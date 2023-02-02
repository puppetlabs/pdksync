require 'spec_helper'
require 'pdksync/utils'
require 'tempfile'
describe 'PdkSync::Utils' do
  before(:all) do
    @tmp_dir = Dir.mktmpdir('testing')
  end

  let(:cloned_module) do
    begin
      Git.open(@tmp_dir)
    rescue ArgumentError
      PdkSync::Utils.clone_directory('puppetlabs',
                                     'puppetlabs-testing', @tmp_dir)
    end
  end

  let(:metadata_file) do
    File.join(@tmp_dir, 'metadata.json')
  end

  before(:each) do
    cloned_module
  end

  after(:all) do
    FileUtils.remove_entry @tmp_dir
  end

  it '#self.clone_directory' do
    Dir.mktmpdir do |dir|
      PdkSync::Utils.clone_directory('puppetlabs',
                                     'puppetlabs-testing', dir)
      expect(cloned_module).to be_a Git::Base
    end
  end

  it '#self.create_commit' do
    File.write(File.join(@tmp_dir, 'README.md'), rand(32_332))
    expect(PdkSync::Utils.create_commit(cloned_module, 'main', 'boom')).to match(%r{boom})
  end

  it '#self.run_command' do
    expect(PdkSync::Utils.run_command('./', 'pwd', nil)).to eq(0)
  end

  it '#self.pdk_update' do
    run_update = PdkSync::Utils.pdk_update(@tmp_dir)
    sleep(100)
    expect(run_update).to eq(0)
  end

  it '#self.return_template_ref' do
    expect(PdkSync::Utils.return_template_ref(metadata_file)).to match(%r{^heads\/main\S+$})
  end

  it '#self.module_templates_url' do
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: 'v1.14.1' }])
    url, version = PdkSync::Utils.module_templates_url(metadata_file).split('#')
    expect(url).to eq('https://github.com/puppetlabs/pdk-templates')
    expect(version).to match(%r{main})
  end

  it '#self.change_module_template_url' do
    url = 'https://github.com/nwops/pdk-templates'
    ref = 'special'
    expect(PdkSync::Utils.change_module_template_url(url, ref, metadata_file)).to eq('https://github.com/nwops/pdk-templates#special')
  end

  it '#self.checkout_branch' do
    PdkSync::Utils.checkout_branch(cloned_module, 'sync1234')
    branch = cloned_module.branches.find { |b| b.name.eql?('pdksync_sync1234') }
    expect(branch).to be_a Git::Branch
  end

  it '#self.check_pdk_version is false' do
    process = double
    allow(process).to receive(:exitstatus).and_return(true)
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: 'v1.14.1' }])
    allow(PdkSync::Utils).to receive(:return_pdk_path).and_return('/opt/puppetlabs/pdk/bin/pdk')
    allow(Open3).to receive(:capture3).with('/opt/puppetlabs/pdk/bin/pdk --version').and_return(['1.14.0', nil, process])
    expect(PdkSync::Utils.check_pdk_version).to be false
  end

  it '#self.check_pdk_version is true' do
    process = double
    allow(process).to receive(:exitstatus).and_return(true)
    allow(PdkSync::Utils).to receive(:return_pdk_path).and_return('/opt/puppetlabs/pdk/bin/pdk')
    allow(Open3).to receive(:capture3).with('/opt/puppetlabs/pdk/bin/pdk --version').and_return(['1.14.0', nil, process])
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: 'v1.14.0' }])
    expect(PdkSync::Utils.check_pdk_version).to be true
  end

  it '#self.check_gem_latest_version' do
    process = double
    allow(process).to receive(:exitstatus).and_return(true)
    allow(Octokit).to receive(:tags).with('puppetlabs/puppet_module_gems').and_return([{ name: '0.4.0' }])
    expect(PdkSync::Utils.check_gem_latest_version('puppet_module_gems')).to eq '0.4.0'
  end

  it '#self.update_gem_latest_version_by_one' do
    expect(PdkSync::Utils.update_gem_latest_version_by_one('0.4.0')).to eq Gem::Version.new('0.5')
  end

  it '#self.create_filespace' do
    expect(PdkSync::Utils.create_filespace).to eq('modules_pdksync')
  end

  it '#self.setup_client' do
    g = double(PdkSync::GitPlatformClient)
    expect(PdkSync::GitPlatformClient).to receive(:new).with(:github,
                                                             access_token: 'github-token',
                                                             api_endpoint: nil,
                                                             gitlab_api_endpoint: 'https://gitlab.com/api/v4').and_return(g)
    expect(PdkSync::Utils.setup_client).to eq(g)
  end

  it '#self.return_modules' do
    allow_any_instance_of(PdkSync::Configuration).to receive(:managed_modules).and_return(File.join(fixtures_dir, 'fake_managed_modules.yaml'))
    expect(PdkSync::Utils.return_modules).to eq(['puppetlabs/puppetlabs-testing'])
  end

  it '#self.validate_modules_exist' do
    client = double
    allow_any_instance_of(PdkSync::Configuration).to receive(:managed_modules).and_return(File.join(fixtures_dir, 'fake_managed_modules.yaml'))
    allow(client).to receive(:repository?).with('puppetlabs/puppetlabs-testing').and_return(true)
    expect(PdkSync::Utils.validate_modules_exist(client, ['puppetlabs-testing'])).to be true
  end

  it '#self.create_filespace_gem' do
    expect(PdkSync::Utils.create_filespace_gem).to eq('gems_pdksync')
  end
end
