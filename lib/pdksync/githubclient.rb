require 'octokit'

# @summary
#   This class wraps Octokit::Client and provides the method implementations
#   required by pdksync main to access the Github API for creating pull
#   requests, adding labels, and so forth.
class PdkSync::GithubClient
  # @summary
  #   Creates a new Octokit::Client and logs in the user based on the
  #   supplied access token
  # @param access_token
  #   The Github access token, required to access the Github API
  def initialize(access_token, api_endpoint = nil)
    # USE ENV['OCTOKIT_API_ENDPOINT'] or pass in the api_endpoint
    Octokit.configure { |c| c.api_endpoint = api_endpoint } unless api_endpoint.nil?
    @client = Octokit::Client.new(access_token: access_token.to_s)
    @client.user.login
  end

  # @summary Checks if the supplied repository exists on the Git hosting platform
  # @param [String] repository
  #   The full repository name, i.e. "namespace/repo_name"
  # @return [Boolean] true if the repository exists, false otherwise
  def repository?(repository)
    @client.repository?(repository)
  end

  # @summary Creates a new pull request against the Git hosting platform
  # @param [String] repo_name
  #   The full repository name, i.e. "namespace/repo_name" in which to create
  #   the pull request
  # @param [String] create_pr_against
  #   The target branch against which to create the pull request
  # @param [String] head
  #   The source branch from which to create the pull request
  # @param [String] title
  #   The title/name of the pull request to create
  # @param [String] message
  #   The pull request message/body
  # @return An Octokit pull request object for the newly created pull request
  def create_pull_request(repo_name, create_pr_against, head, title, message)
    @client.create_pull_request(repo_name, create_pr_against, head, title, message)
  end

  # @summary Gets the labels available in the repository
  # @param [String] repo_name
  #   The full repository name, i.e. "namespace/repo_name", from which to get
  #   the available labels
  # @return [Array] List of available labels in the repository
  def labels(repo_name)
    @client.labels(repo_name)
  end

  # @summary Updates an existing issue/pull request in the repository
  # @param [String] repo_name
  #   The full repository name, i.e. "namespace/repo_name" in which to update
  #   the issue
  # @param [Integer] issue_number
  #   The id number of the issue/pull request to update
  # @param [Hash] options
  #   A hash of options definint the changes to the issue
  # @return An Octokit issue object of the updated issue
  def update_issue(repo_name, issue_number, options)
    @client.update_issue(repo_name, issue_number, options)
  end

  # @summary Deletes a branch in the repository
  # @param [String] repo_name
  #   The full repository name, i.e. "namespace/repo_name" in which to delete
  #   the branch
  # @param [String] branch_name
  #   The name of the branch to delete
  # @return [Boolean] true on success, false on failure
  def delete_branch(repo_name, branch_name)
    @client.delete_branch(repo_name, branch_name)
  end
end
