require_relative 'lib/pdksync'

desc 'Run pdk update'
task :pdksync do
  PdkSync::run_pdksync
  puts "The script has run."
end

desc 'Run pdksync cleanup'
task :pdksync_cleanup do
  PdkSync::clean_branches
  puts "The script has run."
end
