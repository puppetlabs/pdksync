require 'gitlab'

# @summary
#   This class wraps Gitlab::Client and provides the method implementations
#   required by pdksync main to access the Gitlab API for creating merge
#   requests, adding labels, and so forth.
class PdkSync::GitlabClient
  # @summary
  #   Creates a new Gitlab::Client and logs in the user based on the
  #   supplied access token and the Gitlab API endpoint URL
  # @param [String] access_token
  #   The Gitlab private access token, required to access the Gitlab API
  # @param [String] gitlab_api_endpoint
  #   URL to the Gitlab API endpoint against which to work
  def initialize(access_token, gitlab_api_endpoint)
    @client = Gitlab.client(endpoint: gitlab_api_endpoint, private_token: access_token)
  end

  # @summary Checks if the supplied project exists on the Git hosting platform
  # @param [String] project
  #   The full repository name, i.e. "namespace/project"
  # @return [Boolean] true if the project exists, false otherwise
  def repository?(project)
    @client.project(project)

    true
  rescue Gitlab::Error::NotFound
    false
  end

  # @summary
  #   Creates a new merge request (i.e. pull request) against the Gitlab
  #   platform
  # @param [String] project
  #   The full project name, i.e. "namespace/project" in which to create
  #   the merge request
  # @param [String] target_branch
  #   The target branch against which to create the merge request
  # @param [String] source_branch
  #   The source branch from which to create the merge request
  # @param [String] title
  #   The title/name of the merge request to create
  # @param [String] message
  #   The pull request message/body
  # @return
  #   A Gitlab merge request object for the newly created merge request
  def create_pull_request(project, target_branch, source_branch, title, message)
    mr_options = {
      source_branch: source_branch,
      target_branch: target_branch,
      description: message
    }
    @client.create_merge_request(project, title, mr_options)
  end

  # @summary Gets the labels available in the project
  # @param [String] project
  #   The full project name, i.e. "namespace/project", from which to get
  #   the available labels
  # @return [Array] List of available labels in the project
  def labels(project)
    @client.labels(project)
  end

  # @summary Updates an existing merge request in the repository
  # @note This method is specifically used to set labels for a merge request
  # @param [String] project
  #   The full project name, i.e. "namespace/project" in which to update
  #   the issue
  # @param [Integer] id
  #   The id number of the merge request to update
  # @param [Hash] options
  #   A hash of options defining the changes to the merge request
  # @return A Gitlab merge request object of the updated merge request
  def update_issue(project, id, options)
    # Gitlab requires labels to be supplied as a comma-separated string
    labels = options[:labels].join(',')
    @client.update_merge_request(project, id, labels: labels)
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
end
