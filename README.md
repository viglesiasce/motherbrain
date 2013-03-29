# motherbrain

motherbrain is an orchestration framework for Chef. In the same way that you
would use Chef's Knife command to create a single node, you can use
motherbrain to create and control an entire application environment.

## Requirements

* Ruby 1.9.3+
* Chef Server 10 or 11, or Hosted Chef

## Installation

Install motherbrain via RubyGems:

```sh
gem install mb
```

If your cookbook has a Gemfile, you'll probably want to add motherbrain there
instead:

```ruby
gem 'motherbrain'
```

and then install with `bundle install`.

Before using motherbrain, you'll need to create a configuration file with `mb
configure`:

```
Enter a Chef API URL:
Enter a Chef API Client:
Enter the path to the client's Chef API Key:
Enter a SSH user:
Enter a SSH password:
Config written to: '~/.mb/config.json'
```

You can verify that motherbrain is installed correctly and pointing to a Chef
server my running `mb plugins --remote`:

```
$ mb plugins --remote

** listing local and remote plugins...

```

## Getting Started

motherbrain comes with an `init` command to help you get started quickly. Let's
pretend we have an app called MyFace, our hot new social network. We'll
be using the myface cookbook for this tutorial:

```
$ git clone https://github.com/reset/myface-cookbook
$ cd myface
myface$
```

We'll generate a new plugin for the cookbook we're developing:

```
myface$ mb init
      create  bootstrap.json
      create  motherbrain.rb

motherbrain plugin created.

Take a look at motherbrain.rb and bootstrap.json,
and then bootstrap with:

  mb myface bootstrap bootstrap.json

To see all available commands, run:

  mb myface help

myface$
```

That command created a plugin for us, as well as told us about some commands we
can run. Notice that each command starts with the name of our plugin. Once
we're done developing our plugin and we upload it to our Chef server, we can
run plugins from any cookbook on our Chef server.

Lets take a look at all of the commands we can run on a plugin:

```
myface$ mb myface
using myface (1.1.8)

Tasks:
  mb myface app [COMMAND]       # Myface application
  mb myface bootstrap MANIFEST  # Bootstrap a manifest of node groups
  mb myface help [COMMAND]      # Describe subcommands or one specific subcommand
  mb myface nodes               # List all nodes grouped by Component and Group
  mb myface provision MANIFEST  # Create a cluster of nodes and add them to a Chef environment
  mb myface upgrade             # Upgrade an environment to the specified versions
```

There are a few things plugins can do:

* Bootstrap existing nodes and configure an environment
* Provision nodes from a compute provider, such as Amazon EC2, Vagrant, or
  Eucalyptus
* List all nodes in an environment, and what they're used for
* Configure/upgrade an environment with cookbook versions, environment
  attributes, and then run Chef on all affected nodes
* Run plugin commands, which abstract setting environment attributes and
  running Chef on the nodes

Notice that there's one task in the help output called `app` which doesn't map
to any of those bulletpoints. Let's take a look at the plugin our `init`
command created:

```rb
cluster_bootstrap do
  bootstrap 'app::default'
end

component 'app' do
  description "Myface application"
  versioned

  group 'default' do
    recipe 'myface::default'
  end
end
```

A plugin consists of a few things:

* `cluster_bootstrap` declares the order to bootstrap component groups
* `component` creates a namespace for different parts of your application
  * `description` provides a friendly summary of the component
  * `versioned` denotes that this component is versioned with an environment
    attribute
  * `group` declares a group of nodes
    * `recipe` defines how we identify nodes in this group

This plugin is enough to get our app running on a single node. Let's try it out.
Edit `bootstrap.json` and fill in a hostname to bootstrap:

```json
{
  "nodes": [
    {
      "groups": ["app::default"],
        "hosts": ["box1"]
    }
  ]
}
```

And then we'll bootstrap our plugin to the node:

```
knife environment create motherbrain_tutorial
myface-cookbook$ mb myface bootstrap bootstrap.json -e motherbrain_tutorial

```


# Authors

* Jamie Winsor (<reset@riotgames.com>)
* Jesse Howarth (<jhowarth@riotgames.com>)
* Justin Campbell (<justin.campbell@riotgames.com>)
