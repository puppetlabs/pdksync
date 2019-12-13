require 'pdksync'
require 'spec_helper'
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

  let(:platform) { Object.new }

  before(:each) do
    allow(ENV).to receive(:[]).with('HOME').and_return('./')
    allow(ENV).to receive(:[]).with('GIT_DIR').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_WORK_TREE').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_INDEX_FILE').and_return(nil)
    allow(ENV).to receive(:[]).with('PDKSYNC_LOG_FILENAME').and_return(nil)
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_SSH').and_return(nil)
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('blah')
    allow(ENV).to receive(:[]).with('PDKSYNC_VERSION_CHECK').and_return(nil)
    allow(ENV).to receive(:[]).with('http_proxy').and_return(nil)
    allow(ENV).to receive(:[]).with('HTTP_PROXY').and_return(nil)
    allow(ENV).to receive(:[]).with('PDKSYNC_CONFIG_PATH').and_return(nil)
    allow(PdkSync::Utils).to receive(:return_modules).and_return(@module_names)
    allow(PdkSync::Utils).to receive(:validate_modules_exist).and_return(@module_names)
    allow(PdkSync::Utils).to receive(:setup_client).and_return(git_client)
    Dir.chdir(@folder)
    allow(PdkSync::GitPlatformClient).to receive(:new).and_return(platform)
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: '1' }])
  end

  let(:git_client) do
    double(PdkSync::GitPlatformClient)
  end

  context 'main method' do
    it 'runs clone sucessfully' do
      allow(PdkSync::Utils).to receive(:setup_client).and_return(git_client)
      FileUtils.rm_rf(@pdksync_dir)
      PdkSync::Utils.create_filespace
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

    it 'raise when create_pr with no arguments' do
      expect { PdkSync.main(steps: [:create_pr]) }.to raise_error(RuntimeError, %r{Needs a pr_title})
    end

    it 'create_pr with 1 argument' do
      expect { PdkSync.main(steps: [:create_pr], args: { pr_title: 'some title' }) }.to_not raise_error
    end

    it 'raise when clean_branches with no arguments' do
      expect { PdkSync.main(steps: [:clean_branches]) }.to raise_error(RuntimeError, %r{Needs a branch_name, and the branch name contains the string pdksync})
    end
  end
end
