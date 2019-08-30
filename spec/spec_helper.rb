require 'rspec'

# Set environment variable if it does not exist
unless ENV['GITHUB_TOKEN']
  ENV['GITHUB_TOKEN'] = 'github-token'
end

def fixtures_dir
  @fixtures_dir ||= File.join(__dir__, 'fixtures')
end
