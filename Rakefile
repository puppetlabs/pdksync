require_relative 'lib/pdksync'
require 'colorize'
require 'github_changelog_generator/task'

desc 'Display the current configuration of pdksync'
task :show_config do
  include PdkSync::Constants
  puts 'PDKSync Configuration'.bold.yellow
  puts '- Namespace: '.bold + "#{PdkSync::Constants::NAMESPACE}".cyan
  puts '- PDKSync Dir: '.bold + "#{PdkSync::Constants::PDKSYNC_DIR}".cyan
  puts '- Push File Destination: '.bold + "#{PdkSync::Constants::PUSH_FILE_DESTINATION}".cyan
  puts '- Create PR Against: '.bold + "#{PdkSync::Constants::CREATE_PR_AGAINST}".cyan
  puts '- Managed Modules: '.bold + "#{PdkSync::Constants::MANAGED_MODULES}".cyan
  puts '- Default PDKSync Label: '.bold + "#{PdkSync::Constants::PDKSYNC_LABEL}".cyan
end

desc 'Run full pdksync process, clone repository, pdk update, create pr. Additional title information can be added to the title, which will be appended before the reference section.'
task :pdksync, [:additional_title] do |task, args|
  args = {:branch_name    => "pdksync_{ref}",
          :commit_message => "pdksync_{ref}",
          :pr_title       => "pdksync_{ref}",
          :additional_title => args[:additional_title]}
  PdkSync::main(steps: [:use_pdk_ref, :clone, :pdk_update, :create_commit, :push_and_create_pr], args: args)
end

namespace :pdk do 
  desc 'Runs PDK convert against modules'
  task :pdk_convert do
    PdkSync::main(steps: [:pdk_convert])
  end

  desc 'Runs PDK validate against modules'
  task :pdk_validate do
    PdkSync::main(steps: [:pdk_validate])
  end
end

namespace :git do
  desc 'Clone managed modules'
  task :clone_managed_modules do
    PdkSync::main(steps: [:clone])
  end

  desc "Stage commits for modules, branchname and commit message eg rake 'git:create_commit[flippity, commit messagez]'"
  task :create_commit, [:branch_name, :commit_message] do |task, args|
    PdkSync::main(steps: [:create_commit], args: args)
  end

  desc "Push commit, and create PR for modules eg rake 'git:push_and_create_pr[pr title goes here, optional label right here]'"
  task :push_and_create_pr, [:pr_title, :label]  do |task, args|
    PdkSync::main(steps: [:push_and_create_pr], args: args)
  end

  desc "Clean up origin branches, (branches must include pdksync in their name) eg rake 'git:clean[pdksync_origin_branch]'"
  task :clean_branches, [:branch_name]  do |task, args|
    PdkSync::main(steps: [:clean_branches], args: args)
  end
end

desc "Run a command against modules eg rake 'run_a_command[complex command here -f -gx]'"
task :run_a_command, [:command] do |task, args|
  PdkSync::main(steps: [:run_a_command], args: args[:command])
end

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'puppetlabs'
  config.project = 'pdksync'
  # config.since_tag = '1.1.1'
  config.future_release = '0.3.0'
  config.exclude_labels = ['maintenance']
  config.header = "# Change log\n\nAll notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org)."
  config.add_pr_wo_labels = true
  config.issues = false
  config.merge_prefix = "### UNCATEGORIZED PRS; GO LABEL THEM"
  config.configure_sections = {
    "Changed" => {
      "prefix" => "### Changed",
      "labels" => ["backwards-incompatible"],
    },
    "Added" => {
      "prefix" => "### Added",
      "labels" => ["feature", "enhancement"],
    },
    "Fixed" => {
      "prefix" => "### Fixed",
      "labels" => ["bugfix"],
    },
  }
end
