# @summary A simple wrapper class around Github pull request and Gitlab merge
#   request objects used to abstract the differences and provide a common
#   interface to PR URL and number/id.
class PdkSync::PullRequest
  class << self
    def github(pr_object)
      new(pr_object)
    end

    def gitlab(pr_object)
      new(pr_object, :gitlab)
    end

    private :new
  end

  attr_reader :html_url, :number

  # Create a new PR wrapper object setting html_url and number
  # @param pr_object
  #   The pull request object to wrap as created by Octokit::Client or
  #   Gitlab::Client
  # @param [Symbol] git_platform
  #   The Git hosting platform against which the pull request is made
  def initialize(pr_object, git_platform = :github)
    case git_platform
    when :github
      @html_url = pr_object.html_url
      @number = pr_object.number
    when :gitlab
      @html_url = pr_object.web_url
      @number = pr_object.iid
    end
  end
end
