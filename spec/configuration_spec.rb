require 'spec_helper'
require 'pdksync/configuration'


RSpec.describe 'configuration' do

    before(:each) do
      allow(ENV).to receive(:[]).with('HOME').and_return('./')
      allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('blah')
      allow(ENV).to receive(:[]).with('PDK_CONFIG_PATH').and_return(nil)
    end

    let(:instance) do
        PdkSync::Configuration.new
    end

    it '#new' do
        expect(instance).to be_a PdkSync::Configuration
    end

    it 'passes when token is provided' do
        expect(instance).to be_a PdkSync::Configuration
    end

    it 'raises error without token' do
      allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return(nil)
      expect{instance}.to raise_error(ArgumentError)
    end

    it '#custom_config' do
      expect(instance.custom_config).to be_a Hash
    end

    it '#custom_config does not exist' do
      expect(instance.custom_config('/tmp/blah')).to be_a Hash
    end

    it '#custom_config exists' do
        config = File.join(fixtures_dir, 'pdksync.yml')
        data = instance.custom_config(config)
        expect(data).to be_a Hash
        expect(data[:namespace]).to eq('voxpupuli')
    end

    it '#locate_config_path' do
      expect(instance.local_config_path).to be_nil
    end

    it '#locate_config_path with value' do
        config = File.join(fixtures_dir, 'pdksync.yml')
        expect(instance.locate_config_path(config)).to eq(config)
    end
end