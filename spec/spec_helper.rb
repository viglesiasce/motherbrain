require 'rubygems'
require 'bundler'
require 'spork'

Spork.prefork do
  require 'rspec'
  require 'json_spec'
  require 'webmock/rspec'

  Dir[File.join(File.expand_path("../../spec/support/**/*.rb", __FILE__))].each { |f| require f }

  RSpec.configure do |config|
    config.include JsonSpec::Helpers
    config.include MotherBrain::SpecHelpers

    config.mock_with :rspec
    config.treat_symbols_as_metadata_keys_with_true_values = true
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true

    config.before(:each) do
      clean_tmp_path
      @config = double('config',
        to_ridley: {
          server_url: "http://chef.riotgames.com",
          client_name: "fake",
          client_key: File.join(fixtures_path, "fake_key.pem")
        }
      )
      @context = double('context',
        to_ridley: @config.to_ridley
      )
    end
  end
end

Spork.each_run do
  require 'motherbrain'
end
