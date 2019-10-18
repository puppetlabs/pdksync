require 'jenkins_api_client'

# @summary
#   This class wraps Gitlab::JenkinsCLient and provides the method implementations
#   required by pdksync main to access the Jenkins API for creating jobs in jenkins
class PdkSync::JenkinsClient
  # @summary
  #   Creates a new Jenkins::Client and logs in the user based on the
  #   supplied user credentials and the Jenkins API endpoint URL
  # @param [String] jenkins_platform_access_settings
  #   The Jenkins credentials, required to access the Jenkins API

  def initialize(jenkins_platform_access_settings)
    jenkins_username = jenkins_platform_access_settings[:jenkins_username]
    jenkins_password = jenkins_platform_access_settings[:jenkins_password]
    @client = JenkinsApi::Client.new('server_url' => 'https://jenkins-master-prod-1.delivery.puppetlabs.net',
                                     'username'   => jenkins_username,
                                     'password'   => jenkins_password)
  end

  # @summary
  #   Creates a new adhoc job against the jenkins
  #   platform
  # @param [String] github_repo
  #   Repo or Module for which the adhoc job to be created
  # @param [String] github_branch
  #   The target branch against which to create the adhoc job
  # @return
  #   Build Id returned by the job
  def create_adhoc_job(github_repo, github_branch)
    # params to start the build
    job_params = { 'GITHUB_USER' => 'puppetlabs',
                   'GITHUB_REPO' => github_repo,
                   'GITHUB_REF'  => github_branch }
    # job name
    job_name = "forge-module_#{github_repo}_init-manual-parameters_adhoc"
    # Wait for up to 30 seconds, attempt to cancel queued build
    opts = { 'build_start_timeout' => 30,
             'cancel_on_build_start_timeout' => true,
             'completion_proc' => lambda { |build_number, cancelled| # rubocop:disable Style/Lambda
               if build_number
                 puts "Wait over: build #{build_number} started"
               else
                 puts "Wait over: build not started, build #{cancelled ? '' : 'NOT '} cancelled"
               end
             } }

    build_id = @client.job.build(job_name, job_params || {}, opts)
    build_id
  end
end
