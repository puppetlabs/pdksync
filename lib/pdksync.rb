# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'octokit'
require 'pdksync/constants'
require 'json'
require 'yaml'

# @summary
#   This module set's out and controls the pdksync process
# @param [String] @access_token
#   The token used to access github, must be exported locally.
# @param [String] @namspace
#   The namespace of the repositories we are updating.
# @param [String] @pdksync_dir
#   The local directory the repositories are to be copied to.
# @param [String] @push_file_destination
#   The remote that the pull requests are to be made against.
# @param [String] @create_pr_against
#   The branch the the pull requests are to be made against.
# @param [String] @managed_modules
#   The file that the array of managed modules is to be retrieved from.
module PdkSync
  include Constants
  @access_token = Constants::ACCESS_TOKEN
  @namespace = Constants::NAMESPACE
  @pdksync_dir = Constants::PDKSYNC_DIR
  @push_file_destination = Constants::PUSH_FILE_DESTINATION
  @create_pr_against = Constants::CREATE_PR_AGAINST
  @managed_modules = Constants::MANAGED_MODULES

  # @summary
  #   When a new instance of this module is called, this method will be run in order to start the pdksync process.
  def self.run_pdksync
    puts '*************************************'
    puts 'Running pdksync'
    create_filespace
    @client = setup_client
    @module_names = return_modules
    # The current directory is saved for cleanup purposes
    @main_path = Dir.pwd

    # Run an iterative loop for each @module_name
    @module_names.each do |module_name|
      sync(module_name, @client)
      # Cleanup used to ensure that the current directory is reset after each run.
      Dir.chdir(@main_path) unless Dir.pwd == @main_path
    end
  end

  # @summary
  #   This method when called will create a directory identified by the set global variable '@pdksync_dir', on the condition that it does not already exist.
  def self.create_filespace
    FileUtils.mkdir @pdksync_dir unless Dir.exist?(@pdksync_dir)
  end

  # @summary
  #   This method when called will create and return an octokit client with access to the upstream git repositories.
  # @return [Octokit::Client] client
  #   The octokit client that has been created.
  def self.setup_client
    client = Octokit::Client.new(access_token: @access_token.to_s)
    client.user.login
    puts '*************************************'
    puts 'Client login has been successful.'
    client
  rescue ArgumentError
    raise "Access Token not set up correctly - Use export 'GITHUB_TOKEN=<put your token here>' to set it."
  end

  # @summary
  #   This method when called will access a file set by the global variable '@managed_modules' and retrieve the information within as an array.
  # @return [Array]
  #   An array of different module names.
  def self.return_modules
    YAML.safe_load(File.open(@managed_modules))
  end

  # @summary
  #   This method when called will take in a module name and an octokit client and use them to run the pdksync process on the given module.
  #   If @git_repo is not set the clone will have failed, in which case we avoid further action. If the pdk update fails it will move to the
  #   next module.
  # @param [String] module_name
  #   The name of the module to be put through the process
  # @param [Octokit::Client] client
  #   The client used to access github.
  def self.sync(module_name, client)
    @repo_name = "#{@namespace}/#{module_name}"
    @output_path = "#{@pdksync_dir}/#{module_name}"
    clean_env(@output_path) if Dir.exist?(@output_path)
    @git_repo = clone_directory(@namespace, module_name, @output_path)
    unless @git_repo.nil? # rubocop:disable Style/GuardClause
      if pdk_update(@output_path) == 0 # rubocop:disable Style/NumericPredicate
        @template_ref = return_template_ref
        checkout_branch(@git_repo, @template_ref)
        @pdk_version = return_pdk_version
        add_staged_files(@git_repo)
        commit_staged_files(@git_repo, @template_ref)
        push_staged_files(@git_repo, @template_ref, @repo_name)
        create_pr(client, @repo_name, @template_ref, @pdk_version)
      end
    end
  end

  # @summary
  #   This method when called will call the delete function against the given repository if it exists.
  # @param [String] output_path
  #   The repository that is to be deleted.
  def self.clean_env(output_path)
    puts '*************************************'
    puts 'Cleaning your environment.'
    # If a local copy already exists it is removed
    FileUtils.rm_rf(output_path)
  end

  # @summary
  #   This method when called will clone a given repository into a local location that has also been set.
  # @param [String] namespace
  #   The namespace the repository is located in.
  # @param [String] module_name
  #   The name of the repository.
  # @param [String] output_path
  #   The location the repository is to be cloned to.
  # @return [Git::Base]
  #   A git object representing the local repository.
  def self.clone_directory(namespace, module_name, output_path)
    puts '*************************************'
    puts "Cloning to: #{module_name} to #{output_path}."
    Git.clone("git@github.com:#{namespace}/#{module_name}.git", output_path.to_s) # is returned
  rescue Git::GitExecuteError
    puts '*************************************'
    puts "(FAILURE) Cloning for #{module_name} failed - check the module name and namespace are correct."
  end

  # @summary
  #   This method when called will run the 'pdk update --force' command at the given location, with an error message being thrown if it is not successful.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @return [Integer]
  #   The status code of the pdk update run.
  def self.pdk_update(output_path)
    # Runs the pdk update command
    Dir.chdir(output_path) unless Dir.pwd == output_path
    puts '*************************************'
    _stdout, stderr, status = Open3.capture3('pdk update --force')
    if status != 0
      puts "(FAILURE) Unable to run `pdk update`: #{stderr}"
    else
      puts 'PDK Update has ran.'
    end
    status
  end

  # @summary
  #   This method when called will retrieve the template ref of the current module, i.e. the one that was navigated into in the 'pdk_update' method.
  # @param [String] metadata_file
  #   An optional input that can be used to set the location of the metadata file.
  # @return [String]
  #   A string value that represents the current pdk template.
  def self.return_template_ref(metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    data_hash = JSON.parse(file)
    data_hash['template-ref']
  end

  # @summary
  #   This method when called will checkout a new local branch of the given repository.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository to be branched.
  # @param [String] template_ref
  #   The unique template_ref that is used as part of the branch name.
  def self.checkout_branch(git_repo, template_ref)
    puts '*************************************'
    puts "Creating a branch called: pdksync_#{template_ref}."
    git_repo.branch("pdksync_#{template_ref}".to_s).checkout
  end

  # @summary
  #   This method when called will retrieve the pdk_version of the current module, i.e. the one that was navigated into in the 'pdk_update' method.
  # @param [String] metadata_file
  #   An optional input that can be used to set the location of the metadata file.
  # @return [String]
  #   A string value that represents the current pdk version.
  def self.return_pdk_version(metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    data_hash = JSON.parse(file)
    data_hash['pdk-version']
  end

  # @summary
  #   This method when called will stage all changed files within the given repository, conditional on them being managed via the pdk.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository to be staged.
  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts '*************************************'
    puts 'All files have been staged.'
  end

  # @summary
  #   This method when called will create a commit containing all currently staged files, with the name of the commit containing the template ref as a unique identifier.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository against which the commit is to be made.
  # @param [String] template_ref
  #   The unique template_ref that is used as part of the commit name.
  def self.commit_staged_files(git_repo, template_ref)
    git_repo.commit("pdksync_#{template_ref}")
    puts '*************************************'
    puts "The following commit has been created: pdksync_#{template_ref}."
  end

  # @summary
  #   This method when called will push the given local commit to local repository's origin.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository againt which the push is to be made.
  # @param [String] template_ref
  #   The unique reference that that represents the template the update has ran against.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  def self.push_staged_files(git_repo, template_ref, repo_name)
    git_repo.push(@push_file_destination, "pdksync_#{template_ref}")
    puts '*************************************'
    puts 'All staged files have been pushed to the repo, bon voyage!'
  rescue StandardError
    puts '*************************************'
    puts "(FAILURE) Pushing to #{@push_file_destination} has failed for #{repo_name}"
  end

  # @summary
  #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the master with the pdk version as an identifier.
  # @param [Octokit::Client] client
  #   The octokit client used to gain access to and manipulate the repository.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  # @param [String] template_ref
  #   The unique reference that that represents the template the update has ran against.
  # @param [String] pdk_version
  #   The current version of the pdk on which the update is run.
  def self.create_pr(client, repo_name, template_ref, pdk_version)
    pr = client.create_pull_request(repo_name, @create_pr_against,
                                    "pdksync_#{template_ref}".to_s,
                                    "pdksync - Update using #{pdk_version}",
                                    "pdk version: `#{pdk_version}` \n pdk template ref: `#{template_ref}`")
    puts '*************************************'
    puts 'The PR has been created.'
    pr
  rescue StandardError
    puts '*************************************'
    puts "(FAILURE) PR creation has failed for #{repo_name}"
  end
end
