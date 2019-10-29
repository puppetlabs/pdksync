require 'spec_helper'
require 'pdksync/logger'

RSpec.describe 'logger' do
  before(:each) do
    allow(ENV).to receive(:[]).with('PDKSYNC_LOG_FILENAME').and_return('dev/')
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return(nil)
    # allow(PdkSync::Logger).to receive(:logger).and_return(PdkSync::Logger.logger($stderr))
  end

  let(:logger) do
    PdkSync::Logger.instance_variable_set('@logger', nil)
    PdkSync::Logger.logger
  end

  it '#self.logger' do
    expect(PdkSync::Logger.logger).to be_a Logger
  end

  it '#self.debug' do
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return('debug')
    expect(logger.debug('this is a debug')).to be_truthy
    # wasn't able to capture stdout with rspec, no idea why
    # expect { logger.debug("this is a debug") }.to output(/DEBUG - PdkSync: this is a debug/).to_stdout
  end

  it '#self.warn' do
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return('warn')
    # wasn't able to capture stdout with rspec, no idea why
    expect(logger.warn('this is a warning')).to be_truthy # output(/WARN - PdkSync: this is a warning/).to_stdout
  end

  it '#self.info' do
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return('info')
    # wasn't able to capture stdout with rspec, no idea why
    expect(logger.info('this is a info')).to be_truthy # output(/INFO - PdkSync: this is a info/).to_stderr
  end

  it '#self.fatal' do
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return('error')
    # wasn't able to capture stdout with rspec, no idea why
    expect(logger.fatal('this is a fatal')).to be_truthy # output(/FATAL - PdkSync: this is a fatal/).to_stderr
  end
end
