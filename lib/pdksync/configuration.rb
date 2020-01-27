require 'yaml'
require 'pdk/version'
require 'ostruct'

# @summary
#   A class used to contain a set of configuration variables
# @note
#   Configuration is loaded from `$HOME/.pdksync.yml`. If $HOME is not set, the config_path will use the current directory.
#   The configuration filename and path can be overridden with env variable PDK_CONFIG_PATH
#   Set PDKSYNC_LABEL to '' to disable adding a label during pdksync runs.
module PdkSync
  class Configuration < OpenStruct
    SUPPORTED_SCM_PLATFORMS = [:github, :gitlab].freeze
    PDKSYNC_FILE_NAME = 'pdksync.yml'.freeze

    # Any key value added to the default config or custom config
    # will automatically be a new configuration item and referenced
    # via Configuration.new.<key_name> ie.
    # c = Configuration.new
    # c.api_endpoint
    DEFAULT_CONFIG = {
      namespace: 'puppetlabs',
      pdksync_dir: 'modules_pdksync',
      pdksync_gem_dir: 'gems_pdksync',
      push_file_destination: 'origin',
      create_pr_against: 'master',
      managed_modules: 'managed_modules.yml',
      pdksync_label: 'maintenance',
      git_platform: :github,
      git_base_uri: 'https://github.com',
      gitlab_api_endpoint: 'https://gitlab.com/api/v4',
      api_endpoint: nil,
      pdk_templates_prefix: nil,
      pdk_templates_ref: PDK::VERSION,
      pdk_templates_url: 'https://github.com/puppetlabs/pdk-templates.git',
      jenkins_platform: :jenkins,
      jenkins_base_uri: 'https://jenkins.io',
      jenkins_api_endpoint: '',
      jenkins_server_url: '',
      module_is_authoritive: true
    }.freeze

    # @param config_path [String] -  the path to the pdk config file
    def initialize(config_path = ENV['PDKSYNC_CONFIG_PATH'])
      @config_path = locate_config_path(config_path)
      @custom_config = DEFAULT_CONFIG.merge(custom_config(@config_path))
      @custom_config[:pdk_templates_ref] = "#{@custom_config[:pdk_templates_prefix]}#{@custom_config[:pdk_templates_ref]}"
      super(@custom_config)
      valid_scm?(git_platform)
      valid_access_token?
    end

    # @return [Hash] - returns the access settings for git scm
    def git_platform_access_settings
      @git_platform_access_settings ||= {
        access_token: access_token,
        gitlab_api_endpoint: gitlab_api_endpoint || api_endpoint,
        api_endpoint: api_endpoint

      }
    end

    def jenkins_platform_access_settings
      @jenkins_platform_access_settings ||= {
        jenkins_username: ENV['JENKINS_USERNAME'].freeze,
        jenkins_password: ENV['JENKINS_PASSWORD'].freeze,
        jenkins_api_endpoint: ''
      }
    end

    # @return [Hash] - returns the access settings for gemfury account
    def gemfury_access_settings
      valid_access_token_gem_fury?
      @gemfury_access_token = access_token_gem_fury
    end

    # @return [String] return a rendered string for pdk to use the templates
    def templates
      "--template-url=#{pdk_templates_url} --template-ref=#{pdk_templates_ref}"
    end

    # @param path [String] path to the pdksync config file in yaml format
    # @return [Hash] the custom configuration as a hash
    def custom_config(path = nil)
      return {} unless path
      return {} unless File.exist?(path)
      c = (YAML.load_file(path) || {}).transform_keys_to_symbols
      c[:git_base_uri] ||= 'https://gitlab.com' if c[:git_platform].eql?(:gitlab)
      c
    end

    # @return [String] the path the pdksync config file, nil if not found
    def locate_config_path(custom_file = nil)
      files = [
        custom_file,
        PDKSYNC_FILE_NAME,
        File.join(ENV['HOME'], PDKSYNC_FILE_NAME)
      ]
      files.find { |file| file && File.exist?(file) }
    end

    private

    # @return [Boolean] true if the supported platforms were specified correctly
    # @param scm [Symbol] - the scm type (:github or :gitlab)
    def valid_scm?(scm)
      unless SUPPORTED_SCM_PLATFORMS.include?(scm)
        raise ArgumentError, "Unsupported Git hosting platform '#{scm}'."\
          " Supported platforms are: #{SUPPORTED_SCM_PLATFORMS.join(', ')}"
      end
      true
    end

    # @return [Boolean] true if the access token for the scm platform was supplied
    def valid_access_token?
      if access_token.nil?
        raise ArgumentError, "Git platform access token for #{git_platform.capitalize} not set"\
          " - use 'export #{git_platform.upcase}_TOKEN=\"<your token>\"' to set"
      end
      true
    end

    # @return [Boolean] true if the access token for the gemfury was supplied
    def valid_access_token_gem_fury?
      if access_token_gem_fury.nil?
        raise 'Gemfury access token not set'\
        " - use 'export GEMFURY_TOKEN=\"<your token>\"' to set"
      end
      true
    end

    # @return [String] the platform specific access token
    def access_token
      case git_platform
      when :github
        ENV['GITHUB_TOKEN'].freeze
      when :gitlab
        ENV['GITLAB_TOKEN'].freeze
      end
    end

    # @return [String] the gem_fury access token
    def access_token_gem_fury
      ENV['GEMFURY_TOKEN'].freeze
    end
  end
end

# monkey patch
class Hash
  # take keys of hash and transform those to a symbols
  def transform_keys_to_symbols
    each_with_object({}) { |(k, v), memo| memo[k.to_sym] = v; }
  end
end
