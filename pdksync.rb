#!/usr/bin/env ruby
require 'git'

checkout_path = './pdksync/checkout/'
supported_path = 'https://github.com/puppetlabs/'

# Handles arguments, has the basis for iteration through a hash later on.
ARGV.each do|a|
  module_url = "#{supported_path}#{a}"
  module_path = "#{checkout_path}#{a}"
  if !Dir.exist?(module_path) || Dir.empty?(module_path)
	  Git.clone(module_url, module_path)
    puts "Argument: #{a} has been cloned to #{module_path}."
  end
end
