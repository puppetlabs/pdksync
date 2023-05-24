# -*- encoding: utf-8 -*-
# stub: pdk 2.7.1 ruby lib

Gem::Specification.new do |s|
  s.name = "pdk".freeze
  s.version = "2.7.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Puppet, Inc.".freeze]
  s.bindir = "exe".freeze
  s.date = "2023-03-28"
  s.description = "A CLI to facilitate easy, unified development workflows for Puppet modules.".freeze
  s.email = ["pdk-maintainers@puppet.com".freeze]
  s.executables = ["pdk".freeze]
  s.files = ["exe/pdk".freeze]
  s.homepage = "https://github.com/puppetlabs/pdk".freeze
  s.required_ruby_version = Gem::Requirement.new(">= 2.5.9".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A key part of the Puppet Development Kit, the shortest path to better modules".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<bundler>.freeze, [">= 2.3.0", "< 3.0.0"])
    s.add_runtime_dependency(%q<childprocess>.freeze, ["~> 4.1.0"])
    s.add_runtime_dependency(%q<cri>.freeze, ["~> 2.15.11"])
    s.add_runtime_dependency(%q<diff-lcs>.freeze, [">= 1.5.0"])
    s.add_runtime_dependency(%q<ffi>.freeze, [">= 1.15.5", "< 2.0.0"])
    s.add_runtime_dependency(%q<hitimes>.freeze, ["= 2.0.0"])
    s.add_runtime_dependency(%q<json-schema>.freeze, ["= 2.8.0"])
    s.add_runtime_dependency(%q<json_pure>.freeze, ["~> 2.6.2"])
    s.add_runtime_dependency(%q<minitar>.freeze, ["~> 0.6"])
    s.add_runtime_dependency(%q<pathspec>.freeze, ["~> 0.2.1"])
    s.add_runtime_dependency(%q<tty-prompt>.freeze, ["~> 0.23"])
    s.add_runtime_dependency(%q<tty-spinner>.freeze, ["~> 0.9"])
    s.add_runtime_dependency(%q<tty-which>.freeze, ["~> 0.5"])
    s.add_runtime_dependency(%q<concurrent-ruby>.freeze, ["~> 1.1.10"])
    s.add_runtime_dependency(%q<facter>.freeze, [">= 4.0.0", "< 5.0.0"])
    s.add_runtime_dependency(%q<httpclient>.freeze, ["~> 2.8.3"])
    s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.2.2"])
  else
    s.add_dependency(%q<bundler>.freeze, [">= 2.3.0", "< 3.0.0"])
    s.add_dependency(%q<childprocess>.freeze, ["~> 4.1.0"])
    s.add_dependency(%q<cri>.freeze, ["~> 2.15.11"])
    s.add_dependency(%q<diff-lcs>.freeze, [">= 1.5.0"])
    s.add_dependency(%q<ffi>.freeze, [">= 1.15.5", "< 2.0.0"])
    s.add_dependency(%q<hitimes>.freeze, ["= 2.0.0"])
    s.add_dependency(%q<json-schema>.freeze, ["= 2.8.0"])
    s.add_dependency(%q<json_pure>.freeze, ["~> 2.6.2"])
    s.add_dependency(%q<minitar>.freeze, ["~> 0.6"])
    s.add_dependency(%q<pathspec>.freeze, ["~> 0.2.1"])
    s.add_dependency(%q<tty-prompt>.freeze, ["~> 0.23"])
    s.add_dependency(%q<tty-spinner>.freeze, ["~> 0.9"])
    s.add_dependency(%q<tty-which>.freeze, ["~> 0.5"])
    s.add_dependency(%q<concurrent-ruby>.freeze, ["~> 1.1.10"])
    s.add_dependency(%q<facter>.freeze, [">= 4.0.0", "< 5.0.0"])
    s.add_dependency(%q<httpclient>.freeze, ["~> 2.8.3"])
    s.add_dependency(%q<deep_merge>.freeze, ["~> 1.2.2"])
  end
end
