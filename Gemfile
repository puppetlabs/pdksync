source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in pdksync.gemspec
gemspec

gem 'github_changelog_generator', '~> 1.15'

group :development do
  gem 'rb-readline', require: true
end

group :rubocop do
    gem 'rubocop', '~> 1.6.1', require: false
end
