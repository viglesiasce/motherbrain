require 'grape'
require 'mb/api_validators'

module MotherBrain
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Api < Grape::API
    helpers MB::Logging
    helpers MB::ApiHelpers
    helpers MB::Mixin::Services

    format :json

    rescue_from Grape::Exceptions::ValidationError do |e|
      body = {
        status: e.status,
        message: e.message,
        param: e.param
      }
      rack_response(body, e.status, "Content-type" => "application/json")
    end

    rescue_from PluginNotFound, JobNotFound do |ex|
      rack_response(ex.to_json, 404, "Content-type" => "application/json")
    end

    rescue_from NoBootstrapRoutine do |ex|
      rack_response(ex.to_json, 405, "Content-type" => "application/json")
    end

    rescue_from InvalidProvisionManifest, InvalidBootstrapManifest do |ex|
      rack_response(ex.to_json, 400, "Content-type" => "application/json")
    end

    rescue_from :all do |ex|
      body = if ex.is_a?(MB::MBError)
        ex.to_json
      else
        MB.log.fatal { "an unknown error occured: #{ex}" }
        MultiJson.encode(code: -1, message: "an unknown error occured")
      end

      rack_response(body, 500, "Content-type" => "application/json")
    end

    desc "display the loaded configuration"
    get :config do
      Application.config
    end

    resource :jobs do
      desc "list all jobs (completed and active)"
      get do
        JobManager.instance.list
      end

      desc "list all active jobs"
      get :active do
        JobManager.instance.active
      end

      desc "find and return the Job with the given ID"
      params do
        requires :id, type: String, desc: "job id"
      end
      get ':id' do
        find_job!(params[:id])
      end
    end

    resource :environments do
      desc "destroy a provisioned environment"
      params do
        requires :id, type: String, desc: "environment name"
      end
      delete ':id' do
        provisioner.destroy(params[:id])
      end

      desc "create (provision) a new cluster of nodes"
      params do
        requires :id, type: String, desc: "environment name"
        requires :manifest, desc: "a Hash representation of the node group to create"
        group :plugin do
          requires :name, type: String, desc: "name of the plugin to use"
          optional :version, sem_ver: true, desc: "version of the plugin to use"
        end
        optional :component_versions, type: Hash, desc: "component versions to set with override attributes"
        optional :cookbook_versions, type: Hash, desc: "cookbook versions to set on the environment"
        optional :environment_attributes, type: Hash, desc: "additional attributes to set on the environment"
        optional :skip_bootstrap, type: Boolean, desc: "skip automatic bootstrapping of the created environment"
        optional :force, type: Boolean, desc: "force provisioning nodes to the environment even if the environment is locked"
      end
      post ':id' do
        plugin   = find_plugin!(params[:plugin][:name], params[:plugin][:version])
        manifest = Provisioner::Manifest.new(params[:manifest])
        manifest.validate!(plugin)

        provisioner.provision(
          params[:id].freeze,
          manifest.freeze,
          plugin.freeze,
          params.exclude(:id, :manifest, :plugin).freeze
        )
      end

      desc "update (bootstrap) an existing cluster of nodes"
      params do
        requires :id, type: String, desc: "environment name"
        requires :manifest, desc: "a Hash representation of the node group to update"
        group :plugin do
          requires :name, type: String, desc: "name of the plugin to use"
          optional :version, sem_ver: true, desc: "version of the plugin to use"
        end
        optional :component_versions, type: Hash, desc: "component versions to set with override attributes"
        optional :cookbook_versions, type: Hash, desc: "cookbook versions to set on the environment"
        optional :environment_attributes, type: Hash, desc: "additional attributes to set on the environment"
        optional :force, type: Boolean
        optional :hints
      end
      put ':id' do
        plugin   = find_plugin!(params[:plugin][:name], params[:plugin][:version])
        manifest = Bootstrap::Manifest.new(params[:manifest])
        manifest.validate!(plugin)

        bootstrapper.bootstrap(
          params[:id].freeze,
          manifest.freeze,
          plugin.freeze,
          params.slice(:component_versions, :cookbook_versions, :environment_attributes, :force, :bootstrap_proxy, :hints).freeze
        )
      end

      desc "configure an existing environment cluster"
      params do
        requires :id, type: String, desc: "environment name"
        requires :attributes, type: Hash, desc: "a hash of attributes to set on the environment"
        optional :force, type: Boolean, desc: "force configure even if the environment is locked"
      end
      post ':id/configure' do
        environment_manager.configure(params[:id], params.slice(:attributes, :force))
      end
    end

    resource :plugins do
      desc "list all loaded plugins and their versions"
      get do
        plugin_manager.list
      end

      desc "display all the versions of the given plugin"
      params do
        requires :name, type: String, desc: "plugin name"
      end
      get ':name' do
        plugin_manager.versions(params[:name])
      end

      resource ':name/latest' do
        desc "display the latest version of the plugin of the given name"
        params do
          requires :name, type: String, desc: "plugin name"
        end
        get do
          find_plugin!(params[:name])
        end

        desc "list of all the commands the latest plugin can do"
        params do
          requires :name, type: String, desc: "plugin name"
        end
        get 'commands' do
          find_plugin!(params[:name]).commands
        end

        desc "list of all the components the latest plugin has"
        params do
          requires :name, type: String, desc: "plugin name"
        end
        get 'components' do
          find_plugin!(params[:name]).components
        end
      end

      resource ':name/:version' do
        desc "display the plugin of the given name and version"
        params do
          requires :name, type: String, desc: "plugin name"
          requires :version, sem_ver: true
        end
        get do
          find_plugin!(params[:name], params[:version])
        end

        desc "list of all the commands the specified plugin version can do"
        params do
          requires :name, type: String, desc: "plugin name"
          requires :version, sem_ver: true
        end
        get 'commands' do
          find_plugin!(params[:name], params[:version]).commands
        end

        resource :components do
          desc "list of all the components the specified plugin version has"
          params do
            requires :name, type: String, desc: "plugin name"
            requires :version, sem_ver: true
          end
          get do
            find_plugin!(params[:name], params[:version]).components
          end

          desc "list of all the commands the component of the specified plugin version has"
          params do
            requires :name, type: String, desc: "plugin name"
            requires :version, sem_ver: true
            requires :component_id, type: String, desc: "component name"
          end
          get ':component_id/commands' do
            find_plugin!(params[:name], params[:version]).component(params[:component_id])
          end
        end
      end
    end

    if MB.testing?
      get :mb_error do
        raise MB::InternalError, "a nice error message"
      end

      get :unknown_error do
        raise ::ArgumentError, "hidden error message"
      end
    end
  end
end
