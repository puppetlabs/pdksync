source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in pdksync.gemspec
gemspec

group :development do
  gem 'rb-readline', require: true
end

group :rubocop do
  gem "rubocop", '~> 1.73.0',                    require: false
  gem "rubocop-performance", '~> 1.24.0',        require: false
  gem "rubocop-rspec", '~> 3.5.0',               require: false
  gem "rubocop-rspec_rails", '~> 2.31.0',        require: false
  gem "rubocop-factory_bot", '~> 2.27.0',        require: false
  gem "rubocop-capybara", '~> 2.22.0',           require: false
end
