require 'yaml'

# @summary
#   A module used to contain a set of variables that are expected to remain constant across all iterations of the main pdksync module.
# @note
#   Configuration is loaded from `$HOME/.pdksync.yml`. If $HOME is not set, the config_path will use the current directory.
#   Set PDKSYNC_LABEL to '' to disable adding a label during pdksync runs.
module PdkSync # rubocop:disable Style/ClassAndModuleChildren
  # Constants contains the configuration for pdksync to use
  module Constants
    default_config = {
      namespace: 'puppetlabs',
      pdksync_dir: 'modules_pdksync',
      push_file_destination: 'origin',
      create_pr_against: 'master',
      managed_modules: 'managed_modules.yml',
      pdksync_label: 'maintenance'
    }

    config = {}

    config_path = "#{ENV['HOME']}/.pdksync.yml"

    if File.exist?(config_path)
      customConfig = YAML.load_file(config_path)
      config[:namespace] = customConfig['namespace'] ||= default_config[:namespace]
      config[:pdksync_dir] = customConfig['pdksync_dir'] ||= default_config[:pdksync_dir]
      config[:push_file_destination] = customConfig['push_file_destination'] ||= default_config[:push_file_destination]
      config[:create_pr_against] = customConfig['create_pr_against'] ||= default_config[:create_pr_against]
      config[:managed_modules] = customConfig['managed_modules'] ||= default_config[:managed_modules]
      config[:pdksync_label] = customConfig['pdksync_label'] ||= default_config[:pdksync_label]
    else
      config = default_config
    end

    ACCESS_TOKEN = ENV['GITHUB_TOKEN'].freeze
    NAMESPACE = config[:namespace].freeze
    PDKSYNC_DIR = config[:pdksync_dir].freeze
    PUSH_FILE_DESTINATION = config[:push_file_destination].freeze
    CREATE_PR_AGAINST = config[:create_pr_against].freeze
    MANAGED_MODULES = config[:managed_modules].freeze
    PDKSYNC_LABEL = config[:pdksync_label].freeze
  end
end
