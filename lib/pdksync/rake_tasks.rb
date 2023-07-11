require 'pdksync'
require 'logger'

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
  PdkSync.main(steps: [:use_gem_ref, :clone, :gem_file_update, :create_commit, :push, :create_pr], args: args)
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

  desc "Run a command against modules eg rake 'run_a_command[complex command here -f -gx, 'background']'"
  task :run_a_command, [:command, :option] do |_task, args|
    PdkSync.main(steps: [:run_a_command], args: args)
  end

  desc "Gem File Update'gem_file_update[gem_to_test, gem_line, gem_sha_finder, gem_sha_replacer, gem_version_finder, gem_version_replacer, gem_branch_finder, gem_branch_replacer]'"
  task :gem_file_update, [:gem_to_test, :gem_line, :gem_sha_finder, :gem_sha_replacer, :gem_version_finder, :gem_version_replacer, :gem_branch_finder, :gem_branch_replacer] do |_task, args|
    PdkSync.main(steps: [:gem_file_update], args: args)
  end

  desc "Run test against modules eg rake 'run_tests_locally[litmus, 'provision_type']'"
  task :run_tests_locally, [:provision_type, :puppet_collection] do |_task, args|
    PdkSync.main(steps: [:run_tests_locally], args: args)
  end

  desc "Fetch run results against modules eg rake 'fetch_test_results_locally[litmus]'"
  task :fetch_test_results_locally do
    PdkSync.main(steps: [:fetch_test_results_locally])
  end

  desc "Run test in jenkins for traditional modules eg rake 'run_tests_jenkins['jenkins_server_url', 'branchname']'"
  task :run_tests_jenkins, [:jenkins_server_url, :github_branch, :test_framework, :github_user] do |_task, args|
    PdkSync.main(steps: [:run_tests_jenkins], args: args)
  end

  desc 'Multi Gem Testing, multi_gem_testing[gem_name, version_file, build_gem, gem_path, gemfury_username]'
  task :multi_gem_testing, [:gem_name, :version_file, :build_gem, :gem_path, :gemfury_username] do |_task, args|
    PdkSync.main(steps: [:multi_gem_testing], args: args)
  end

  desc 'Multi Gem File Update, multigem_file_update[gem_name, gemfury_username]'
  task :multigem_file_update, [:gem_name, :gemfury_username] do |_task, args|
    PdkSync.main(steps: [:multigem_file_update], args: args)
  end

  desc 'Display the current configuration of pdksync'
  task :show_config do
    config = PdkSync::Configuration.new
    puts 'Please note that you can override any of the configuration by using an additional file at `$HOME/.pdksync.yml`.'.bold.red
    puts "\nPDKSync Configuration:".bold.yellow
    config.to_h.each do |key, value|
      puts "- #{key}: " + value.to_s.light_blue
    end
  end

  desc "Fetch run results against traditional modules eg rake 'fetch_traditional_test_results'"
  task :test_results_jenkins, [:jenkins_server_url] do |_task, args|
    PdkSync.main(steps: [:test_results_jenkins], args: args)
  end

  desc 'Add a provision list key to provision.yaml'
  task :add_provision_list, [:key, :provisioner, :images] do |_task, args|
    PdkSync.main(steps: [:add_provision_list], args: args)
  end

  desc 'Generates release checks in provision.yaml based on module compatible platforms and puppet version'
  task :generate_vmpooler_release_checks, [:puppet_version] do |_task, args|
    PdkSync.main(steps: [:generate_vmpooler_release_checks], args: args)
  end

  desc 'Update the metadata.json OS supported list to that defined in conf/supported_os_list.yaml'
  task :update_os_support do |_task, args|
    PdkSync.main(steps: [:update_os_support], args: args)
  end

  desc 'Remove a platform version from the metadata.json'
  task :remove_platform_from_metadata, [:os, :version] do |_task, args|
    PdkSync.main(steps: [:remove_platform_from_metadata], args: args)
  end

  desc 'Add a platform version to the metadata.json'
  task :add_platform_to_metadata, [:os, :version] do |_task, args|
    PdkSync.main(steps: [:add_platform_to_metadata], args: args)
  end

  desc 'Add or update a requirement in the metadata.json'
  task :update_requirements, [:name, :key, :value] do |_task, args|
    PdkSync.main(steps: [:update_requirements], args: args)
  end

  desc 'Normalise the OS and OS versions in the metadata.json'
  task :normalize_metadata_supported_platforms do |_task, args|
    PdkSync.main(steps: [:normalize_metadata_supported_platforms], args: args)
  end
end

namespace :git do
  desc 'Clone managed modules'
  task :clone_managed_modules do
    PdkSync.main(steps: [:clone])
  end

  desc 'Clone managed gem'
  task :clone_gem, [:gem_name] do |_task, args|
    PdkSync.main(steps: [:clone_gem], args: args)
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
