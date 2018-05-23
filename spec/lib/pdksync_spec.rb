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
  end

  context 'env' do
    it 'has a filespace' do
      FileUtils.rm_rf(@pdksync_dir)
      PdkSync.create_filespace
      expect(Dir.exist?(@pdksync_dir)).to be(true)
    end

    it 'has cloned the repo' do
      PdkSync.clone_directory(@namespace, @module_name, @output_path)
      expect(Dir.exist?(@output_path)).to be(true)
    end
  end

  context 'run' do
    before(:all) do
      @git_repo = Git.open(@output_path)
    end

    it 'has created a branch' do
      PdkSync.checkout_branch(@git_repo, @timestamp)
      expect(@git_repo.current_branch).to include(@timestamp.to_s)
    end

    it 'has created a report' do
      FileUtils.rm_rf('update_report.txt')
      PdkSync.pdk_update(@output_path)
      expect(File.exist?('update_report.txt')).to be(true)
    end

    it 'has staged files' do
      PdkSync.add_staged_files(@git_repo)
      result = Open3.capture3('git status')
      expect(result).to include(%r{Changes to be committed})
    end

    it 'has committed files' do
      pre_commit = @git_repo.log.last
      PdkSync.commit_staged_files(@git_repo, @timestamp)
      post_commit = @git_repo.log.last
      expect(pre_commit).not_to eq(post_commit)
    end
  end
  # Test fails if ran from travis due to lack of proper credentials
  # it 'The committed files should be pushed and the PR created', unless: @access_token == '' do
  #   @client = PdkSync.setup_client
  #   PdkSync.push_staged_files(@git_repo, @timestamp, @repo_name)
  #   pr = PdkSync.create_pr(@client, @repo_name, @timestamp, @timstamp)
  #   expect(pr.title).to eq("pdksync - pdksync_#{@timestamp}")
  #   #Branch is now cleaned
  #   PdkSync.delete_branch(@client, @repo_name, "pdksync_#{@timestamp}".to_s)
  # end
end
