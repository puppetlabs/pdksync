require_relative '../../lib/pdksync'
require 'git'
require 'fileutils'
require 'octokit'

describe PdkSync do
  before(:all) do
    @timestamp = Time.now.to_i
    @namespace = 'puppetlabs'
    @pdksync_dir = './modules_pdksync'
    @module_name = 'puppetlabs-testing'
    @output_path = "#{@pdksync_dir}/#{@module_name}"
    @access_token = ENV['GITHUB_TOKEN']

    @repo_name = "#{@namespace}/#{@module_name}"
    @branch_name = "pdksync_#{@timestamp}"
  end

  context 'The environment is set up' do
    it 'The filespace should exist' do
      PdkSync.create_filespace

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
      PdkSync.checkout_branch(@git_repo)

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
      PdkSync.commit_staged_files(@git_repo)
      post_commit = @git_repo.log.last
      expect(pre_commit).not_to eq(post_commit)
    end

    # Test fails if ran from travis due to lack of proper credentials
    # it 'The committed files should be pushed and the PR created', unless: @access_token == '' do
    #   @client = PdkSync.setup_client(@access_token)
    #   PdkSync.push_staged_files(@git_repo, @branch_name)
    #   pr = PdkSync.create_pr(@client, @repo_name, @branch_name)
    #   expect(pr.title).to eq("pdksync - pdksync_#{@timestamp}")
    # end
  end
end
