require 'pdksync'
require 'colorize'

desc 'Run full pdksync process, clone repository, pdk update, create pr. Additional title information can be added to the title, which will be appended before the reference section.'
task :pdksync, [:additional_title] do |_task, args|
  args = { branch_name: 'pdksync_{ref}',
           commit_message: 'pdksync_{ref}',
           pr_title: 'pdksync_{ref}',
           additional_title: args[:additional_title] }
  PdkSync.main(steps: [:use_pdk_ref, :clone, :pdk_update, :create_commit, :push, :create_pr], args: args)
end

desc 'Run full gem_testing process, clone repository, gemfile update, create pr. Additional title information can be added to the title, which will be appended before the reference section.'
task :gem_testing, [:additional_title, :gem_to_test, :gem_line, :gem_sha_finder, :gem_sha_replacer, :gem_version_finder, :gem_version_replacer, :gem_branch_finder, :gem_branch_replacer] do |_task, args| # rubocop:disable Metrics/LineLength
  args = { branch_name: 'pdksync_gem_testing{ref}',
           commit_message: 'pdksync_gem_testing{ref}',
           pr_title: 'pdksync_gem_testing{ref}',
           additional_title: args[:additional_title],
           gem_to_test: args[:gem_to_test],
           gem_line: args[:gem_line],
           gem_sha_finder: args[:gem_sha_finder],
           gem_sha_replacer: args[:gem_sha_replacer],
           gem_version_finder: args[:gem_version_finder],
           gem_version_replacer: args[:gem_version_replacer],
           gem_branch_finder: args[:gem_branch_finder],
           gem_branch_replacer: args[:gem_branch_replacer] }
  PdkSync.main(steps: [:use_pdk_ref, :clone, :gem_file_update, :create_commit, :push, :create_pr], args: args)
end

namespace :pdksync do
  desc 'Runs PDK convert against modules'
  task :pdk_convert do
    PdkSync.main(steps: [:pdk_convert])
  end

  desc 'Runs PDK validate against modules'
  task :pdk_validate do
    PdkSync.main(steps: [:pdk_validate])
  end

  desc "Run a command against modules eg rake 'run_a_command[complex command here -f -gx]'"
  task :run_a_command, [:command] do |_task, args|
    PdkSync.main(steps: [:run_a_command], args: args[:command])
  end

  desc "Gem File Update'gem_file_update[gem_to_test, gem_line, gem_sha_finder, gem_sha_replacer, gem_version_finder, gem_version_replacer, gem_branch_finder, gem_branch_replacer]'"
  task :gem_file_update, [:gem_to_test, :gem_line, :gem_sha_finder, :gem_sha_replacer, :gem_version_finder, :gem_version_replacer, :gem_branch_finder, :gem_branch_replacer] do |_task, args|
    PdkSync.main(steps: [:gem_file_update], args: args)
  end

  desc "Run test against modules eg rake 'run_tests[litmus]'"
  task :run_tests, [:module_type] do |_task, args|
    PdkSync.main(steps: [:run_tests], args: args)
  end

  desc 'Display the current configuration of pdksync'
  task :show_config do
    include PdkSync::Constants
    puts 'Please note that you can override any of the configuration by using an additional file at `$HOME/.pdksync.yml`.'.bold.red
    puts 'PDKSync Configuration'.bold.yellow
    puts '- Git hosting platform: '.bold + PdkSync::Constants::GIT_PLATFORM.to_s.cyan
    puts '- Git base URI: '.bold + PdkSync::Constants::GIT_BASE_URI.to_s.cyan
    if PdkSync::Constants::GIT_PLATFORM == :gitlab
      puts '- Gitlab API endpoint: '.bold + PdkSync::Constants::GITLAB_API_ENDPOINT.to_s.cyan
    end
    puts '- Namespace: '.bold + PdkSync::Constants::NAMESPACE.to_s.cyan
    puts '- PDKSync Dir: '.bold + PdkSync::Constants::PDKSYNC_DIR.to_s.cyan
    puts '- Push File Destination: '.bold + PdkSync::Constants::PUSH_FILE_DESTINATION.to_s.cyan
    puts '- Create PR Against: '.bold + PdkSync::Constants::CREATE_PR_AGAINST.to_s.cyan
    puts '- Managed Modules: '.bold + PdkSync::Constants::MANAGED_MODULES.to_s.cyan
    puts '- Default PDKSync Label: '.bold + PdkSync::Constants::PDKSYNC_LABEL.to_s.cyan
  end
end

namespace :git do
  desc 'Clone managed modules'
  task :clone_managed_modules do
    PdkSync.main(steps: [:clone])
  end

  desc "Stage commits for modules, branchname and commit message eg rake 'git:create_commit[flippity, commit messagez]'"
  task :create_commit, [:branch_name, :commit_message] do |_task, args|
    PdkSync.main(steps: [:create_commit], args: args)
  end

  desc "Push commits for the module eg rake 'git:push'"
  task :push do |_task|
    PdkSync.main(steps: [:push], args: nil)
  end

  desc "Create PR for modules eg rake 'git:create_pr[pr title goes here, optional label right here]'"
  task :create_pr, [:pr_title, :label] do |_task, args|
    PdkSync.main(steps: [:create_pr], args: args)
  end

  desc "Clean up origin branches, (branches must include pdksync in their name) eg rake 'git:clean[pdksync_origin_branch]'"
  task :clean_branches, [:branch_name] do |_task, args|
    PdkSync.main(steps: [:clean_branches], args: args)
  end
end
