# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'pdksync/constants'
require 'pdksync/gitplatformclient'
require 'pdksync/jenkinclient'
require 'json'
require 'yaml'
require 'colorize'
require 'bundler'
require 'octokit'
require 'terminal-table'

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
  @jenkins_platform = Constants::JENKINS_PLATFORM
  @git_platform_access_settings = {
    access_token: Constants::ACCESS_TOKEN,
    gitlab_api_endpoint: Constants::GITLAB_API_ENDPOINT
  }
  @jenkins_platform_access_settings = {
    jenkins_username: Constants::JENKINS_USERNAME,
    jenkins_password: Constants::JENKINS_PASSWORD,
    jenkins_api_endpoint: Constants::JENKINS_API_ENDPOINT,
    jenkins_server_url: Constants::JENKINS_SERVER_URL
  }

  # convert duration from ms to format h m s ms
  def self.get_duration_hrs_and_mins(ms)
    return '' unless ms
    hours, ms   = ms.divmod(1000 * 60 * 60)
    minutes, ms = ms.divmod(1000 * 60)
    seconds, ms = ms.divmod(1000)
    "#{hours}h #{minutes}m #{seconds}s #{ms}ms"
  end

  # jenkins report
  def self.fetch_traditional_test_results(build_id, job_name, module_name)
    puts 'Fetch results from jenkins'
    # def self.jenkins_report_analisation(github_repo, build_id)
    adhoc_urls = []
    # get adhoc jobs
    adhoc_urls.push("#{@jenkins_platform_access_settings[:jenkins_server_url]}/job/#{job_name}")
    # get_adhoc_jobs(adhoc_urls).size
    report_rows = []
    adhoc_urls.each do |url|
      conn = Faraday::Connection.new "#{url}/api/json"
      res = conn.get
      build_job_data = JSON.parse(res.body.to_s)
      downstream_job = build_job_data['downstreamProjects']
      break if downstream_job.empty?
      downstream_job.each do |item|
        next if item.nil?
        adhoc_urls.push(item['url']) unless item['url'].nil? && item['url'].include?('skippable_adhoc')
      end
    end

    @failed = false
    @in_progress = false
    @aborted = false

    File.delete("results_#{module_name}.out") if File.exist?("results_#{module_name}.out")
    # remove duplicates
    adhoc_urls = adhoc_urls.uniq
    # sort the list
    adhoc_urls = adhoc_urls.sort_by { |url| JSON.parse(Faraday.get("#{url}/api/json").body.to_s)['fullDisplayName'].scan(%r{[0-9]{2}\s}).first.to_i }
    # analyse each build result - get status, execution time, logs_link
    @data = "MODULE_NAME=#{module_name}\nBUILD_ID=#{build_id}\nINITIAL_job=#{@jenkins_platform_access_settings[:jenkins_server_url]}/job/#{job_name}/#{build_id}\n\n"
    write_to_file("results_#{module_name}.out", @data)
    puts "Analyse test execution report \n"
    adhoc_urls.each do |url|
      # next if skipped in build name
      current_build_data = JSON.parse(Faraday.get("#{url}/api/json").body.to_s)
      next if url.include?('skippable_adhoc') || current_build_data['color'] == 'notbuilt'
      next if current_build_data['fullDisplayName'].downcase.include?('skipped')
      returned_data = get_data_build(url, build_id, module_name) unless @failed || @in_progress
      if @failed
        report_rows << ['FAILED', url, returned_data[1]] unless returned_data.nil?
      elsif @aborted
        report_rows << ['ABORTED', url, returned_data[1]] unless returned_data.nil?
      else
        report_rows << [returned_data[0], url, returned_data[1]] unless returned_data.nil?
      end
    end

    table = Terminal::Table.new title: "Module Test Results for: #{module_name}\nCheck results in #{Dir.pwd}/results_#{module_name}.out ", headings: %w[Status Result Execution_Time], rows: report_rows
    puts "SUCCESSFUL test results!\n".green unless @failed || @in_progress
    puts table
  end

  # for each build from adhoc jobs, get data
  # if multiple platforms under current url, get data for each platform
  def self.get_data_build(url, build_id, module_name)
    current_build_data = JSON.parse(Faraday.get("#{url}/api/json").body.to_s)
    if current_build_data['activeConfigurations'].nil?
      returned_data = analyse_jenkins_report(url, module_name, build_id)
      if returned_data[0] == 'in progress'
        @in_progress = true
      elsif returned_data[0] == 'FAILURE'
        @failed = true
      elsif returned_data[0] == 'ABORTED'
        @aborted = true
      end
    else
      platforms_list = []
      current_build_data['activeConfigurations'].each do |url_child|
        next if url_child['color'] == 'notbuilt'
        platforms_list.push(url_child['url'])
      end

      platforms_list.each do |platform_build|
        returned_data = analyse_jenkins_report(platform_build, module_name, build_id)
        if returned_data[0] == 'in progress'
          @in_progress = true
        elsif returned_data[0] == 'FAILURE'
          @failed = true
        elsif returned_data[0] == 'ABORTED'
          @aborted = true
        end
      end
    end

    @data = "\nFAILURE. Fix the failures and rerun tests!\n" if @failed
    @data = "\nIN PROGRESS. Please check test report after the execution is done!\n" if @in_progress
    write_to_file("results_#{module_name}.out", @data) if @failed || @in_progress
    puts 'Failed status! Fix errors and rerun.'.red if @failed
    puts 'Aborted status! Fix errors and rerun.'.red if @aborted
    puts 'Tests are still running! You can fetch the results later by using this task: fetch_traditional_test_results'.blue if @in_progress
    returned_data
  end

  # write test report to file
  def self.write_to_file(file, _data)
    File.open(file, 'a') do |f|
      f.write @data
    end
  end

  # remove duplicated
  def self.remove_duplicates(file)
    open = File.open(file, 'r')
    content = open.read
    new_content = content.split("\n").uniq
    write_to_file(file, new_content)
  end

  # analyse jenkins report 
  def self.analyse_jenkins_report(url, module_name, build_id)
    # builds don't have the same build_id. That's why just the init build will be identified by id, rest of them by lastBuild
    last_build_job_data = JSON.parse(Faraday.get("#{url}/#{build_id}/api/json").body.to_s) if url.include?('init-manual-parameters_adhoc')
    last_build_job_data = JSON.parse(Faraday.get("#{url}/lastBuild/api/json").body.to_s) unless url.include?('init-manual-parameters_adhoc')

    # status = 'not_built' unless last_build_job_data
    if last_build_job_data['result'].nil?
      status = 'in progress'
      execution_time = 'running'
    else
      status = last_build_job_data['result']
      execution_time = get_duration_hrs_and_mins(last_build_job_data['duration'].to_i)
    end

    # execution_time = 0 unless last_build_job_data
    logs_link = "#{url}/#{build_id}/" if url.include?('init-manual-parameters_adhoc')
    logs_link = "#{url}lastBuild/" unless url.include?('init-manual-parameters_adhoc')
    @data = "Job title =#{last_build_job_data['fullDisplayName']}\n logs_link = #{logs_link}\n status = #{status}\n"
    # @data[logs_link] = {:status => status, :execution_time => execution_time}
    return_data = [status, execution_time]
    write_to_file("results_#{module_name}.out", @data)
    return_data
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
    module_type
  end

  def self.main(steps: [:clone], args: nil)
    check_pdk_version
    create_filespace
    client = setup_client
    module_names = return_modules
    raise "No modules found in '#{@managed_modules}'" if module_names.nil?
    validate_modules_exist(client, module_names)
    pr_list = []
    if steps.include?(:run_tests_jenkins)
      jenkins_client = setup_jenkins_client
    end

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
    # validation create_pr
    if steps.include?(:create_pr)
      raise 'Needs a pr_title' if args.nil? || args[:pr_title].nil?
      puts "PR title =#{args[:additional_title]} #{args[:pr_title]}"
    end
    # validation clean_branches
    if steps.include?(:clean_branches)
      raise 'Needs a branch_name, and the branch name contains the string pdksync' if args.nil? || args[:branch_name].nil? || !args[:branch_name].include?('pdksync')
      puts "Removing branch_name =#{args[:branch_name]}"
    end
    # validation run_tests_jenkins
    if steps.include?(:run_tests_jenkins)
      # jenkins_client = setup_jenkins_client
      raise 'run_tests_jenkins requires arguments (github_branch) to run.' if args[:github_branch].nil?
      puts "Command '#{args}'"
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
      if steps.include?(:run_tests_jenkins)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'run tests in jenkins, '
        module_type = module_type(output_path, module_name)
        if module_type == 'traditional'
          github_user = 'puppetlabs' if module_args[:test_framework].nil?
          github_user = module_args[:github_user] unless module_args[:github_user].nil?
          if module_args[:test_framework] == 'jenkins' || module_args[:test_framework].nil?
            module_name = "puppetlabs-#{module_name}" if %w[cisco_ios device_manager].include?(module_name) # rubocop:disable Metrics/BlockNesting
            job_name = "forge-module_#{module_name}_init-manual-parameters_adhoc"
            job_name = "forge-windows_#{module_name}_init-manual-parameters_adhoc" if ['puppetlabs-reboot', 'puppetlabs-iis', 'puppetlabs-powershell', 'sqlserver'].include?(module_name) # rubocop:disable Metrics/BlockNesting, Metrics/LineLength
            build_id = run_tests_jenkins(jenkins_client, module_name, module_args[:github_branch], github_user)
            next if build_id.nil? # rubocop:disable Metrics/BlockNesting
            puts "New adhoc TEST EXECUTION has started. \nYou can check progress here: #{@jenkins_platform_access_settings[:jenkins_server_url]}/job/#{job_name}/#{build_id}"
            fetch_traditional_test_results(build_id, job_name, module_name)
          end
        end
        if module_type == 'litmus'
          puts '(Error) Module Type is Litmus please use the rake task run_tests to run'.red
        end
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
      if steps.include?(:push)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        if git_instance.diff(git_instance.current_branch, "#{@push_file_destination}/#{@create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
          push_staged_files(git_instance, git_instance.current_branch, repo_name)
          print 'push, '
        else
          print 'skipped push, '
        end
      end
      if steps.include?(:create_pr)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        git_instance = Git.open(output_path)
        if git_instance.diff(git_instance.current_branch, "#{@push_file_destination}/#{@create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
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
        else
          print 'skipped pr, '
        end
        pr_list
      end
      if steps.include?(:clean_branches)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        delete_branch(client, repo_name, module_args[:branch_name])
        print 'branch deleted, '
      end
      if steps.include?(:fetch_traditional_test_results)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        print 'Fetch test results from jenkins, '
        module_type = module_type(output_path, module_name)
        if module_type == 'litmus'
          puts '(Error) Module Type is Litmus please use the rake task run_tests to run'.red
          next
        end

        module_name = "puppetlabs-#{module_name}" if %w[cisco_ios device_manager].include?(module_name)
        File.open("results_#{module_name}.out", 'r') do |f|
          f.each_line do |line|
            if line.include?('BUILD_ID')
              build_id = line.split('=')[1].strip
            elsif line.include?('MODULE_NAME')
              module_name = line.split('=')[1].strip
              # elsif line.include?("INITIAL_job")
              #   initial_job = line.split("=")[1]
            end
          end

          job_name = "forge-module_#{module_name}_init-manual-parameters_adhoc" if module_args[:job_name].nil?
          job_name = "forge-windows_#{module_name}_init-manual-parameters_adhoc" if ['puppetlabs-reboot', 'puppetlabs-iis', 'puppetlabs-powershell', 'sqlserver'].include?(module_name)

          fetch_traditional_test_results(build_id, job_name, module_name)
        end
      end
      puts "done.\n".green
    end

    return if pr_list.size.zero?
    puts "\nPRs created:\n".blue
    pr_list.each do |pr|
      puts pr
    end
  end

  # @summary
  #   Check the local pdk version against the most recent tagged release on GitHub
  def self.check_pdk_version
    stdout, _stderr, status = Open3.capture3("#{return_pdk_path} --version")
    raise "(FAILURE) Unable to find pdk at '#{return_pdk_path}'.".red unless status.exitstatus

    local_version = stdout.strip
    remote_version = Octokit.tags('puppetlabs/pdk').first[:name][1..-1]

    unless Gem::Version.new(remote_version) <= Gem::Version.new(local_version)
      puts "(WARNING) The current version of pdk is #{remote_version} however you are using #{local_version}".red
    end
  rescue StandardError => error
    puts "(WARNING) Unable to check latest pdk version. #{error}".red
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
  #   This method when called will create and return an octokit client with access to the upstream jenkin repositories.
  # @return [PdkSync::JenkinsPlatformClient] client
  #   The Jenkins platform client that has been created.
  def self.setup_jenkins_client
    PdkSync::JenkinsClient.new(@jenkins_platform_access_settings)
  rescue StandardError => error
    raise "Jenkins platform access not set up correctly: #{error}"
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
  #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the master with the pdk version as an identifier.
  # @param [PdkSync::GitPlatformClient] client
  #   The Git platform client used to gain access to and manipulate the repository.
  # @param [String] ouput_path
  #   The location that the command is to be run from.
  # @param [String] jenkins_client
  #   Jenkins authentication.
  # @param [String] repo_name
  #   Module to run on Jenkins
  # @param [String] current_branch
  #   The branch against which the user needs to run the jenkin jobs
  def self.run_tests_jenkins(jenkins_client, repo_name, current_branch, github_user, job_name)
    if jenkins_client || repo_name || current_branch
      pr = jenkins_client.create_adhoc_job(repo_name,
                                           current_branch,
                                           github_user,
                                           job_name)
      pr
    end
  rescue StandardError => error
    puts "(FAILURE) Jenkins Job creation for #{repo_name} has failed. #{error}".red
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
      true
    else
      puts 'Nothing to commit.'
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
