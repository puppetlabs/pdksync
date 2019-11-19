# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'pdksync/configuration'
require 'pdksync/gitplatformclient'
require 'json'
require 'yaml'
require 'colorize'
require 'bundler'
require 'octokit'
require 'pdk/util/template_uri'
require 'pdksync/logger'
require 'pry'
require 'terminal-table'

# @summary
#   This module set's out and controls the pdksync process
module PdkSync
  def self.configuration
    @configuration ||= PdkSync::Configuration.new
  end
  @main_path = Dir.pwd

  def self.main(steps: [:clone], args: nil)
    check_pdk_version if ENV['PDKSYNC_VERSION_CHECK'].eql?('true')
    create_filespace
    client = setup_client
    module_names = return_modules
    raise "No modules found in '#{configuration.managed_modules}'" if module_names.nil?
    validate_modules_exist(client, module_names)
    pr_list = []
    report_rows = []
    table = Terminal::Table.new

    # The current directory is saved for cleanup purposes
    main_path = Dir.pwd

    # validation run_a_command
    if steps.include?(:run_a_command)
      raise '"run_a_command" requires an argument to run.' if args.nil?
      PdkSync::Logger.info "Command '#{args}'"
    end
    # validation create_commit
    if steps.include?(:create_commit)
      raise 'Needs a branch_name and commit_message' if args.nil? || args[:commit_message].nil? || args[:branch_name].nil?
      PdkSync::Logger.info "Commit branch_name=#{args[:branch_name]} commit_message=#{args[:commit_message]}"
    end
    # validation create_pr
    if steps.include?(:create_pr)
      raise 'Needs a pr_title' if args.nil? || args[:pr_title].nil?
      PdkSync::Logger.info "PR title =#{args[:additional_title]} #{args[:pr_title]}"
    end
    # validation clean_branches
    if steps.include?(:clean_branches)
      raise 'Needs a branch_name, and the branch name contains the string pdksync' if args.nil? || args[:branch_name].nil? || !args[:branch_name].include?('pdksync')
      PdkSync::Logger.info "Removing branch_name =#{args[:branch_name]}"
    end
    # validation gem_file_update
    if steps.include?(:gem_file_update)
      raise 'gem_file_update requires arguments (gem_to_test) to run.' if args[:gem_to_test].nil?
      puts "Command '#{args}'"
    end
    # validation run_tests_locally
    if steps.include?(:run_tests_locally)
      puts "Command '#{args}'"
    end
    # validation fetch_test_results_locally
    if steps.include?(:fetch_test_results_locally)
      puts "Command '#{args}'"
    end

    abort "No modules listed in #{configuration.managed_modules}" if module_names.nil?
    module_names.each do |module_name|
      module_args = args.clone
      Dir.chdir(main_path) unless Dir.pwd == main_path
      PdkSync::Logger.info "#{module_name}, "
      repo_name = "#{configuration.namespace}/#{module_name}"
      output_path = "#{configuration.pdksync_dir}/#{module_name}"
      if steps.include?(:clone)
        clean_env(output_path) if Dir.exist?(output_path)
        PdkSync::Logger.info 'delete module directory'
        @git_repo = clone_directory(configuration.namespace, module_name, output_path)
        PdkSync::Logger.info 'cloned'
        PdkSync::Logger.error "Unable to clone repo for #{module_name}" if @git_repo.nil?
        Dir.chdir(main_path) unless Dir.pwd == main_path
        next if @git_repo.nil?
      end
      PdkSync::Logger.warn "#{output_path} does not exist, skipping module" unless File.directory?(output_path)
      next unless File.directory?(output_path)
      if steps.include?(:pdk_convert)
        exit_status = run_command(output_path, "#{return_pdk_path} convert --force #{configuration.templates}", nil)
        PdkSync::Logger.info 'converted'
        next unless exit_status.zero?
      end
      if steps.include?(:pdk_validate)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = run_command(output_path, "#{return_pdk_path} validate -a", nil)
        PdkSync::Logger.info 'validated'
        next unless exit_status.zero?
      end
      if steps.include?(:run_a_command)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        PdkSync::Logger.info 'run command'
        if module_args[:option].nil?
          pid = run_command(output_path, module_args[:command], module_args[:option])
          next unless pid != 0
        else
          exit_status = run_command(output_path, module_args[:command], nil)
          next unless exit_status.zero?
        end
      end
      if steps.include?(:gem_file_update)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'gem file update, '
        gem_file_update(output_path, module_args[:gem_to_test], module_args[:gem_line], module_args[:gem_sha_finder], module_args[:gem_sha_replacer], module_args[:gem_version_finder], module_args[:gem_version_replacer], module_args[:gem_branch_finder], module_args[:gem_branch_replacer]) # rubocop:disable Metrics/LineLength
        print 'gem file updated, '
      end
      if steps.include?(:run_tests_locally)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'Run tests '
        module_type = module_type(output_path, module_name)
        run_tests_locally(output_path, module_type, module_args[:provision_type], module_name, module_args[:puppet_collection])
      end
      if steps.include?(:fetch_test_results_locally)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'Fetch test results for local run '
        module_type = module_type(output_path, module_name)
        table = fetch_test_results_locally(output_path, module_type, module_name, report_rows)
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
                                          pdksync_label: configuration.default_pdksync_label)
        end
        PdkSync::Logger.info 'pdk update'
      end
      if steps.include?(:use_gem_ref)
        pr_title = module_args[:additional_title] ? "#{module_args[:additional_title]} - pdksync_gem_testing" : 'pdksync_gem_testing'
        module_args = module_args.merge(branch_name: "gem_testing_#{module_args[:gem_to_test]}",
                                        commit_message: pr_title,
                                        pr_title: pr_title,
                                        pdksync_label: @default_pdksync_label)
      end
      if steps.include?(:create_commit)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        create_commit(git_instance, module_args[:branch_name], module_args[:commit_message])
        PdkSync::Logger.info 'commit created'
      end
      if steps.include?(:push)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        if git_instance.diff(git_instance.current_branch, "#{configuration.push_file_destination}/#{configuration.create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
          PdkSync::Logger.info 'push'
          push_staged_files(git_instance, git_instance.current_branch, repo_name)
        else
          PdkSync::Logger.info 'skipped push'
        end
      end
      if steps.include?(:create_pr)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        if git_instance.diff(git_instance.current_branch, "#{configuration.push_file_destination}/#{configuration.create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
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
          break if pr.nil?

          pr_list.push(pr.html_url)
          PdkSync::Logger.info 'created pr'

          # If a valid label is supplied, add this to the PR
          if label_valid == true
            add_label(client, repo_name, pr.number, label)
            PdkSync::Logger.info "added label '#{label}' "
          end
        else
          PdkSync::Logger.info 'skipped pr'
        end
      end
      if steps.include?(:clean_branches)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        delete_branch(client, repo_name, module_args[:branch_name])
        PdkSync::Logger.info 'branch deleted'
      end
      PdkSync::Logger.info 'done'
    end
    table = Terminal::Table.new title: 'Module Test Results', headings: %w[Module Status Result From], rows: report_rows
    puts table if steps.include?(:fetch_test_results_locally)
    return if pr_list.size.zero?
    PdkSync::Logger.info "\nPRs created:\n"
    puts pr_list.join("\n")
  end

  # @summary
  #   Check the local pdk version against the most recent tagged release on GitHub
  def self.check_pdk_version
    stdout, _stderr, status = Open3.capture3("#{return_pdk_path} --version")
    PdkSync::Logger.fatal "Unable to find pdk at '#{return_pdk_path}'." unless status.exitstatus

    local_version = stdout.strip
    remote_version = Octokit.tags('puppetlabs/pdk').first[:name][1..-1]

    unless Gem::Version.new(remote_version) <= Gem::Version.new(local_version)
      PdkSync::Logger.warn "The current version of pdk is #{remote_version} however you are using #{local_version}"
    end
  rescue StandardError => error
    PdkSync::Logger.warn "Unable to check latest pdk version. #{error}"
  end

  # @summary
  #   This method when called will create a directory identified by the set global variable 'configuration.pdksync_dir', on the condition that it does not already exist.
  def self.create_filespace
    FileUtils.mkdir configuration.pdksync_dir unless Dir.exist?(configuration.pdksync_dir)
  end

  # @summary
  #   This method when called will create and return an octokit client with access to the upstream git repositories.
  # @return [PdkSync::GitPlatformClient] client
  #   The Git platform client that has been created.
  def self.setup_client
    PdkSync::GitPlatformClient.new(configuration.git_platform, configuration.git_platform_access_settings)
  rescue StandardError => error
    raise "Git platform access not set up correctly: #{error}"
  end

  # @summary
  #   This method when called will access a file set by the global variable 'configuration.managed_modules' and retrieve the information within as an array.
  # @return [Array]
  #   An array of different module names.
  def self.return_modules
    raise "File '#{configuration.managed_modules}' is empty/does not exist" if File.size?(configuration.managed_modules).nil?
    YAML.safe_load(File.open(configuration.managed_modules))
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
    raise "Error reading in modules. Check syntax of '#{configuration.managed_modules}'." unless !module_names.nil? && module_names.is_a?(Array)
    module_names.each do |module_name|
      # If module name is invalid, push it to invalid names array
      unless client.repository?("#{configuration.namespace}/#{module_name}")
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
             PdkSync::Logger.warn "(WARNING) Using pdk on PATH not '#{full_path}'"
             'pdk'
           end
    path
  end

  def self.create_commit(git_repo, branch_name, commit_message)
    checkout_branch(git_repo, branch_name)
    if add_staged_files(git_repo) # ignore rubocop for clarity on side effect ordering # rubocop:disable Style/GuardClause
      commit_staged_files(git_repo, branch_name, commit_message)
    end
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
    # not all urls are public facing so we need to conditionally use the correct separator
    sep = configuration.git_base_uri.start_with?('git@') ? ':' : '/'
    clone_url = "#{configuration.git_base_uri}#{sep}#{namespace}/#{module_name}.git"
    Git.clone(clone_url, output_path.to_s) # is returned
  rescue Git::GitExecuteError => error
    PdkSync::Logger.fatal "Cloning #{module_name} has failed. #{error}"
  end

  # @summary
  #   This method when called will run a command command at the given location, with an error message being thrown if it is not successful.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] command
  #   The command to be run.
  # @return [Integer]
  #   The status code of the command run.
  def self.run_command(output_path, command, option)
    stdout = ''
    stderr = ''
    status = Process::Status
    pid = ''
    Dir.chdir(output_path) unless Dir.pwd == output_path

    # Environment cleanup required due to Ruby subshells using current Bundler environment
    if option.nil? == true
      if command =~ %r{^bundle}
        Bundler.with_clean_env do
          stdout, stderr, status = Open3.capture3(command)
        end
      else
        stdout, stderr, status = Open3.capture3(command)
      end
      PdkSync::Logger.info "\n#{stdout}\n"
      PdkSync::Logger.fatal "Unable to run command '#{command}': #{stderr}" unless status.exitstatus.zero?
      status.exitstatus
    else
      # Environment cleanup required due to Ruby subshells using current Bundler environment
      if command =~ %r{^sh }
        Bundler.with_clean_env do
          pid = spawn(command, out: 'run_command.out', err: 'run_command.err')
          Process.detach(pid)
        end
      end
      pid
    end
  end

  # @summary
  #   This method when called will find the source location of the gem to test
  # @param [String] gem_to_test
  #   The gem to test
  # @param [String] gem_line
  #   TThe line to update in the Gemfile
  # @return [String]
  #   The source location of the gem to test
  def self.get_source_test_gem(gem_to_test, gem_line)
    return gem_line.split(',') if gem_line
    return gem_to_test unless gem_to_test

    gemfile_line = File.readlines('Gemfile').find do |line|
      line.include?(gem_to_test.to_s)
    end

    return "https://github.com/puppetlabs/#{gem_to_test}" unless gemfile_line
    gemfile_line =~ %r{(http|https|ftp|ftps)\:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,3}(\/\S*)?}
    line.split(',')[1].strip.to_s if line
  end

  # @summary
  #   This method when called will validate the gem_line to update in the Gemfile
  # @param [String] gem_to_test
  #   The gem to test
  # @param [String] gem_line
  #   The line to update in the Gemfile
  def self.validate_gem_update_module(gem_to_test, gem_line)
    gem_to_test = gem_to_test.chomp('"').reverse.chomp('"').reverse
    Dir.chdir(@main_path)
    output_path = "#{configuration.pdksync_dir}/#{gem_to_test}"
    clean_env(output_path) if Dir.exist?(output_path)
    print 'delete module directory, '

    # when gem_line is specified, we need to parse the line and identify all the values
    # - we can have source url or we need to
    # - sha, branch, version
    if gem_line
      git_repo = get_source_test_gem(gem_to_test, gem_line)
      i = 0
      git_repo.each do |item|
        i += 1
        if item =~ %r{((git@|http(s)?:\/\/)([\w\.@]+)(\/|:))([\w,\-,\_]+)\/([\w,\-,\_]+)(.git){0,1}((\/){0,1})}
          git_repo = item.split('git:')[1]
          break
        elsif git_repo.size == i
          git_repo = "https://github.com/puppetlabs#{gem_to_test}"
        end
      end

      print 'delete module directory, '
      git_repo = run_command(configuration.pdksync_dir.to_s, "git clone #{git_repo}", nil)
    elsif gem_to_test
      git_repo = clone_directory(configuration.namespace, gem_to_test, output_path.to_s)
    end

    Dir.chdir(@main_path)
    raise "Unable to clone repo for #{gem_to_test}. Check repository's url to be correct!".red if git_repo.nil?

    @all_versions = ''
    @all_refs = ''
    @all_branches = ''

    Dir.chdir(output_path)
    stdout_refs, stderr_refs, status_refs = Open3.capture3('git show-ref -s')
    @all_refs = stdout_refs
    stdout_branches, stderr_branches, status_branches = Open3.capture3('git branch -a')
    @all_branches = stdout_branches
    stdout_versions, stderr_versions, status_versions = Open3.capture3('git tag')
    @all_versions = stdout_versions

    raise "Couldn't get references due to #{stderr_refs}".red unless status_refs.exitstatus.zero?
    raise "Couldn't get branches due to #{stderr_branches}".red unless status_branches.exitstatus.zero?
    raise "Couldn't get versions due to #{stderr_versions}".red unless status_versions.exitstatus.zero?
    Dir.chdir(@main_path)
  end

  # @summary
  #   This method when called will validate the gem_sha_replacer to update in the Gemfile
  # @param [String] gem_to_test
  #   The gem to test
  # @param [String] gem_sha_replacer
  #   The sha to update in the Gemfile
  def self.validate_gem_sha_replacer(gem_sha_replacer, gem_to_test)
    found = false
    @all_refs.split(' ').each do |sha|
      puts "SHA #{gem_sha_replacer} valid.\n".green if gem_sha_replacer == sha
      found = true if gem_sha_replacer == sha
    end
    raise "Couldn't find sha: #{gem_sha_replacer} in your repository: #{gem_to_test}".red if found == false
  end

  # @summary
  #   This method when called will validate the gem_branch_replacer to update in the Gemfile
  # @param [String] gem_to_test
  #   The gem to test
  # @param [String] gem_branch_replacer
  #   The branch to update in the Gemfile
  def self.validate_gem_branch_replacer(gem_branch_replacer, gem_to_test)
    raise "Couldn't find branch: #{gem_branch_replacer} in your repository: #{gem_to_test}".red unless @all_branches.include?(gem_branch_replacer)
    puts "Branch #{gem_branch_replacer} valid.\n".green
  end

  # @summary
  #   This method when called will validate the gem_version_replacer to update in the Gemfile
  # @param [String] gem_to_test
  #   The gem to test
  # @param [String] gem_version_replacer
  #   The version to update in the Gemfile
  def self.validate_gem_version_replacer(gem_version_replacer, gem_to_test)
    found = false
    @all_versions.split(' ').each do |version|
      puts "Version #{gem_version_replacer} valid.\n".green if gem_version_replacer == version
      found = true if gem_version_replacer == version
    end
    raise "Couldn't find version: #{gem_version_replacer} in your repository: #{gem_to_test}".red if found == false
  end

  # @summary
  #   This method when called will update a Gemfile and remove the existing version of gem from the Gemfile.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] gem_to_test
  #   The Gem to test.
  # @param [String] gem_line
  #   The gem line to replace
  # @param [String] gem_sha_finder
  #   The gem sha to find
  # @param [String] gem_sha_replacer
  #   The gem sha to replace
  # @param [String] gem_version_finder
  #   The gem version to find
  # @param [String] gem_version_replacer
  #   The gem version to replace
  # @param [String] gem_branch_finder
  #   The gem branch to find
  # @param [String] gem_branch_replacer
  #   The gem branch to replace
  def self.gem_file_update(output_path, gem_to_test, gem_line, gem_sha_finder, gem_sha_replacer, gem_version_finder, gem_version_replacer, gem_branch_finder, gem_branch_replacer)
    gem_file_name = 'Gemfile'

    validate_gem_update_module(gem_to_test, gem_line)

    if (gem_line.nil? == false) && (gem_sha_replacer != '\"\"')
      new_data = get_source_test_gem(gem_to_test, gem_line)
      new_data.each do |data|
        if data.include?('branch')
          gem_branch_replacer = data.split(' ')[1].strip.chomp('"').delete("'")
        elsif data.include?('ref')
          gem_sha_replacer = data.split(' ')[1].strip.chomp('').delete("'")
        elsif data =~ %r{~>|=|>=|<=|<|>}
          delimiters = ['>', '<', '>=', '<=', '=']
          version_to_check = data.split(Regexp.union(delimiters))[1].chomp('""').delete("'")
          validate_gem_version_replacer(version_to_check.to_s, gem_to_test)
        end
      end
    end

    if gem_sha_replacer.nil? == false && gem_sha_replacer != '\"\"' && gem_sha_replacer != ''
      validate_gem_sha_replacer(gem_sha_replacer.chomp('"').reverse.chomp('"').reverse, gem_to_test)
    end
    if gem_branch_replacer.nil? == false && gem_branch_replacer != '\"\"'
      validate_gem_branch_replacer(gem_branch_replacer.chomp('"').reverse.chomp('"').reverse, gem_to_test)
    end
    if gem_version_replacer.nil? == false && gem_version_replacer != '\"\"' && gem_version_replacer != ''
      delimiters = ['<', '>', '<=', '>=', '=']
      version_to_check = gem_version_replacer.split(Regexp.union(delimiters))
      version_to_check.each do |version|
        next if version.nil?
        validate_gem_version_replacer(version.to_s, gem_to_test) unless version == ''
      end
    end

    Dir.chdir(output_path) unless Dir.pwd == output_path

    line_number = 1
    gem_update_sha = [
      { finder: "ref: '#{gem_sha_finder}'",
        replacer: "ref: '#{gem_sha_replacer}'" }
    ]
    gem_update_version = [
      { finder: gem_version_finder,
        replacer: gem_version_replacer }
    ]
    gem_update_branch = [
      { finder: "branch: '#{gem_branch_finder}'",
        replacer: "branch: '#{gem_branch_replacer}'" }
    ]
    # gem_line option is passed

    if gem_line.nil? == false && (gem_line != '' || gem_line != '\"\"')

      # Delete the gem in the Gemfile to add the new line
      gem_test = gem_to_test.chomp('"').reverse.chomp('"').reverse
      File.open('/tmp/out.tmp', 'w') do |out_file|
        File.foreach(gem_file_name) do |line|
          out_file.puts line unless line =~ %r{#{gem_test}}
        end
      end
      FileUtils.mv('/tmp/out.tmp', gem_file_name)

      # Insert the new Gem to test
      file = File.open(gem_file_name)
      contents = file.readlines.map(&:chomp)
      contents.insert(line_number, gem_line.chomp('"').reverse.chomp('"').reverse)
      File.open(gem_file_name, 'w') { |f| f.write contents.join("\n") }
    end

    # gem_sha_finder and gem_sha_replacer options are passed
    if gem_sha_finder.nil? == false && gem_sha_replacer.nil? == false && gem_sha_finder != '' && gem_sha_finder != '\"\"' && gem_sha_replacer != '' && gem_sha_replacer != '\"\"'
      # Replace with SHA
      file = File.open(gem_file_name)
      contents = file.readlines.join
      gem_update_sha.each do |regex|
        contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer])
      end
      File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
    end

    # gem_version_finder and gem_version_replacer options are passed
    if gem_version_finder.nil? == false && gem_version_replacer.nil? == false && gem_version_finder != '' && gem_version_finder != '\"\"' && gem_version_replacer != '' && gem_version_replacer != '\"\"' # rubocop:disable Metrics/LineLength
      # Replace with version
      file = File.open(gem_file_name)
      contents = file.readlines.join
      gem_update_version.each do |regex|
        contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer])
      end
      File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
    end

    # gem_branch_finder and gem_branch_replacer options are passed
    if gem_branch_finder.nil? == false && gem_branch_replacer.nil? == false && gem_branch_finder != '' && gem_branch_finder != '\"\"' && gem_branch_replacer != '' && gem_branch_replacer != '\"\"' # rubocop:disable Metrics/LineLength, Style/GuardClause
      # Replace with branch
      file = File.open(gem_file_name)
      contents = file.readlines.join
      gem_update_branch.each do |regex|
        contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer]) # unless contents =~ %r{#{gem_to_test}}
      end
      File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
    end
  end

  # @summary
  #   This method is used to identify the type of module.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] repo_name
  #   The module name to identify the type
  def self.module_type(output_path, repo_name)
    if repo_name.nil? == false
      module_type = if File.exist?("#{output_path}/provision.yaml")
                      'litmus'
                    else
                      'traditional'
                    end
    end
    puts module_type
    module_type
  end

  # @summary
  #   This method when called will run the 'module tests' command at the given location, with an error message being thrown if it is not successful.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] module_type
  #   The module type (litmus or traditional)
  # @param [String] module_name
  #   The module name
  # @param [String] puppet collection
  #   The puppet collection
  # @return [Integer]
  #   The status code of the pdk update run.
  def self.run_tests_locally(output_path, module_type, provision_type, module_name, puppet_collection)
    provision_type = provision_type.chomp('"').reverse.chomp('"').reverse
    status = Process::Status
    # Save the current path
    old_path = Dir.pwd

    # Create the acceptance scripts
    file = File.open('acc.sh', 'w')
    file.puts '#!/bin/sh'

    if puppet_collection
      file.puts "export PUPPET_GEM_VERSION='~> #{puppet_collection}'"
    end
    file.puts "rm -rf #{output_path}/Gemfile.lock;rm -rf #{output_path}/.bundle"
    file.puts 'bundle install --path .bundle/gems/ --jobs 4'
    file.puts "bundle exec rake 'litmus:provision_list[#{provision_type}]'"
    file.puts 'bundle exec rake litmus:install_agent'
    file.puts 'bundle exec rake litmus:install_module'
    file.puts 'bundle exec rake litmus:acceptance:parallel'
    file.puts 'bundle exec rake litmus:tear_down'
    file.close

    # Runs the module tests command
    if module_type == 'litmus'
      run_command(output_path, 'cp ../../acc.sh .', nil)
      Dir.chdir(old_path)
      run_command(output_path, 'chmod 777 acc.sh', nil)
      Dir.chdir(old_path)
      status = run_command(output_path, 'sh acc.sh 2>&1 | tee litmusacceptance.out', 'background')
      if status != 0
        PdkSync::Logger.info "SUCCESS:Kicking of module Acceptance tests to run for the module #{module_name} - SUCCEED.Results will be available in the following path #{output_path}/litmusacceptance.out.Process id is #{status}"
      else
        PdkSync::Logger.fatal "FAILURE:Kicking of module Acceptance tests to run for the module #{module_name} - FAILED.Results will be available in the following path #{output_path}/litmusacceptance.out."
      end
    end
    PdkSync::Logger.warn "(WARNING) Executing testcases locally supports only for litmus'" if module_type != 'litmus'
  end

  # @summary
  #   This method when called will fetch the module tests results.
  # @param [String] output_path
  #   The location that the command is to be run from.
  # @param [String] module_type
  #   The module type (litmus or traditional)
  # @param [String] module_name
  #   The module name
  # @param [String] report_rows
  #   The module test results
  # @return [Integer]
  #   The status code of the pdk update run.
  def self.fetch_test_results_locally(output_path, module_type, module_name, report_rows)
    # Save the current path
    old_path = Dir.pwd
    if module_type != 'litmus'
      PdkSync::Logger.warn "(WARNING) Fetching test results locally supports only for litmus'"
    end

    # Run the tests
    Dir.chdir(old_path)
    lines = IO.readlines("#{output_path}/litmusacceptance.out")[-10..-1]
    if lines.find { |e| %r{exit} =~ e } # rubocop:disable Style/ConditionalAssignment
      report_rows << if lines.find { |e| %r{^Failed} =~ e } || lines.find { |e| %r{--trace} =~ e }
                       [module_name, 'FAILED', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                     else
                       [module_name, 'SUCCESS', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                     end
    else
      report_rows << if lines.find { |e| %r{^Failed} =~ e } || lines.find { |e| %r{--trace} =~ e } || lines.find { |e| %r{rake aborted} =~ e }
                       [module_name, 'FAILED', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                     else
                       [module_name, 'PROGRESS', "Results will be available in the following path #{output_path}/litmusacceptance.out"]
                     end
    end
    return report_rows if module_type == 'litmus'
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
    _, module_temp_ref = module_templates_url.split('#')
    module_temp_ref ||= configuration.pdk_templates_ref
    template_ref = configuration.module_is_authoritive ? module_temp_ref : configuration.pdk_templates_ref
    change_module_template_url(configuration.pdk_templates_url, template_ref) unless configuration.module_is_authoritive
    _stdout, stderr, status = Open3.capture3("#{return_pdk_path} update --force --template-ref=#{template_ref}")
    PdkSync::Logger.fatal "Unable to run `pdk update`: #{stderr}" unless status.exitstatus.zero?
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
  #   This method when called will retrieve the tempalate-url of the current module,
  # @param metadata_file [String]
  #   An optional input that can be used to set the location of the metadata file.
  # @param url [String] - the url of the pdk-templates repo
  # @return [String]
  #   A string value that represents the current pdk tempalate-url.
  def self.module_templates_url(metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    data_hash = JSON.parse(file)
    data_hash['template-url']
  end

  def self.change_module_template_url(url, ref, metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    uri = PDK::Util::TemplateURI.uri_safe(url.to_s + "##{ref}")
    data_hash = JSON.parse(file)
    data_hash['template-url'] = uri
    File.write(metadata_file, data_hash.to_json)
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
      PdkSync::Logger.info 'All files have been staged.'
      true
    else
      PdkSync::Logger.info 'Nothing to commit.'
      false
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
    git_repo.push(configuration.push_file_destination, current_branch)
  rescue StandardError => error
    PdkSync::Logger.error "Pushing to #{configuration.push_file_destination} for #{repo_name} has failed. #{error}"
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
    client.create_pull_request(repo_name, configuration.create_pr_against,
                               head,
                               title,
                               message)
  rescue StandardError => error
    PdkSync::Logger.fatal "PR creation for #{repo_name} has failed. #{error}"
    nil
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
    PdkSync::Logger.fatal "Retrieving labels for #{repo_name} has failed. #{error}"
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
    PdkSync::Logger.info "Adding label to #{repo_name} issue #{issue_number} has failed. #{error}"
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
    PdkSync::Logger.fatal "Deleting #{branch_name} in #{repo_name} failed. #{error}"
  end
end
