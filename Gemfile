source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in pdksync.gemspec
gemspec

gem 'github_changelog_generator', git: 'https://github.com/skywinder/github-changelog-generator', ref: 'master'
gem 'travis'

group :development do
  gem 'pry', require: true
  gem 'rb-readline', require: true
end
