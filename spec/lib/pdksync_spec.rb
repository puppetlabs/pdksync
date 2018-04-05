require_relative '../../lib/pdksync'
require 'git'
require 'fileutils'

describe PdkSync do
  before(:all) do
    @timestamp = Time.now.to_i
    @namespace = 'HelenCampbell'
    @pdksync_dir = './modules_pdksync'
    @module_name = 'puppetlabs-motd'
    @output_path = "#{@pdksync_dir}/#{@module_name}"
  end

  context 'The environment is set up' do
    it 'The filespace should exist' do
      PdkSync.create_filespace(@pdksync_dir)

      expect(Dir.exist?(@pdksync_dir)).to be(true)
    end

    it 'The repo should be cloned' do
      PdkSync.clone_directory(@namespace, @module_name, @output_path)

      expect(Dir.exist?(@output_path)).to be(true)
    end
  end

  context 'The changes are made and committed' do
    before(:all) do
      @git_repo = Git.open(@output_path)
    end

    it 'The repo should be branched' do
      PdkSync.checkout_branch(@timestamp, @git_repo)

      expect(@git_repo.current_branch).to eq("pdksync_#{@timestamp}")
    end

    it 'There should be am update report' do
      PdkSync.pdk_update(@output_path)
      expect(File.exist?('update_report.txt')).to be(true)
    end

    it 'The files should be staged' do
      PdkSync.add_staged_files(@git_repo)
    end

    it 'The staged files should be committed' do
      pre_commit = @git_repo.log.last
      PdkSync.commit_staged_files(@git_repo, @timestamp)
      post_commit = @git_repo.log.last
      expect(pre_commit).not_to eq(post_commit)
    end
  end
end
