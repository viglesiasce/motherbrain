module MotherBrain
  # @author Jamie Winsor <reset@riotgames.com>
  class CommandInvoker
    class << self
      # @raise [Celluloid::DeadActorError] if command invoker has not been started
      #
      # @return [Celluloid::Actor(CommandInvoker)]
      def instance
        MB::Application[:command_invoker] or raise Celluloid::DeadActorError, "command invoker not running"
      end
    end

    include Celluloid
    include MB::Logging
    include MB::Mixin::Services

    def initialize
      log.info { "Command Invoker starting..." }
    end

    # Invoke a plugin level command on an environment
    #
    # @param [String] plugin_id
    # @param [String] command_id
    # @param [String] environment
    #
    # @option options [Array] :arguments
    # @option options [String] :version
    #
    # @raise [PluginNotFound] if a plugin of the given name is not found
    # @raise [CommandNotfound] if the plugin does not have a command matching the given name
    #
    # @return [JobTicket]
    def invoke_plugin(plugin_id, command_id, environment, options = {})
      options = options.reverse_merge(
        arguments: Array.new
      )

      unless plugin = plugin_manager.find(plugin_id, options[:version])
        abort PluginNotFound.new(plugin_id, options[:version])
      end

      unless command = plugin.command(command_id)
        abort CommandNotFound.new(command_id, plugin)
      end

      command.invoke(environment, options[:arguments])
    end

    # Invoke a component level command on an environment
    #
    # @param [String] plugin_id
    # @param [String] component_id
    # @param [String] command_id
    # @param [String] environment
    #
    # @option options [Array] :arguments
    # @option options [String] :version
    #
    # @raise [PluginNotFound] if a plugin of the given name is not found
    # @raise [ComponentNotFound] if the plugin does not have a component matching the given name
    # @raise [CommandNotfound] if the plugin does not have a command matching the given name
    #
    # @return [JobTicket]
    def invoke_component(plugin_id, component_id, command_id, environment, options = {})
      options = options.reverse_merge(
        arguments: Array.new
      )
      
      unless plugin = plugin_manager.find(plugin_id, options[:version])
        abort PluginNotFound.new(plugin_id, options[:version])
      end

      unless component = plugin.component(component_id)
        abort ComponentNotFound.new(component_id, plugin)
      end

      unless command = component.command(command_id)
        abort CommandNotFound.new(command_id, plugin)
      end

      command.invoke(environment, options[:arguments])
    end
  end
end
