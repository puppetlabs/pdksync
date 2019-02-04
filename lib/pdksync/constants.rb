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
      pdksync_label: 'maintenance',
      git_platform: :github,
      git_base_uri: 'https://github.com',
      gitlab_api_endpoint: 'https://gitlab.com/api/v4'
    }

    supported_git_platforms = [:github, :gitlab]

    config = {}

    config_path = "#{ENV['HOME']}/.pdksync.yml"

    # pdksync config file must exist, not be empty and not be an empty YAML file
    if File.exist?(config_path) && YAML.load_file(config_path) && !YAML.load_file(config_path).nil?
      custom_config = YAML.load_file(config_path)
      config[:namespace] = custom_config['namespace'] ||= default_config[:namespace]
      config[:pdksync_dir] = custom_config['pdksync_dir'] ||= default_config[:pdksync_dir]
      config[:push_file_destination] = custom_config['push_file_destination'] ||= default_config[:push_file_destination]
      config[:create_pr_against] = custom_config['create_pr_against'] ||= default_config[:create_pr_against]
      config[:managed_modules] = custom_config['managed_modules'] ||= default_config[:managed_modules]
      config[:pdksync_label] = custom_config['pdksync_label'] ||= default_config[:pdksync_label]
      config[:git_platform] = custom_config['git_platform'] ||= default_config[:git_platform]
      config[:git_base_uri] = custom_config['git_base_uri'] ||= case config[:git_platform]
                                                                when :gitlab
                                                                  'https://gitlab.com'
                                                                else
                                                                  default_config[:git_base_uri]
                                                                end
      config[:gitlab_api_endpoint] = custom_config['gitlab_api_endpoint'] ||= default_config[:gitlab_api_endpoint]
    else
      config = default_config
    end

    NAMESPACE = config[:namespace].freeze
    PDKSYNC_DIR = config[:pdksync_dir].freeze
    PUSH_FILE_DESTINATION = config[:push_file_destination].freeze
    CREATE_PR_AGAINST = config[:create_pr_against].freeze
    MANAGED_MODULES = config[:managed_modules].freeze
    PDKSYNC_LABEL = config[:pdksync_label].freeze
    GIT_PLATFORM = config[:git_platform].downcase.to_sym.freeze
    GIT_BASE_URI = config[:git_base_uri].freeze
    GITLAB_API_ENDPOINT = config[:gitlab_api_endpoint].freeze
    ACCESS_TOKEN = case GIT_PLATFORM
                   when :github
                     ENV['GITHUB_TOKEN'].freeze
                   when :gitlab
                     ENV['GITLAB_TOKEN'].freeze
                   end

    # Sanity checks

    unless supported_git_platforms.include?(GIT_PLATFORM)
      raise "Unsupported Git hosting platform '#{GIT_PLATFORM}'."\
        " Supported platforms are: #{supported_git_platforms.join(', ')}"
    end

    if ACCESS_TOKEN.nil?
      raise "Git platform access token for #{GIT_PLATFORM.capitalize} not set"\
        " - use 'export #{GIT_PLATFORM.upcase}_TOKEN=\"<your token>\"' to set"
    end
  end
end
