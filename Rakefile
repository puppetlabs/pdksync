require "pdksync/rake_tasks"
require "rubocop/rake_task"
require "rspec/core/rake_task"
require "bundler/gem_tasks"

RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ["--display-cop-names"]
end

RSpec::Core::RakeTask.new(:spec)

task :default => :spec
