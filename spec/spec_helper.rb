# frozen_string_literal: true

if ENV['SIMPLECOV'] == 'yes'
  begin
    require 'simplecov'
    require 'simplecov-console'
    require 'codecov'

    SimpleCov.formatters = [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console,
      SimpleCov::Formatter::Codecov
    ]
    SimpleCov.start do
      track_files 'lib/**/*.rb'
      add_filter '/spec'

      # do not track vendored files
      add_filter '/vendor'
      add_filter '/.vendor'

      # do not track gitignored files
      # this adds about 4 seconds to the coverage check
      # this could definitely be optimized
      add_filter do |f|
        # system returns true if exit status is 0, which with git-check-ignore means file is ignored
        system("git check-ignore --quiet #{f.filename}")
      end
    end
  rescue LoadError
    raise 'Add the simplecov, simplecov-console, codecov gems to Gemfile to enable this task'
  end
end

require 'rspec'
require 'git'
require 'fileutils'

def pupmods_dir
  @pupmods_dir ||= begin
    p = File.join(fixtures_dir, 'puppetlabs')
    FileUtils.mkdir_p(p) unless File.exist?(p)
    p
  end
end

def remote_testing_repo
  File.join(pupmods_dir, 'puppetlabs-testing.git')
end

# localizes the remote repo for faster testing, download once and use the local machine as the remote repo
def setup_fake_module
  Git.clone('https://github.com/puppetlabs/puppetlabs-testing.git', remote_testing_repo) unless Dir.exist?(File.join(remote_testing_repo, '.git'))
end

def destroy_fake_modules
  FileUtils.rm_rf(pupmods_dir)
end

def fixtures_dir
  @fixtures_dir ||= File.join(__dir__, 'fixtures')
end

RSpec.configure do |config|
  config.before(:suite) do
    setup_fake_module
    # provide a fake github token for the tests
    ENV['GITHUB_TOKEN'] = 'github-token'
  end
  config.before(:each) do
    allow(PdkSync::Utils.configuration).to receive(:git_base_uri).and_return("file://#{fixtures_dir}")
  end
  config.after(:suite) { FileUtils.rm_rf(pupmods_dir) }
end
