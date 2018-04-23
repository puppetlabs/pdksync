module PdkSync # rubocop:disable Style/ClassAndModuleChildren
  module Constants
    ACCESS_TOKEN = ENV['GITHUB_TOKEN'].freeze
    TIMESTAMP = Time.now.to_i
    NAMESPACE = 'puppetlabs'.freeze
    PDKSYNC_DIR = './modules_pdksync'.freeze
    PUSH_FILE_DESTINATION = 'origin'.freeze
    CREATE_PR_AGAINST = 'master'.freeze
    PR_BODY = 'This commit has been created by pdksync.'.freeze
    PR_TITLE = "(maint) - pdksync[#{TIMESTAMP}]".freeze
    BRANCH_NAME = "pdksync_#{TIMESTAMP}".freeze
    COMMIT_MESSAGE = "pdksync - #{BRANCH_NAME}".freeze
  end
end
