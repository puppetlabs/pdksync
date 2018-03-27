#!/usr/bin/env ruby
# Rune Command: ruby RepoClone.rb HelenCampbell puppetlabs-motd
require 'git'
require 'fileutils'

# Inputs are collected and then checked to insure they are correct
@user = ARGV[0]
@input_array = ARGV[1..-1]
unless @input_array.size >= 1
  puts 'The require input has not been given, please enter the user name followed by at least one module.'
end

@input_array.each do |module_name|
  # Set's the output path of the module
  @output_path = "./modules/#{module_name}"
  # Check's if the module has already been downloaded.
  if File.directory?(@output_path)
    # Deletes the module if it has.
    FileUtils.rm_rf(@output_path)
  end

  # The module is cloned into the set output.
  @clone = Git.clone("https://github.com/#{@user}/#{module_name}", @output_path)

  # A check to ensure the module exist's.
  if File.directory?(@output_path)
    puts module_name + ' cloned successfully.'
  end
end