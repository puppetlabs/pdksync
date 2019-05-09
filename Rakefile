require 'pdksync/rake_tasks'
require 'github_changelog_generator/task'
require 'rubocop/rake_task'

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.user = 'puppetlabs'
  config.project = 'pdksync'
  # config.since_tag = '1.1.1'
  config.future_release = '0.4.0'
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
