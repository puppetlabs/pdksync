# -*- encoding: utf-8 -*-
# stub: jenkins_api_client 2.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "jenkins_api_client".freeze
  s.version = "2.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Kannan Manickam".freeze]
  s.date = "2023-03-20"
  s.description = "\nThis is a simple and easy-to-use Jenkins Api client with features focused on\nautomating Job configuration programaticaly and so forth".freeze
  s.email = ["arangamani.kannan@gmail.com".freeze]
  s.executables = ["jenkinscli".freeze]
  s.files = ["bin/jenkinscli".freeze]
  s.homepage = "https://github.com/arangamani/jenkins_api_client".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.7".freeze)
  s.rubygems_version = "3.1.6".freeze
  s.summary = "Jenkins JSON API Client".freeze

  s.installed_by_version = "3.1.6" if s.respond_to? :installed_by_version

  if s.respond_to? :specification_version then
    s.specification_version = 4
  end

  if s.respond_to? :add_runtime_dependency then
    s.add_runtime_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
    s.add_runtime_dependency(%q<thor>.freeze, [">= 0.16.0"])
    s.add_runtime_dependency(%q<terminal-table>.freeze, [">= 1.4.0"])
    s.add_runtime_dependency(%q<mixlib-shellout>.freeze, [">= 1.1.0"])
    s.add_runtime_dependency(%q<socksify>.freeze, [">= 1.7.0"])
    s.add_runtime_dependency(%q<json>.freeze, [">= 1.0"])
    s.add_runtime_dependency(%q<addressable>.freeze, ["~> 2.7"])
  else
    s.add_dependency(%q<nokogiri>.freeze, ["~> 1.6"])
    s.add_dependency(%q<thor>.freeze, [">= 0.16.0"])
    s.add_dependency(%q<terminal-table>.freeze, [">= 1.4.0"])
    s.add_dependency(%q<mixlib-shellout>.freeze, [">= 1.1.0"])
    s.add_dependency(%q<socksify>.freeze, [">= 1.7.0"])
    s.add_dependency(%q<json>.freeze, [">= 1.0"])
    s.add_dependency(%q<addressable>.freeze, ["~> 2.7"])
  end
end
