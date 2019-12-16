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
        gem_file_update(output_path, module_args[:gem_to_test], module_args[:gem_line], module_args[:gem_sha_finder], module_args[:gem_sha_replacer], module_args[:gem_version_finder], module_args[:gem_version_replacer], module_args[:gem_branch_finder], module_args[:gem_branch_replacer], @main_path) # rubocop:disable Metrics/LineLength
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
end
