require 'pdksync/pullrequest'

# @summary
#   The GitPlatformClient class creates a PdkSync::GithubClient or
#   PdkSync::GitlabClient and provides methods wrapping the client's
#   corresponding methods
class PdkSync::GitPlatformClient
  # @summary
  #   Creates a PdkSync::GithubClient or PdkSync::GitlabClient based on the
  #   value of git_platform.
  # @param [Symbol] git_platform
  #   The symbol designating the Git hosting platform to use and thus which
  #   client to create
  # @param [Hash] git_platform_access_settings
  #   Hash of Git platform access settings, such as access_token or
  #   gitlab_api_endpoint. access_token is always required,
  #   gitlab_api_endpoint only for Gitlab.
  def initialize(git_platform, git_platform_access_settings)
    @git_platform = git_platform

    # TODO: raise exceptions when git_platform_access_settings hash is not
    # set up correctly? Or let PdkSync::GithubClient or PdkSync::GitlabClient
    # raise errors later and let them propagate upwards?
    access_token = git_platform_access_settings[:access_token]
    @client = case git_platform
              when :github
                require 'pdksync/githubclient'

                PdkSync::GithubClient.new(access_token)
              when :gitlab
                require 'pdksync/gitlabclient'

                gitlab_api_endpoint = git_platform_access_settings[:gitlab_api_endpoint]
                PdkSync::GitlabClient.new(access_token, gitlab_api_endpoint)
              end
  end

  # @summary Checks if the supplied project exists on the Git hosting platform
  # @param [String] project
  #   The full repository name, i.e. "namespace/project"
  # @return [Boolean] true if the project exists, false otherwise
  def repository?(project)
    @client.repository?(project)
  end

  # @summary
  #   Creates a new pull/merge request against the Git hosting platform and
  #   wraps the Github or Gitlab result in a PdkSync::PullRequest object for
  #   consumption by pdksync main
  # @param [String] project
  #   The full project name, i.e. "namespace/project" in which to create
  #   the pull/merge request
  # @param [String] target_branch
  #   The target branch against which to create the pull/merge request
  # @param [String] source_branch
  #   The source branch from which to create the pull/merge request
  # @param [String] title
  #   The title/name of the pull/merge request to create
  # @param [String] message
  #   The pull/merge request message/body
  # @return [PdkSync::PullRequest]
  #   A pdksync pull request object for the newly created pull/merge request
  #   for consumption by pdksync main
  def create_pull_request(project, target_branch, source_branch, title, message)
    client_pr = @client.create_pull_request(project, target_branch, source_branch, title, message)
    pr = case @git_platform
         when :github
           PdkSync::PullRequest.github(client_pr)
         when :gitlab
           PdkSync::PullRequest.gitlab(client_pr)
         end
    pr
  end

  # @summary Gets the labels available in the project
  # @param [String] project
  #   The full project name, i.e. "namespace/project", from which to get
  #   the available labels
  # @return [Array] List of available labels in the project
  def labels(project)
    @client.labels(project)
  end

  # @summary Updates an existing pull/merge request in the repository
  # @note
  #   This method is specifically used to set labels for a pull/merge request
  # @param [String] project
  #   The full project name, i.e. "namespace/project" in which to update
  #   the issue
  # @param [Integer] id
  #   The id number of the pull/merge request to update
  # @param [Hash] options
  #   A hash of options defining the changes to the pull/merge request
  # @return A pull/merge request object of the updated pull/merge request
  def update_issue(project, id, options)
    @client.update_issue(project, id, options)
  end

  # @summary Deletes a branch in the project
  # @param [String] project
  #   The full project name, i.e. "namespace/project" in which to delete
  #   the branch
  # @param [String] branch_name
  #   The name of the branch to delete
  # @return [Boolean] true on success, false on failure
  def delete_branch(project, branch_name)
    @client.delete_branch(project, branch_name)
  end

  # @summary Returns the current ref of a given branches head in the repository
  # @param [String] repo_name
  #   The full repository name, i.e. "namespace/repo_name"
  # @param [String] branch_name
  #   The name of the branch whose ref is to be retrieved
  # @return [Octokit::Refs]
  #   The ref object that has been retrieved
  def ref(repo_name, branch_name)
    @client.ref(repo_name, branch_name)
  end
end
