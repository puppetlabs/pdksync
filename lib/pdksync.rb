# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'
require 'octokit'
require 'pdksync/constants'
require 'json'

# Initialization of running pdksync
module PdkSync
  include Constants

  @access_token = Constants::ACCESS_TOKEN
  @namespace = Constants::NAMESPACE
  @pdksync_dir = Constants::PDKSYNC_DIR
  @push_file_destination = Constants::PUSH_FILE_DESTINATION
  @create_pr_against = Constants::CREATE_PR_AGAINST

  # Dynamic variables that will change (when iterating through module)
  @module_name = 'puppetlabs-testing'

  def self.run_pdksync
    puts '*************************************'
    puts 'Running pdksync'
    create_filespace
    @client = setup_client

    # Run an iterative loop for each @module_name
    sync(@module_name, @client)
  end

  def self.sync(module_name, client)
    @repo_name = "#{@namespace}/#{module_name}"
    @output_path = "#{@pdksync_dir}/#{module_name}"
    clean_env(@output_path) if Dir.exist?(@output_path)
    @git_repo = clone_directory(@namespace, module_name, @output_path)
    move_to_output_path
    @template_ref = return_template_ref
    @pdk_version = return_pdk_version
    checkout_branch(@git_repo)
    pdk_update
    add_staged_files(@git_repo)
    commit_staged_files(@git_repo)
    push_staged_files(@git_repo)
    create_pr(client, @repo_name)
  end

  def self.create_filespace
    FileUtils.mkdir @pdksync_dir unless Dir.exist?(@pdksync_dir)
  end

  def self.clean_env(output_path)
    puts '*************************************'
    puts 'Cleaning your environment.'
    # If a local copy already exists it is removed
    FileUtils.rm_rf(output_path)
  end

  def self.clone_directory(namespace, module_name, output_path)
    puts '*************************************'
    puts "Cloning to: #{module_name} to #{output_path}."
    Git.clone("git@github.com:#{namespace}/#{module_name}.git", output_path.to_s) # is returned
  end

  def self.checkout_branch(git_repo)
    puts '*************************************'
    puts "Creating a branch called: pdksync_#{@template_ref}."
    git_repo.branch("pdksync_#{@template_ref}".to_s).checkout
  end

  def self.pdk_update
    # Runs the pdk update command
    stdout, stderr, status = Open3.capture3('pdk update --force')
    if status != 0 # rubocop:disable Style/GuardClause
      raise "Unable to run `pdk update`: #{stderr}: #{stdout}"
    else
      puts '*************************************'
      puts 'PDK Update has ran.'
    end
  end

  def self.move_to_output_path
    Dir.chdir(@output_path) unless Dir.pwd == @output_path
  end

  def self.return_template_ref
    file = File.read('metadata.json')
    data_hash = JSON.parse(file)
    data_hash['template-ref']
  end

  def self.return_pdk_version
    # Dir.chdir(@output_path) unless Dir.pwd == @output_path
    file = File.read('metadata.json')
    data_hash = JSON.parse(file)
    data_hash['pdk-version']
  end

  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts '*************************************'
    puts 'All files have been staged.'
  end

  def self.commit_staged_files(git_repo)
    git_repo.commit("pdksync_#{@template_ref}")
    puts '*************************************'
    puts "The following commit has been created: pdksync_#{@template_ref}."
  end

  def self.push_staged_files(git_repo)
    git_repo.push(@push_file_destination, "pdksync_#{@template_ref}")
    puts '*************************************'
    puts 'All staged files have been pushed to the repo, bon voyage!'
  end

  def self.setup_client
    client = Octokit::Client.new(access_token: @access_token.to_s)
    client.user.login
    puts '*************************************'
    puts 'Client login has been successful.'
    client
  end

  def self.create_pr(client, repo_name)
    pr = client.create_pull_request(repo_name, @create_pr_against, "pdksync_#{@template_ref}".to_s, "pdksync - Update using #{@pdk_version}",
      "pdk version: `#{@pdk_version}` \n pdk template ref: `#{@template_ref}`") # rubocop:disable Layout/AlignParameters
    puts '*************************************'
    puts 'The PR has been created.'
    pr
  end
end
