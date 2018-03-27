#!/usr/bin/env ruby
require 'git'
require 'fileutils'
require 'open3'

timestamp = Time.now.to_i
namespace = 'HelenCampbell'
module_name = 'puppetlabs-motd'
output_path = "./modules_pdksync/#{module_name}"
git_repo = Git.open('./modules_pdksync/puppetlabs-motd')

def clone_directories(output_path, module_name, namespace)
  if File.directory?(output_path)
    puts 'Cleaning up'
    FileUtils.rm_rf(output_path)
  end
  puts "Currently Cloning: #{module_name} to #{output_path}"
  Git.clone "git://github.com/#{namespace}/#{module_name}.git", output_path.to_s
  puts 'Clone complete.'
end

def checkout_branch(timestamp, git_repo)
  puts "Creating a branch called: pdksync_#{timestamp}"
  git_repo.branch("pdksync_#{timestamp}").checkout
end

def run_pdk_update(output_path)
  Dir.chdir(output_path)
  stdout, stderr, status = Open3.capture3('pdk update --force')
  if status != 0
    puts 'Something bad happened'
    puts '==============='
    puts stderr
    puts stdout
    puts '================='
  else
    puts 'Your module has been updated via the pdk'
  end
end

def add_staged_files(git_repo)
  git_repo.add(all: true)
  puts 'All files have been added'
end

def commit_changed_files(git_repo, timestamp)
  git_repo.commit("(maint) - pdksync[#{timestamp}]")
  puts "The following commit has been created: pdksync[#{timestamp}]"
end

clone_directories(output_path, module_name, namespace)
checkout_branch(timestamp, git_repo)
run_pdk_update(output_path)
add_staged_files(git_repo)
commit_changed_files(git_repo, timestamp)

puts 'Script finished.'
