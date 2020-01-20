lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name = 'pdksync'
  spec.version = '0.5.0'
  spec.authors = ['Puppet']
  spec.email = ['']
  spec.summary = 'Puppet Module PDK Synchronizer'
  spec.description = 'Utility to synchronize common files across puppet modules using PDK Update.'
  spec.homepage = 'http://github.com/puppetlabs/pdksync'
  spec.license = 'Apache-2.0'
  spec.required_ruby_version = '>= 2.0.0'

  spec.files = `git ls-files -z`.split("\x0")
  spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop', '~> 0.50.0'
  spec.add_development_dependency 'pry'
  spec.add_runtime_dependency 'pdk', '>= 1.14.1'
  spec.add_runtime_dependency 'git', '~>1.3'
  spec.add_runtime_dependency 'rake'
  spec.add_runtime_dependency 'gitlab'
  spec.add_runtime_dependency 'octokit'
  spec.add_runtime_dependency 'colorize'
  spec.add_runtime_dependency 'jenkins_api_client'
end
