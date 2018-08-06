require_relative 'lib/pdksync'
require 'github_changelog_generator/task'


desc 'Run full pdksync process, clone repo, pdk update, create pr.'
task :pdksync do
  PdkSync::run_pdksync
end

desc 'Clone managed modules'
task :clone_managed_modules do
  PdkSync::main(steps: [:clone])
end

desc 'PDK convert against modules'
task :pdk_convert do
  PdkSync::main(steps: [:pdk_convert])
end

desc 'PDK validate against modules'
task :pdk_validate do
  PdkSync::main(steps: [:pdk_validate])
end

desc "Run a command against modules eg rake 'run_a_command[complex command here -f -gx]'"
task :run_a_command, [:command] do |task, args|
  PdkSync::main(steps: [:run_a_command], args: args[:command])
end

desc 'Run pdksync cleanup branches'
task :pdksync_cleanup do
  PdkSync::clean_branches
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
