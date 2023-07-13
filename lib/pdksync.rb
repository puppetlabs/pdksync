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
require 'bundler'
require 'octokit'
require 'pdk/util/template_uri'
require 'pdksync/logger'
require 'pdksync/utils'
require 'terminal-table'

# @summary
#   This module set's out and controls the pdksync process
module PdkSync
  def self.configuration
    @configuration ||= PdkSync::Configuration.new
  end

  @main_path = Dir.pwd

  def self.client
    @client ||= Utils.setup_client
  end

  def self.main(steps: [:clone], args: nil)
    Utils.check_pdk_version if ENV['PDKSYNC_VERSION_CHECK'].eql?('true')
    Utils.create_filespace
    Utils.create_filespace_gem
    module_names = Utils.return_modules

    unless steps.include?(:clone_gem) || steps.include?(:multi_gem_testing)
      raise "No modules found in '#{Utils.configuration.managed_modules}'" if module_names.nil?
    end

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
    # validation clone_gem
    if steps.include?(:clone_gem)
      raise 'Needs a gem_name' if args.nil? || args[:gem_name].nil?
      PdkSync::Logger.info "Command '#{args}'"
    end
    # validation multi_gem_testing
    if steps.include?(:multi_gem_testing)
      raise '"multi_gem_testing" requires arguments to run version_file and build_gem.' if args.nil? || args[:version_file].nil? || args[:build_gem].nil?
      puts "Command '#{args}'"
    end
    # validation multi_gem_file_update
    if steps.include?(:multigem_file_update)
      raise 'multigem_file_update requires arguments gem_to_test, gemfury_username to run.' if args[:gem_name].nil? || args[:gemfury_username].nil?
      puts "Command '#{args}'"
    end
    # validation gem_file_update
    if steps.include?(:gem_file_update)
      raise '"gem_file_update" requires arguments (gem_to_test) to run.' if args[:gem_to_test].nil?
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
    # validation run_tests_jenkins
    if steps.include?(:run_tests_jenkins)
      raise 'run_tests_jenkins requires arguments (jenkins_server_url, github_branch) to run.' if args[:github_branch].nil? || args[:jenkins_server_url].nil?
      puts "Command '#{args}'"
    end
    # validation test_results_jenkins
    if steps.include?(:test_results_jenkins)
      raise 'test_results_jenkins requires argument jenkins_server_url to run.' if args[:jenkins_server_url].nil?
      puts "Command '#{args}'"
    end

    unless steps.include?(:clone_gem) || steps.include?(:multi_gem_testing)
      abort "No modules listed in #{Utils.configuration.managed_modules}" if module_names.nil?
    end

    if steps.include?(:clone_gem) || steps.include?(:multi_gem_testing)
      gem_args = args.clone
      Dir.chdir(main_path) unless Dir.pwd == main_path
      PdkSync::Logger.info "#{gem_args[:gem_name]}, "
      output_path = File.join(Utils.configuration.pdksync_gem_dir, gem_args[:gem_name])
      if steps.include?(:clone_gem)
        Utils.clean_env(output_path) if Dir.exist?(output_path)
        PdkSync::Logger.info 'delete gem directory, '
        @git_repo = Utils.clone_directory(Utils.configuration.namespace, gem_args[:gem_name], output_path)
        PdkSync::Logger.info 'cloned'
        PdkSync::Logger.error "Unable to clone repo for #{gem_args[:gem_name]}".red if @git_repo.nil?
        Dir.chdir(main_path) unless Dir.pwd == main_path
      end
      puts '(WARNING) @output_path does not exist, gem'.red unless File.directory?(output_path)
      if steps.include?(:multi_gem_testing)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        PdkSync::Logger.info 'Multi Gem Testing, '
        current_gem_version = Utils.check_gem_latest_version(gem_args[:gem_name])
        PdkSync::Logger.info current_gem_version
        new_gem_version = Utils.update_gem_latest_version_by_one(current_gem_version)
        PdkSync::Logger.info new_gem_version
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = Utils.run_command(output_path, "sed s/#{current_gem_version}/#{new_gem_version}/g #{gem_args[:version_file]} >> test.yml", nil)
        PdkSync::Logger.info 'Updated the version'
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = Utils.run_command(output_path, "cp test.yml #{gem_args[:version_file]}", nil)
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = Utils.run_command(output_path, 'rm -rf test.yml', nil)
        PdkSync::Logger.info 'bundle install'
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = Utils.run_command(output_path, 'bundle install', nil)
        PdkSync::Logger.info 'building gem'
        Dir.chdir(main_path) unless Dir.pwd == main_path
        exit_status = Utils.run_command(output_path, "bundle exec #{gem_args[:build_gem]}", nil)
        PdkSync::Logger.info 'uploading packages'
        Dir.chdir(main_path) unless Dir.pwd == main_path
        Dir.chdir("#{output_path}/#{gem_args[:gem_path]}") unless Dir.pwd == output_path
        gemfury_token = Utils.configuration.gemfury_access_settings
        Dir.glob('*.gem') do |filename|
          PdkSync::Logger.info filename
          Dir.chdir(main_path) unless Dir.pwd == main_path
          exit_status = Utils.run_command("#{output_path}/#{gem_args[:gem_path]}", "curl -F package=@#{filename} https://" + gemfury_token + "@push.fury.io/#{gem_args[:gemfury_username]}/", nil)
        end
      end
    else
      module_names.each do |module_name|
        module_args = args.clone
        Dir.chdir(main_path) unless Dir.pwd == main_path
        PdkSync::Logger.info "#{module_name}, "
        repo_name = File.join(Utils.configuration.namespace, module_name)
        output_path = File.join(Utils.configuration.pdksync_dir, module_name)
        if steps.include?(:clone)
          Utils.validate_modules_exist(client, module_names)
          Utils.clean_env(output_path) if Dir.exist?(output_path)
          PdkSync::Logger.info 'delete module directory'
          @git_repo = Utils.clone_directory(Utils.configuration.namespace, module_name, output_path)
          PdkSync::Logger.info 'cloned'
          PdkSync::Logger.error "Unable to clone repo for #{module_name}" if @git_repo.nil?
          Dir.chdir(main_path) unless Dir.pwd == main_path
          next if @git_repo.nil?
        end
        PdkSync::Logger.warn "#{output_path} does not exist, skipping module" unless File.directory?(output_path)
        next unless File.directory?(output_path)
        if steps.include?(:pdk_convert)
          exit_status = Utils.run_command(output_path, "#{Utils.return_pdk_path} convert --force #{configuration.templates}", nil)
          break unless exit_status.zero?
          PdkSync::Logger.info 'converted'
        end
        if steps.include?(:pdk_validate)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          exit_status = Utils.run_command(output_path, "#{Utils.return_pdk_path} validate -a", nil)
          PdkSync::Logger.info 'validated' if exit_status.zero?
          break unless exit_status.zero?
        end
        if steps.include?(:run_a_command)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          PdkSync::Logger.info 'run command'
          if module_args[:option].nil?
            pid = Utils.run_command(output_path, module_args[:command], module_args[:option])
            next unless pid != 0 # rubocop:disable Metrics/BlockNesting
          else
            exit_status = Utils.run_command(output_path, module_args[:command], nil)
            break unless exit_status.zero? # rubocop:disable Metrics/BlockNesting
          end
        end
        if steps.include?(:gem_file_update)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          print 'gem file update, '
          Utils.gem_file_update(output_path, module_args[:gem_to_test], module_args[:gem_line], module_args[:gem_sha_finder], module_args[:gem_sha_replacer], module_args[:gem_version_finder], module_args[:gem_version_replacer], module_args[:gem_branch_finder], module_args[:gem_branch_replacer], main_path) # rubocop:disable Metrics/LineLength
          print 'gem file updated, '
        end
        if steps.include?(:run_tests_locally)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          PdkSync::Logger.info 'Run tests '
          module_type = Utils.module_type(output_path, module_name)
          Utils.run_tests_locally(output_path, module_type, module_args[:provision_type], module_name, module_args[:puppet_collection])
        end
        if steps.include?(:fetch_test_results_locally)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          PdkSync::Logger.info 'Fetch test results for local run '
          module_type = Utils.module_type(output_path, module_name)
          table = Utils.fetch_test_results_locally(output_path, module_type, module_name, report_rows)
        end
        if steps.include?(:pdk_update)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          break unless Utils.pdk_update(output_path).zero?
          if steps.include?(:use_pdk_ref)
            ref = Utils.return_template_ref(File.join(output_path, 'metadata.json'))
            pr_title = module_args[:additional_title] ? "#{module_args[:additional_title]} - pdksync_#{ref}" : "pdksync_#{ref}" # rubocop:disable Metrics/BlockNesting
            module_args = module_args.merge(branch_name: "pdksync_#{ref}",
                                            commit_message: pr_title,
                                            pr_title: pr_title,
                                            pdksync_label: Utils.configuration.default_pdksync_label)
          end
          PdkSync::Logger.info 'pdk update'
        end
        if steps.include?(:use_gem_ref)
          pr_title = module_args[:additional_title] ? "#{module_args[:additional_title]} - pdksync_gem_testing" : 'pdksync_gem_testing'
          module_args = module_args.merge(branch_name: "gem_testing_#{module_args[:gem_to_test]}",
                                          commit_message: pr_title,
                                          pr_title: pr_title,
                                          pdksync_label: Utils.configuration.default_pdksync_label)
        end
        if steps.include?(:create_commit)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          git_instance = Git.open(output_path)
          Utils.create_commit(git_instance, module_args[:branch_name], module_args[:commit_message])
          PdkSync::Logger.info 'commit created'
        end
        if steps.include?(:push)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          git_instance = Git.open(output_path)
          if git_instance.diff(git_instance.current_branch, "#{Utils.configuration.push_file_destination}/#{Utils.configuration.create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
            PdkSync::Logger.info 'push'
            Utils.push_staged_files(git_instance, git_instance.current_branch, repo_name)
          else
            PdkSync::Logger.info 'skipped push'
          end
        end
        if steps.include?(:create_pr)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          git_instance = Git.open(output_path)
          if git_instance.diff(git_instance.current_branch, "#{Utils.configuration.push_file_destination}/#{Utils.configuration.create_pr_against}").size != 0 # Git::Diff doesn't have empty? # rubocop:disable Style/ZeroLengthPredicate
            pdk_version = Utils.return_pdk_version("#{output_path}/metadata.json")

            # If a label is supplied, verify that it is available in the repo
            label = module_args[:pdksync_label] ? module_args[:pdksync_label] : module_args[:label] # rubocop:disable Metrics/BlockNesting
            label_valid = (label.is_a?(String) && !label.to_str.empty?) ? Utils.check_for_label(client, repo_name, label) : nil # rubocop:disable Metrics/BlockNesting

            # Exit current iteration if an error occured retrieving a label
            if label_valid == false # rubocop:disable Metrics/BlockNesting
              raise 'Ensure label is valid'
            end

            # Create the PR and add link to pr list
            pr = Utils.create_pr(client, repo_name, git_instance.current_branch, pdk_version, module_args[:pr_title])
            break if pr.nil? # rubocop:disable Metrics/BlockNesting

            pr_list.push(pr.html_url)
            PdkSync::Logger.info 'created pr'

            # If a valid label is supplied, add this to the PR
            if label_valid == true # rubocop:disable Metrics/BlockNesting
              Utils.add_label(client, repo_name, pr.number, label)
              PdkSync::Logger.info "added label '#{label}' "
            end
          else
            PdkSync::Logger.info 'skipped pr'
          end
        end
        if steps.include?(:clean_branches)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          Utils.delete_branch(client, repo_name, module_args[:branch_name])
          PdkSync::Logger.info 'branch deleted'
        end
        if steps.include?(:run_tests_jenkins)
          jenkins_client = Utils.setup_jenkins_client(module_args[:jenkins_server_url])
          Dir.chdir(main_path) unless Dir.pwd == main_path
          PdkSync::Logger.info 'Run tests in jenkins '
          module_type = Utils.module_type(output_path, module_name)
          if module_type == 'traditional'
            github_user = 'puppetlabs' if module_args[:test_framework].nil? # rubocop:disable Metrics/BlockNesting
            github_user = module_args[:github_user] unless module_args[:github_user].nil? # rubocop:disable Metrics/BlockNesting
            if module_args[:test_framework] == 'jenkins' || module_args[:test_framework].nil? # rubocop:disable Metrics/BlockNesting
              module_name = "puppetlabs-#{module_name}" if %w[cisco_ios device_manager].include?(module_name) # rubocop:disable Metrics/BlockNesting
              job_name = "forge-module_#{module_name}_init-manual-parameters_adhoc"
              job_name = "forge-windows_#{module_name}_init-manual-parameters_adhoc" if ['puppetlabs-reboot', 'puppetlabs-iis', 'puppetlabs-powershell', 'sqlserver'].include?(module_name) # rubocop:disable Metrics/BlockNesting, Metrics/LineLength
              build_id = Utils.run_tests_jenkins(jenkins_client, module_name, module_args[:github_branch], github_user, job_name)
              next if build_id.nil? # rubocop:disable Metrics/BlockNesting
              PdkSync::Logger.info "New adhoc TEST EXECUTION has started. \nYou can check progress here: #{configuration['jenkins_server_url']}/job/#{job_name}/#{build_id}"
              Utils.test_results_jenkins(module_args[:jenkins_server_url], build_id, job_name, module_name)
            end
          end
          if module_type == 'litmus'
            PdkSync::Logger.info '(Error) Module Type is Litmus please use the rake task run_tests_locally to run'.red
          end
        end
        if steps.include?(:test_results_jenkins)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          PdkSync::Logger.info 'Fetch test results from jenkins, '
          module_type = Utils.module_type(output_path, module_name)
          if module_type == 'litmus'
            PdkSync::Logger.info '(Error) Module Type is Litmus please use the rake task run_tests_locally to run'.red
            next
          end

          module_name = "puppetlabs-#{module_name}" if %w[cisco_ios device_manager].include?(module_name)
          File.open("results_#{module_name}.out", 'r') do |f|
            f.each_line do |line|
              if line.include?('BUILD_ID')
                build_id = line.split('=')[1].strip
              elsif line.include?('MODULE_NAME')
                module_name = line.split('=')[1].strip
              end
            end

            job_name = "forge-module_#{module_name}_init-manual-parameters_adhoc" if module_args[:job_name].nil?
            job_name = "forge-windows_#{module_name}_init-manual-parameters_adhoc" if ['puppetlabs-reboot', 'puppetlabs-iis', 'puppetlabs-powershell', 'sqlserver'].include?(module_name)
            Utils.test_results_jenkins(module_args[:jenkins_server_url], build_id, job_name, module_name)
          end
        end
        if steps.include?(:multigem_file_update)
          Dir.chdir(main_path) unless Dir.pwd == main_path
          gemfury_readonly_token = Utils.configuration.gemfury_access_settings
          Utils.update_gemfile_multigem(output_path, module_args[:gem_name], gemfury_readonly_token, module_args[:gemfury_username])
          PdkSync::Logger.info 'Updated with multigem, '
        end

        if steps.include?(:add_provision_list)
          result = Utils.add_provision_list(output_path, module_args[:key], module_args[:provisioner], [module_args[:images], module_args.extras].flatten)
          raise "#{output_path}/provision.yaml does not exist" unless result
        end

        if steps.include?(:generate_vmpooler_release_checks)
          Utils.generate_vmpooler_release_checks(output_path, module_args[:puppet_version].to_i)
        end

        if steps.include?(:update_os_support)
          Utils.update_os_support(output_path)
        end

        if steps.include?(:remove_platform_from_metadata)
          Utils.remove_platform_from_metadata(output_path, module_args[:os], module_args[:version])
        end

        if steps.include?(:add_platform_to_metadata)
          Utils.add_platform_to_metadata(output_path, module_args[:os], module_args[:version])
        end

        if steps.include?(:update_requirements)
          Utils.update_requirements(output_path, module_args[:name], module_args[:key], module_args[:value])
        end

        if steps.include?(:normalize_metadata_supported_platforms)
          Utils.normalize_metadata_supported_platforms(output_path)
        end

        PdkSync::Logger.info 'done'
      end
      table = Terminal::Table.new title: 'Module Test Results', headings: %w[Module Status Result From], rows: report_rows
      puts table if steps.include?(:fetch_test_results_locally)
      return if pr_list.size.zero?
      PdkSync::Logger.info "\nPRs created:\n"
      puts pr_list.join("\n")
    end
  end
end
