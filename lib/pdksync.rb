# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'octokit'

# This module set's out and controls the pdksync process
module PdkSync
  # When a new instance of this module is called, this method will be run in order
  #   to start the pdksync process.
  def self.run_pdksync
    puts 'Running pdksync'
    @params = build_params
    # Temporarily placed here, will me moved to prep method
    create_filespace(@pdksync_dir)

    sync_repo(@params)
  end

  # This method when called will take in set input values and use them to create an array of
  #   hash values, each representing a different repository that will be put through the pdksync process.
  # @return [Array[Hash]] array of hash values - Return an array of different hash values, each
  #   representing a different repository.
  # TODO: This method is currently incomplete pending the addition of iteration to the code.
  def self.build_params
    # Variables that should be the same across all repos, i.e. hardcoded
    @pdksync_dir = './modules_pdksync'
    @access_token = ENV['GITHUB_TOKEN']
    @client = setup_client(@access_token)
    # Variables that will differ for each repo/run, i.e. softcoded
    @timestamp = Time.now.to_i
    @namespace = 'puppetlabs'
    @module_name = 'puppetlabs-testing'

    _params = {
      pdksync_dir: @pdksync_dir,
      timestamp: @timestamp,
      namespace: @namespace,
      module_name: @module_name,
      client: @client
    }
  end

  # This method when called will take in a pre-created hash value representing a repository
  #   and use it in order to begin the pdksync process for said repository.
  # @param [Hash] params - The different parameters needed to run each method called via this one.
  def self.sync_repo(params)
    # Passed in as a param
    # pdksync_dir = params[:pdksync_dir]
    # timestamp = params[:timestamp]
    # client = params[:client]
    #
    # namespace = params[:namespace]
    # module_name = params[:module_name]
    # timestamp = params[:timestamp]

    # Set in this method from the given params
    @repo_name = "#{params[:namespace]}/#{params[:module_name]}"
    @output_path = "#{params[:pdksync_dir]}/#{params[:module_name]}"
    @branch_name = "pdksync_#{params[:timestamp]}"

    @git_repo = clone_directory(params[:namespace], params[:module_name], @output_path)
    checkout_branch(@git_repo, @branch_name)
    pdk_update(@output_path)
    add_staged_files(@git_repo)
    commit_staged_files(@git_repo, params[:timestamp])
    push_staged_files(@git_repo, @branch_name)
    create_pr(params[:client], @repo_name, @branch_name)
  end

  # This method when called will create a directory identified by the given parameter, on the
  #   condition that it does not already exist.
  # @param [String] pdksync_dir - A string value representing that name of the directory to be created.
  def self.create_filespace(pdksync_dir)
    FileUtils.mkdir pdksync_dir unless Dir.exist?(pdksync_dir)
  end

  # This method when called will utilise the given parameters in order to clone down
  #   a repository from Github and save it in a set location and return a connecting object.
  # @param [String] namespace - The Github namespace of the set repository.
  # @param [String] module_name - The name of the set repository.
  # @param [String] output_path - The local directory the repository is to be saved to.
  # @return [Git::Base] - The object representing the local repository.
  def self.clone_directory(namespace, module_name, output_path)
    # TODO: Given that we are planning to create a setup and cleanup method will this line still be required?
    puts 'Cleaning up'
    # If a local copy already exists it is removed
    FileUtils.rm_rf(output_path)
    puts '*************************************'
    puts "Currently Cloning: #{module_name} to #{output_path}"
    git_repo = Git.clone("git@github.com:#{namespace}/#{module_name}.git", output_path.to_s)
    puts 'Clone complete.'
    git_repo
  end

  # This method when called will checkout a branch of a given repository, the
  #   branch name being set by a given param.
  # @param [Git::Base] git_repo - The repository that is to be branched.
  # @param [String] branch_name - The name that the branch is to be given.
  def self.checkout_branch(git_repo, branch_name)
    puts '*************************************'
    puts "Creating a branch called: #{branch_name}"
    # TODO: This is awesome, placeholder for SHA of template.
    git_repo.branch(branch_name.to_s).checkout
  end

  # This method when called will use omen to run 'pdk update' at the given location,
  #   an error being raised if it is not successful.
  # @param [String] output_path - The location at which to run the command.
  def self.pdk_update(output_path)
    # Navigate into the correct directory
    Dir.chdir(output_path)
    # # Removes bundler env values that can cause errors with pdk, making it unable to find bundler. Seem's to have resolved, code left just in case.
    # remove_envs = %w[BUNDLE_BIN_PATH BUNDLE_GEMFILE BUNDLER_VERSION RUBYOPT RUBYLIB]
    # remove_envs.each do |env|
    #   ENV.delete(env)
    # end
    # Runs the pdk update command
    stdout, stderr, status = Open3.capture3('pdk update --force')
    if status != 0
      raise 'Something bad happened'\
            '================='\
            "#{stderr}"\
            "#{stdout}"\
            '================='
    else
      puts '*************************************'
      puts 'PDK Update has ran successfully.'
    end
  end

  # This method when called will stage all changed files within the given
  #   git module to prepare them to be commited.
  # @param [Git::Base] git_repo - The git module against which the files are to be staged.
  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts '*************************************'
    puts 'All files have been staged'
  end

  # This method when called will create a commit containing all currently
  #   staged files.
  # @param [Git:base] git_repo - The git module against which the commit is to be made.
  # @param [String] timestamp - The unique identifier to be used to designate the commit.
  def self.commit_staged_files(git_repo, timestamp)
    git_repo.commit("(maint) - pdksync[#{timestamp}]")
    puts '*************************************'
    puts "The following commit has been created: pdksync[#{timestamp}]"
  end

  # This method when called will push the given branch of the set git
  #   module to it's origin.
  # @param [Git::Base] git_repo - The git module whish is to be pushed.
  # @param [String] branch_name - The branch which is to be pushed.
  def self.push_staged_files(git_repo, branch_name)
    git_repo.push('origin', branch_name)
    puts '*************************************'
    puts 'All staged files have been pushed to the repo, bon voyage!'
  end

  # This method when called will create and return an octokit client with
  #   access to the upstream git repositories.
  # @param [String] access_token - A copy of the access token needed to
  #   allow octokit to access the upstream git repositories.
  # @return [Octokit::Client] client - The octokit client that has
  #   been created.
  def self.setup_client(access_token)
    client = Octokit::Client.new(access_token: access_token.to_s)
    client.user.login
    puts '*************************************'
    puts 'Client login has been successful.'
    client
  end

  # this method when called will utilise the given octokit client in
  #   order to create a pull request to merget he given branch into it's master.
  # @param [OctokitLLClient] client - The client used in order to access
  #   the upstream repository.
  # @param [String] repo_name - The name of the repository upon which
  #   the pull request is to be created.
  # @param [String] branch_name - The name of the branch that is to
  #   be merged into master.
  def self.create_pr(client, repo_name, branch_name)
    pr = client.create_pull_request(repo_name, 'master', branch_name.to_s, "pdksync - #{branch_name}", 'This is the body.')
    puts '*************************************'
    puts 'The PR has successfully been created.'
    pr
  end
end
