# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'pdksync/constants'
require 'pdksync/gitplatformclient'
require 'json'
require 'yaml'
require 'colorize'
require 'bundler'

# @summary
#   This module set's out and controls the pdksync process
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
# @param [Symbol] @git_platform
#   The Git hosting platform to use for pull requests
# @param [String] @git_base_uri
#   The base URI for Git repository access, for example 'https://github.com' or
#   'ssh://git@repo.example.com:2222'
# @param [Hash] @git_platform_access_settings
#   Hash of access settings required to access the configured Git hosting
#   platform API. Must always contain the key :access_token set to the exported
#   GITHUB_TOKEN or GITLAB_TOKEN. In case of Gitlab it also must contain the
#   key :gitlab_api_endpoint with an appropriate value.
module PdkSync
  include Constants
  @namespace = Constants::NAMESPACE
  @pdksync_dir = Constants::PDKSYNC_DIR
  @push_file_destination = Constants::PUSH_FILE_DESTINATION
  @create_pr_against = Constants::CREATE_PR_AGAINST
  @managed_modules = Constants::MANAGED_MODULES
  @default_pdksync_label = Constants::PDKSYNC_LABEL
  @git_platform = Constants::GIT_PLATFORM
  @git_base_uri = Constants::GIT_BASE_URI
  @git_platform_access_settings = {
    access_token: Constants::ACCESS_TOKEN,
    gitlab_api_endpoint: Constants::GITLAB_API_ENDPOINT
  }

  def self.main(steps: [:clone], args: nil)
    create_filespace
    client = setup_client
    module_names = return_modules
    raise "No modules found in '#{@managed_modules}'" if module_names.nil?
    validate_modules_exist(client, module_names)
    pr_list = []

    # The current directory is saved for cleanup purposes
    main_path = Dir.pwd

    # validation run_a_command
    if steps.include?(:run_a_command)
      raise '"run_a_command" requires an argument to run.' if args.nil?
      puts "Command '#{args}'"
    end
    # validation create_commit
    if steps.include?(:create_commit)
      raise 'Needs a branch_name and commit_message' if args.nil? || args[:commit_message].nil? || args[:branch_name].nil?
      puts "Commit branch_name=#{args[:branch_name]} commit_message=#{args[:commit_message]}"
    end
    # validation push_and_create_pr
    if steps.include?(:push_and_create_pr)
      raise 'Needs a pr_title' if args.nil? || args[:pr_title].nil?
      puts "PR title =#{args[:additional_title]} #{args[:pr_title]}"
    end
    # validation clean_branches
    if steps.include?(:clean_branches)
      raise 'Needs a branch_name, and the branch name contains the string pdksync' if args.nil? || args[:branch_name].nil? || !args[:branch_name].include?('pdksync')
      puts "Removing branch_name =#{args[:branch_name]}"
    end

    abort "No modules listed in #{@managed_modules}" if module_names.nil?
    module_names.each do |module_name|
      module_args = args.clone
      Dir.chdir(main_path) unless Dir.pwd == main_path
      print "#{module_name}, "
      repo_name = "#{@namespace}/#{module_name}"
      output_path = "#{@pdksync_dir}/#{module_name}"
      if steps.include?(:clone)
        clean_env(output_path) if Dir.exist?(output_path)
        print 'delete module directory, '
        @git_repo = clone_directory(@namespace, module_name, output_path)
        print 'cloned, '
        puts "(WARNING) Unable to clone repo for #{module_name}".red if @git_repo.nil?
        Dir.chdir(main_path) unless Dir.pwd == main_path
        next if @git_repo.nil?
      end
      puts '(WARNING) @output_path does not exist, skipping module'.red unless File.directory?(output_path)
      next unless File.directory?(output_path)
      if steps.include?(:pdk_convert)
        exit_status = run_command(output_path, "#{return_pdk_path} convert --force --template-url https://github.com/puppetlabs/pdk-templates")
        print 'converted, '
        next unless exit_status.zero?
      end
      if steps.include?(:pdk_validate)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = run_command(output_path, "#{return_pdk_path} validate -a")
        print 'validated, '
        next unless exit_status.zero?
      end
      if steps.include?(:run_a_command)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'run command, '
        exit_status = run_command(output_path, module_args)
        next unless exit_status.zero?
      end
      if steps.include?(:pdk_update)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        next unless pdk_update(output_path).zero?
        if steps.include?(:use_pdk_ref)
          ref = return_template_ref
          pr_title = module_args[:additional_title] ? "#{module_args[:additional_title]} - pdksync_#{ref}" : "pdksync_#{ref}"
          module_args = module_args.merge(branch_name: "pdksync_#{ref}",
                                          commit_message: pr_title,
                                          pr_title: pr_title,
                                          pdksync_label: @default_pdksync_label)
        end
        print 'pdk update, '
      end
      if steps.include?(:create_commit)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        create_commit(git_instance, module_args[:branch_name], module_args[:commit_message])
        print 'commit created, '
      end
      if steps.include?(:push_and_create_pr)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        push_staged_files(git_instance, git_instance.current_branch, repo_name)
        print 'push, '
        pdk_version = return_pdk_version("#{output_path}/metadata.json")

        # If a label is supplied, verify that it is available in the repo
        label = module_args[:pdksync_label] ? module_args[:pdksync_label] : module_args[:label]
        label_valid = (label.is_a?(String) && !label.to_str.empty?) ? check_for_label(client, repo_name, label) : nil

        # Exit current iteration if an error occured retrieving a label
        if label_valid == false
          raise 'Ensure label is valid'
        end

        # Create the PR and add link to pr list
        pr = create_pr(client, repo_name, git_instance.current_branch, pdk_version, module_args[:pr_title])
        if pr.nil?
          break
        end

        pr_list.push(pr.html_url)
        print 'created pr, '

        # If a valid label is supplied, add this to the PR
        if label_valid == true
          add_label(client, repo_name, pr.number, label)
          print "added label '#{label}' "
        end
      end
      if steps.include?(:clean_branches)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        delete_branch(client, repo_name, module_args[:branch_name])
        print 'branch deleted, '
      end
      puts 'done.'.green
    end
    return if pr_list.size.zero?
    puts "\nPRs created:\n".blue
    pr_list.each do |pr|
      puts pr
    end
  end

  # @summary
  #   This method when called will create a directory identified by the set global variable '@pdksync_dir', on the condition that it does not already exist.
  def self.create_filespace
    FileUtils.mkdir @pdksync_dir unless Dir.exist?(@pdksync_dir)
  end

  # @summary
  #   This method when called will create and return an octokit client with access to the upstream git repositories.
  # @return [PdkSync::GitPlatformClient] client
  #   The Git platform client that has been created.
  def self.setup_client
    PdkSync::GitPlatformClient.new(@git_platform, @git_platform_access_settings)
  rescue StandardError => error
    raise "Git platform access not set up correctly: #{error}"
  end

  # @summary
  #   This method when called will access a file set by the global variable '@managed_modules' and retrieve the information within as an array.
  # @return [Array]
  #   An array of different module names.
  def self.return_modules
    raise "File '#{@managed_modules}' is empty/does not exist" if File.size?(@managed_modules).nil?
    YAML.safe_load(File.open(@managed_modules))
  end

  # @summary
  #   This method when called will parse an array of module names and verify
  #   whether they are valid repo or project names on the configured Git
  #   hosting platform.
  # @param [PdkSync::GitPlatformClient] client
  #   The Git platform client used to get a repository.
  # @param [Array] module_names
  #   String array of the names of Git platform repos
  def self.validate_modules_exist(client, module_names)
    invalid_names = []
    raise "Error reading in modules. Check syntax of '#{@managed_modules}'." unless !module_names.nil? && module_names.is_a?(Array)
    module_names.each do |module_name|
      # If module name is invalid, push it to invalid names array
      unless client.repository?("#{@namespace}/#{module_name}")
        invalid_names.push(module_name)
        next
      end
    end
    # Raise error if any invalid matches were found
    raise "Could not find the following repositories: #{invalid_names}" unless invalid_names.empty?
  end

  # @summary
  #   Try to use a fully installed pdk, otherwise fall back to the bundled pdk gem.
  # @return String
  #   Path to the pdk executable
  def self.return_pdk_path
    full_path = '/opt/puppetlabs/pdk/bin/pdk'
    path = if File.executable?(full_path)
             full_path
           else
             puts "(WARNING) Using pdk on PATH not '#{full_path}'".red
             'pdk'
           end
    path
  end

  def self.create_commit(git_repo, branch_name, commit_message)
    checkout_branch(git_repo, branch_name)
    add_staged_files(git_repo)
    commit_staged_files(git_repo, branch_name, commit_message)
  end

  # @summary
  #   This method when called will call the delete function against the given repository if it exists.
  # @param [String] output_path
  #   The repository that is to be deleted.
  def self.clean_env(output_path)
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
    Git.clone("#{@git_base_uri}/#{namespace}/#{module_name}.git", output_path.to_s) # is returned
  rescue Git::GitExecuteError => error
    puts "(FAILURE) Cloning #{module_name} has failed. #{error}".red
  end

  # @summary
  #   This method when called will run a command command at the given location, with an error message being thrown if it is not successful.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] command
  #   The command to be run.
  # @return [Integer]
  #   The status code of the command run.
  def self.run_command(output_path, command)
    stdout = ''
    stderr = ''
    status = Process::Status

    Dir.chdir(output_path) unless Dir.pwd == output_path

    # Environment cleanup required due to Ruby subshells using current Bundler environment
    if command =~ %r{^bundle}
      Bundler.with_clean_env do
        stdout, stderr, status = Open3.capture3(command)
      end
    else
      stdout, stderr, status = Open3.capture3(command)
    end

    puts "\n#{stdout}\n".yellow
    puts "(FAILURE) Unable to run command '#{command}': #{stderr}".red unless status.exitstatus.zero?
    status.exitstatus
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
    _stdout, stderr, status = Open3.capture3("#{return_pdk_path} update --force")
    puts "(FAILURE) Unable to run `pdk update`: #{stderr}".red unless status.exitstatus.zero?
    status.exitstatus
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
  # @param [String] branch_suffix
  #   The string that is appended on the branch name. eg template_ref or a friendly name
  def self.checkout_branch(git_repo, branch_suffix)
    git_repo.branch("pdksync_#{branch_suffix}").checkout
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
    if git_repo.status.changed != {}
      git_repo.add(all: true)
      puts 'All files have been staged.'
    else
      puts 'Nothing to commit.'
    end
  end

  # @summary
  #   This method when called will create a commit containing all currently staged files, with the name of the commit containing the template ref as a unique identifier.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository against which the commit is to be made.
  # @param [String] template_ref
  #   The unique template_ref that is used as part of the commit name.
  # @param [String] commit_message
  #   If specified it will be the message for the commit.
  def self.commit_staged_files(git_repo, template_ref, commit_message = nil)
    message = if commit_message.nil?
                "pdksync_#{template_ref}"
              else
                commit_message
              end
    git_repo.commit(message)
  end

  # @summary
  #   This method when called will push the given local commit to local repository's origin.
  # @param [Git::Base] git_repo
  #   A git object representing the local repository againt which the push is to be made.
  # @param [String] template_ref
  #   The unique reference that that represents the template the update has ran against.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  def self.push_staged_files(git_repo, current_branch, repo_name)
    git_repo.push(@push_file_destination, current_branch)
  rescue StandardError => error
    puts "(FAILURE) Pushing to #{@push_file_destination} for #{repo_name} has failed. #{error}".red
  end

  # @summary
  #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the master with the pdk version as an identifier.
  # @param [PdkSync::GitPlatformClient] client
  #   The Git platform client used to gain access to and manipulate the repository.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  # @param [String] template_ref
  #   The unique reference that that represents the template the update has ran against.
  # @param [String] pdk_version
  #   The current version of the pdk on which the update is run.
  def self.create_pr(client, repo_name, template_ref, pdk_version, pr_title = nil)
    if pr_title.nil?
      title = "pdksync - Update using #{pdk_version}"
      message = "pdk version: `#{pdk_version}` \n pdk template ref: `#{template_ref}`"
      head = "pdksync_#{template_ref}"
    else
      title = "pdksync - #{pr_title}"
      message = "#{pr_title}\npdk version: `#{pdk_version}` \n"
      head = template_ref
    end
    pr = client.create_pull_request(repo_name, @create_pr_against,
                                    head,
                                    title,
                                    message)
    pr
  rescue StandardError => error
    puts "(FAILURE) PR creation for #{repo_name} has failed. #{error}".red
  end

  # @summary
  #   This method when called will check on the given repository for the existence of the supplied label
  # @param [PdkSync::GitPlatformClient] client
  #   The Git platform client used to gain access to and manipulate the repository.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  # @param [String] label
  #   The label to check for.
  # @return [Boolean]
  #   A boolean stating whether the label was found.
  def self.check_for_label(client, repo_name, label)
    # Get labels from repository
    repo_labels = client.labels(repo_name)

    # Look for label in the repository's labels
    match = false
    repo_labels.each do |repo_label|
      if repo_label.name == label
        match = true
        break
      end
    end

    # Raise error if a match was not found else return true
    (match == false) ? (raise StandardError, "Label '#{label}' not found in #{repo_name}") : (return true)
  rescue StandardError => error
    puts "(FAILURE) Retrieving labels for #{repo_name} has failed. #{error}".red
    return false
  end

  # @summary
  #   This method when called will add a given label to a given repository
  # @param [PdkSync::GitPlatformClient] client
  #   The Git Platform client used to gain access to and manipulate the repository.
  # @param [String] repo_name
  #   The name of the repository on which the commit is to be made.
  # @param [Integer] issue_number
  #   The id of the issue (i.e. pull request) to add the label to.
  # @param [String] label
  #   The label to add.
  def self.add_label(client, repo_name, issue_number, label)
    client.update_issue(repo_name, issue_number, labels: [label])
  rescue StandardError => error
    puts "(FAILURE) Adding label to #{repo_name} issue #{issue_number} has failed. #{error}".red
    return false
  end

  # @summary
  #   This method when called will delete any preexisting branch on the given repository that matches the given name.
  # @param [PdkSync::GitPlatformClient] client
  #   The Git platform client used to gain access to and manipulate the repository.
  # @param [String] repo_name
  #   The name of the repository from which the branch is to be deleted.
  # @param [String] branch_name
  #   The name of the branch that is to be deleted.
  def self.delete_branch(client, repo_name, branch_name)
    client.delete_branch(repo_name, branch_name)
  rescue StandardError => error
    puts "(FAILURE) Deleting #{branch_name} in #{repo_name} failed. #{error}".red
  end
end
