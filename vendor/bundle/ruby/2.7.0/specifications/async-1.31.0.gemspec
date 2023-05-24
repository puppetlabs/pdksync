# -*- encoding: utf-8 -*-
# stub: async 1.31.0 ruby lib

Gem::Specification.new do |s|
  s.name = "async".freeze
  s.version = "1.31.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Samuel Williams".freeze]
  s.date = "2023-03-02"
  s.homepage = "https://github.com/socketry/async".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.0".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A concurrency framework for Ruby.".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<console>.freeze, ["~> 1.10"])
    s.add_runtime_dependency(%q<nio4r>.freeze, ["~> 2.3"])
    s.add_runtime_dependency(%q<timers>.freeze, ["~> 4.1"])
    s.add_development_dependency(%q<async-rspec>.freeze, ["~> 1.1"])
    s.add_development_dependency(%q<bake>.freeze, [">= 0"])
    s.add_development_dependency(%q<benchmark-ips>.freeze, [">= 0"])
    s.add_development_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_development_dependency(%q<covered>.freeze, ["~> 0.10"])
    s.add_development_dependency(%q<rspec>.freeze, ["~> 3.6"])
  else
    s.add_dependency(%q<console>.freeze, ["~> 1.10"])
    s.add_dependency(%q<nio4r>.freeze, ["~> 2.3"])
    s.add_dependency(%q<timers>.freeze, ["~> 4.1"])
    s.add_dependency(%q<async-rspec>.freeze, ["~> 1.1"])
    s.add_dependency(%q<bake>.freeze, [">= 0"])
    s.add_dependency(%q<benchmark-ips>.freeze, [">= 0"])
    s.add_dependency(%q<bundler>.freeze, [">= 0"])
    s.add_dependency(%q<covered>.freeze, ["~> 0.10"])
    s.add_dependency(%q<rspec>.freeze, ["~> 3.6"])
  end
end
