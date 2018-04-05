# !/usr/bin/env ruby
require 'git'
require 'open3'
require 'fileutils'
require 'rake'
require 'pdk'

# Initialization of running pdksync
module PdkSync
  def self.run_pdksync
    puts 'Running pdksync'
    @timestamp = Time.now.to_i
    @namespace = 'HelenCampbell'
    @pdksync_dir = './modules_pdksync'
    @module_name = 'puppetlabs-motd'
    @output_path = "#{@pdksync_dir}/#{@module_name}"

    create_filespace(@pdksync_dir)
    @git_repo = clone_directory(@namespace, @module_name, @output_path)
    checkout_branch(@timestamp, @git_repo)
    pdk_update(@output_path)
    add_staged_files(@git_repo)
    commit_staged_files(@git_repo, @timestamp)
  end

  def self.create_filespace(pdksync_dir)
    FileUtils.mkdir pdksync_dir unless Dir.exist?(pdksync_dir)
  end

  def self.clone_directory(namespace, module_name, output_path)
    puts 'Cleaning up'
    # If a local copy already exists it is removed
    FileUtils.rm_rf(output_path)

    puts "Currently Cloning: #{module_name} to #{output_path}"
    git_repo = Git.clone("https://github.com/#{namespace}/#{module_name}.git", output_path.to_s)
    puts 'Clone complete.'
    git_repo
  end

  def self.checkout_branch(timestamp, git_repo)
    puts "Creating a branch called: pdksync_#{timestamp}"
    # TODO: This is awesome, placeholder for SHA of template.
    git_repo.branch("pdksync_#{timestamp}").checkout
  end

  def self.pdk_update(output_path)
    # Navigate into the correct directory
    Dir.chdir(output_path)
    puts Dir.pwd
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
      puts 'Echoed text into file.txt, REVISIT FOR PDK UPDATE'
    end
  end

  def self.add_staged_files(git_repo)
    git_repo.add(all: true)
    puts 'All files have been staged'
  end

  def self.commit_staged_files(git_repo, timestamp)
    git_repo.commit("(maint) - pdksync[#{timestamp}]")
    puts "The following commit has been created: pdksync[#{timestamp}]"
  end
end
