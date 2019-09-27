require_relative '../../lib/pdksync'
require 'git'
require 'fileutils'
require 'octokit'

describe PdkSync do
  before(:all) do
    @pdksync_dir = './modules_pdksync'
    module_name = 'puppetlabs-testing'
    @module_names = ['puppetlabs-testing']
    @output_path = "#{@pdksync_dir}/#{module_name}"
    @folder = Dir.pwd
  end

  before(:each) do
    allow(PdkSync).to receive(:return_modules).and_return(@module_names)
    allow(PdkSync).to receive(:validate_modules_exist).and_return(@module_names)
    Dir.chdir(@folder)
  end

  context 'main method' do
    it 'runs clone sucessfully' do
      FileUtils.rm_rf(@pdksync_dir)
      PdkSync.create_filespace
      PdkSync.main(steps: [:clone])
      expect(Dir.exist?(@pdksync_dir)).to be(true)
      expect(Dir.exist?(@output_path)).to be(true)
    end
    it 'runs pdk convert, and files have changed' do
      PdkSync.main(steps: [:pdk_convert])
      File.exist?("#{@output_path}/convert_report.txt")
    end
    it 'raise when running a command with no argument' do
      expect { PdkSync.main(steps: [:run_a_command]) }.to raise_error(RuntimeError, %r{"run_a_command" requires an argument to run.})
    end
    it 'runs a command "touch cat.meow"' do
      PdkSync.main(steps: [:run_a_command], args: 'touch cat.meow')
      expect File.exist?("#{@output_path}/cat.meow")
    end
    it 'raise when create_commit with no arguments' do
      expect { PdkSync.main(steps: [:create_commit]) }.to raise_error(RuntimeError, %r{Needs a branch_name and commit_message})
    end
    it 'create_commit runs, and contains the "kittens in mittens"' do
      PdkSync.main(steps: [:create_commit], args: { branch_name: 'temp_branch', commit_message: 'kittens in mittens' })
      git_repo = Git.open(@output_path)
      expect(git_repo.show).to include('kittens in mittens')
    end
    it 'raise when create_pr with no arguments' do
      expect { PdkSync.main(steps: [:create_pr]) }.to raise_error(RuntimeError, %r{Needs a pr_title})
    end
    it 'raise when create_pr with invalid label' do
      expect { PdkSync.main(steps: [:create_pr], args: { pr_title: 'My amazing PR', label: 'doot doot' }) }.to raise_error(RuntimeError, %r{Ensure label is valid})
    end
    it 'raise when clean_branches with no arguments' do
      expect { PdkSync.main(steps: [:clean_branches]) }.to raise_error(RuntimeError, %r{Needs a branch_name, and the branch name contains the string pdksync})
    end
    it 'raise when gem_file_update with no arguments' do
      expect { PdkSync.main(steps: [:gem_file_update]) }.to raise_error(RuntimeError, %r{gem_file_update" requires arguments (gem_to_test) to run.})
    end
    # it 'gem_file_update runs, and contains the gem_line given' do
    #   PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'beaker-rspec', gem_line: "gem beaker-rspec '~> 3.4'"})
    #   expect(file).to have_file_content "gem beaker-rspec '~> 3.4'"
    # end
    # it 'gem_file_update runs, and contains the gem_sha given' do
    #   PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'beaker-rspec', gem_sha_finder: 'jsjsjsjsjsjsjs', gem_sha_replacer: 'abcdefgjhkk'})
    #   expect(file).to have_file_content "abcdefgjhkk"
    # end
    # it 'gem_file_update runs, and contains the gem_version given' do
    #   PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'beaker-rspec', gem_version_finder: '<= 0.4.9', gem_version_replacer: '<= 0.4.11'})
    #   expect(file).to have_file_content "abcdefgjhkk"
    # end
    # it 'gem_file_update runs, and contains the gem_branch given' do
    #   PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'beaker-rspec', gem_branch_finder: 'jsjsjsjsjsjsjs', gem_branch_replacer: 'abcdefgjhkk'})
    #   expect(file).to have_file_content "abcdefgjhkk"
    # end
    it 'raise when run_tests with no arguments' do
      expect { PdkSync.main(steps: [:run_tests]) }.to raise_error(RuntimeError, %r{run_tests" requires arguments (module_type) to run.})
    end
  end
end
