# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'octokit'
require 'pdksync/constants'

# Initialization of running pdksync
module PdkSync
  include Constants

  @access_token = Constants::ACCESS_TOKEN
  @timestamp = Constants::TIMESTAMP
  @namespace = Constants::NAMESPACE
  @pdksync_dir = Constants::PDKSYNC_DIR
  @push_file_destination = Constants::PUSH_FILE_DESTINATION
  @create_pr_against = Constants::CREATE_PR_AGAINST
  @pr_body = Constants::PR_BODY
  @pr_title = Constants::PR_TITLE
  @branch_name = Constants::BRANCH_NAME
  @commit_message = Constants::COMMIT_MESSAGE

  # Dynamic variables that will change (when iterating through module)
  @module_name = 'puppetlabs-testing'
  @repo_name = "#{@namespace}/#{@module_name}"
  @output_path = "#{@pdksync_dir}/#{@module_name}"

  def self.run_pdksync
    puts '*************************************'
    puts 'Running pdksync'
    puts '*************************************'
    create_filespace(@pdksync_dir)
    @git_repo = clone_directory(@namespace, @module_name, @output_path)
    checkout_branch(@git_repo, @timestamp)
    pdk_update(@output_path)
    add_staged_files(@git_repo)
    commit_staged_files(@git_repo, @timestamp)
    @client = setup_client(@access_token)
    push_staged_files(@git_repo, @branch_name)
    create_pr(@client, @repo_name, @branch_name, @create_pr_against, @pr_title, @pr_body)
  end

  def self.create_filespace(_pdksync_dir)
    FileUtils.mkdir @pdksync_dir unless Dir.exist?(@pdksync_dir)
  end

  def self.clone_directory(namespace, module_name, output_path)
    puts 'Cleaning your environment.' if Dir.exist?(output_path)
    # If a local copy already exists it is removed
    FileUtils.rm_rf(output_path) if Dir.exist?(output_path)
    puts "Cloning to: #{module_name} to #{output_path}."
    git_repo = Git.clone("git@github.com:#{namespace}/#{module_name}.git", output_path.to_s) # rubocop:disable Lint/UselessAssignment
  end

  def self.checkout_branch(git_repo, _timestamp)
    puts '*************************************'
    puts "Creating a branch called: #{@branch_name}."
    git_repo.branch(@branch_name.to_s).checkout
  end

  def self.pdk_update(output_path)
    # Navigate into the correct directory
    Dir.chdir(output_path)
    # Runs the pdk update command
    stdout, stderr, status = Open3.capture3('pdk update --force')
    if status != 0 # rubocop:disable Style/GuardClause
      raise "Unable to run `pdk update`: #{stderr}: #{stdout}"
    else
      puts '*************************************'
      puts 'PDK Update has ran.'
    end
  end

  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts '*************************************'
    puts 'All files have been staged.'
  end

  def self.commit_staged_files(git_repo, _timestamp)
    git_repo.commit(@commit_message)
    puts '*************************************'
    puts "The following commit has been created: #{@commit_message}."
  end

  def self.push_staged_files(git_repo, _branch_name)
    git_repo.push(@push_file_destination, @branch_name)
    puts '*************************************'
    puts 'All staged files have been pushed to the repo, bon voyage!'
  end

  def self.create_pr(_client, _repo_name, _branch_name, _create_pr_against, _pr_title, _pr_body)
    pr = @client.create_pull_request(@repo_name, @create_pr_against, @branch_name.to_s, @pr_title, @pr_body)
    puts '*************************************'
    puts 'The PR has successfully been created.'
    pr
  end

  def self.setup_client(_access_token)
    @client = Octokit::Client.new(access_token: @access_token.to_s)
    @client.user.login
    puts '*************************************'
    puts 'Client login has been successful.'
    @client
  end
end
