# Set environment variable if it does not exist
unless ENV['GITHUB_TOKEN']
  ENV['GITHUB_TOKEN'] = 'github-token'
end
