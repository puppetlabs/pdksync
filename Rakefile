require_relative 'lib/pdksync'
require 'github_changelog_generator/task'

desc 'Run full pdksync process, clone repository, pdk update, create pr.'
task :pdksync do
  PdkSync::run_pdksync
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

  desc "Push commit, and create PR for modules eg rake 'git:push_and_create_pr[pr title goes here]'"
  task :push_and_create_pr, [:pr_title]  do |task, args|
    PdkSync::main(steps: [:push_and_create_pr], args: args)
  end

  desc 'Run pdksync cleanup origin branches'
  task :pdksync_cleanup do
    PdkSync::clean_branches
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
  config.future_release = '0.1.0'
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
