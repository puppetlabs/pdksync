require 'spec_helper'
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
    allow(PdkSync::GitPlatformClient).to receive(:new).and_return(platform)
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: '1' }])
  end

  context 'main method' do
    let(:platform) { Object.new }

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
      label = double(:label)
      allow(label).to receive(:name).and_return('not_existent')
      allow(platform).to receive(:labels).and_return([label])
      expect { PdkSync.main(steps: [:create_pr], args: { pr_title: 'My amazing PR', label: 'doot doot' }) }.to raise_error(RuntimeError, %r{Ensure label is valid})
    end
    it 'raise when clean_branches with no arguments' do
      expect { PdkSync.main(steps: [:clean_branches]) }.to raise_error(RuntimeError, %r{Needs a branch_name, and the branch name contains the string pdksync})
    end
  end
end
