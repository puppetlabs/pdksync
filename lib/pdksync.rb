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

# Initialization of running pdksync
module PdkSync
  include Constants
  @access_token = Constants::ACCESS_TOKEN
  @namespace = Constants::NAMESPACE
  @pdksync_dir = Constants::PDKSYNC_DIR
  @push_file_destination = Constants::PUSH_FILE_DESTINATION
  @create_pr_against = Constants::CREATE_PR_AGAINST
  @managed_modules = Constants::MANAGED_MODULES

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

  def self.create_filespace
    FileUtils.mkdir @pdksync_dir unless Dir.exist?(@pdksync_dir)
  end

  def self.setup_client
    client = Octokit::Client.new(access_token: @access_token.to_s)
    client.user.login
    puts '*************************************'
    puts 'Client login has been successful.'
    client
  end

  def self.return_modules
    YAML.safe_load(File.open(@managed_modules))
  end

  def self.sync(module_name, client)
    @repo_name = "#{@namespace}/#{module_name}"
    @output_path = "#{@pdksync_dir}/#{module_name}"
    clean_env(@output_path) if Dir.exist?(@output_path)
    @git_repo = clone_directory(@namespace, module_name, @output_path)
    pdk_update(@output_path)
    @template_ref = return_template_ref
    checkout_branch(@git_repo, @template_ref)
    @pdk_version = return_pdk_version
    add_staged_files(@git_repo)
    commit_staged_files(@git_repo, @template_ref)
    push_staged_files(@git_repo, @template_ref)
    create_pr(client, @repo_name)
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

  def self.pdk_update(output_path)
    # Runs the pdk update command
    Dir.chdir(output_path) unless Dir.pwd == output_path
    stdout, stderr, status = Open3.capture3('pdk update --force')
    if status != 0 # rubocop:disable Style/GuardClause
      raise "Unable to run `pdk update`: #{stderr}: #{stdout}"
    else
      puts '*************************************'
      puts 'PDK Update has ran.'
    end
  end

  def self.return_template_ref(metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    data_hash = JSON.parse(file)
    data_hash['template-ref']
  end

  def self.checkout_branch(git_repo, template_ref)
    puts '*************************************'
    puts "Creating a branch called: pdksync_#{template_ref}."
    git_repo.branch("pdksync_#{template_ref}".to_s).checkout
  end

  def self.return_pdk_version(metadata_file = 'metadata.json')
    file = File.read(metadata_file)
    data_hash = JSON.parse(file)
    data_hash['pdk-version']
  end

  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts '*************************************'
    puts 'All files have been staged.'
  end

  def self.commit_staged_files(git_repo, template_ref)
    git_repo.commit("pdksync_#{template_ref}")
    puts '*************************************'
    puts "The following commit has been created: pdksync_#{template_ref}."
  end

  def self.push_staged_files(git_repo, template_ref)
    git_repo.push(@push_file_destination, "pdksync_#{template_ref}")
    puts '*************************************'
    puts 'All staged files have been pushed to the repo, bon voyage!'
  end

  def self.create_pr(client, repo_name)
    pr = client.create_pull_request(repo_name, @create_pr_against, "pdksync_#{@template_ref}".to_s, "pdksync - Update using #{@pdk_version}",
      "pdk version: `#{@pdk_version}` \n pdk template ref: `#{@template_ref}`") # rubocop:disable Layout/AlignParameters
    puts '*************************************'
    puts 'The PR has been created.'
    pr
  end
end
