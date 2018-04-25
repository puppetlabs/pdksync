module PdkSync # rubocop:disable Style/ClassAndModuleChildren
  module Constants
    ACCESS_TOKEN = ENV['GITHUB_TOKEN'].freeze
    NAMESPACE = 'puppetlabs'.freeze
    PDKSYNC_DIR = './modules_pdksync'.freeze
    PUSH_FILE_DESTINATION = 'origin'.freeze
    CREATE_PR_AGAINST = 'master'.freeze
  end
end
