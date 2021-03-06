require 'rspec/mocks'
require 'active_support/inflector'
require 'webmock'

module MotherBrain
  module Test
    def self.mock(type)
      type = type.to_s
      klass = begin
                "::MB::Test::#{type.camelize}".constantize
              rescue NameError
                MB.log.warn { "Couldn't find test class for #{type}" }
                return false
              end
      klass.mock!
    end

    class Base
      def self.mock!
        new.register_mocks
      end

      def initialize
        ::RSpec::Mocks.setup(self)
        WebMock.disable_net_connect!(allow_localhost: true)
      end

      def type
        self.class.to_s.sub(/.*::/, '').upcase
      end

      def available_mocks
        []
      end

      def register_mocks
        return unless MB.testing?
        available_mocks.each do |mock|
          env = ENV["MB_TEST_#{type}_#{mock.upcase}"]
          self.send(mock, env) if env
        end
      end
    end

    class Init < Base
      include WebMock::API

      def available_mocks
        [:env, :cookbook, :bootstrap, :template, :template_url]
      end

      def ridley
        return @ridley if @ridley
        @ridley = double('ridley')
        Application.ridley.wrapped_object.should_receive(:connection).and_return(@ridley)
        @ridley.should_receive(:alive?).and_return(true)
        @ridley.should_receive(:terminate).and_return(true)
        @ridley.should_receive(:url_prefix).and_return("http://chef.example.com")
        @ridley
      end

      def env(name)
        ridley.should_receive(:get).with("environments/#{name}").
          and_return(double(:response, :body => {}))
      end

      def cookbook(name, version = nil)
        ridley.should_receive(:get).with("cookbooks").and_return(double(:response, :body => {}))
        ridley.should_receive(:get).with("cookbooks/#{name}").and_return(double(:response, :body => {}))
        plugin = MB::Application.plugin_manager.find(name, version)
        MB::Application.plugin_manager.should_receive(:for_environment).and_return(plugin)
      end

      def bootstrap(x)
        Application.bootstrap_manager.wrapped_object.should_receive(:bootstrap) do |job, environment, manifest, plugin, options|
          job.report_running
          job.report_success
          job.terminate if job.alive?
        end
      end

      def template(name)
        ridley.should_receive(:get).with("nodes").and_return(double(:response, :body => []))
        node = double('node')
        Application.ridley.wrapped_object.should_receive(:node).and_return(node)
        ssh = double('ssh')
        node.should_receive(:bootstrap) do |hostnames, options|
          raise "Template not set!" unless options[:template]
          raise "Template not right!" unless options[:template] =~ /#{name}/
          [ssh]
        end
        node.should_receive(:all).and_return([])
        ssh.should_receive(:host).and_return("foo.example.com")
        ssh.should_receive(:error?).and_return(false)
        Application.node_querier.wrapped_object.should_receive(:node_name).and_return("foo.example.com")
      end

      def template_url(name_and_url)
        name, url = name_and_url.split("##")
        stub_request(:get, url).to_return(:body => name)
      end
    end
  end
end
