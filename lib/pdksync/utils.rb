# @summary provides a module with various methods for performing the desired tasks
require 'git'
require 'open3'
require 'fileutils'
require 'pdk'
require 'pdksync/configuration'
require 'pdksync/gitplatformclient'
require 'bundler'
require 'octokit'
require 'pdk/util/template_uri'
require 'pdksync/logger'

module PdkSync
  module Utils
    def self.configuration
      @configuration ||= PdkSync::Configuration.new
    end

    def self.on_windows?
      # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
      # library uses that to test what platform it's on.
      !!File::ALT_SEPARATOR # rubocop:disable Style/DoubleNegation
    end

    def self.temp_file_path
      @temp_file_path ||= on_windows? ? "#{ENV['TEMP']}\\out.tmp" : '/tmp/out.tmp'
    end

    # @summary
    #   This method when called will delete any preexisting branch on the given repository that matches the given name.
    # @param [PdkSync::GitPlatformClient] client
    #   The Git platform client used to gain access to and manipulate the repository.
    # @param [String] repo_name
    #   The name of the repository from which the branch is to be deleted.
    # @param [String] branch_name
    #   The name of the branch that is to be deleted.
    def self.delete_branch(client, repo_name, branch_name)
      client.delete_branch(repo_name, branch_name)
    rescue StandardError => error
      PdkSync::Logger.fatal "Deleting #{branch_name} in #{repo_name} failed. #{error}"
    end

    # @summary
    #   This method when called will add a given label to a given repository
    # @param [PdkSync::GitPlatformClient] client
    #   The Git Platform client used to gain access to and manipulate the repository.
    # @param [String] repo_name
    #   The name of the repository on which the commit is to be made.
    # @param [Integer] issue_number
    #   The id of the issue (i.e. pull request) to add the label to.
    # @param [String] label
    #   The label to add.
    def self.add_label(client, repo_name, issue_number, label)
      client.update_issue(repo_name, issue_number, labels: [label])
    rescue StandardError => error
      PdkSync::Logger.info "Adding label to #{repo_name} issue #{issue_number} has failed. #{error}"
      return false
    end

    # @summary
    #   This method when called will check on the given repository for the existence of the supplied label
    # @param [PdkSync::GitPlatformClient] client
    #   The Git platform client used to gain access to and manipulate the repository.
    # @param [String] repo_name
    #   The name of the repository on which the commit is to be made.
    # @param [String] label
    #   The label to check for.
    # @return [Boolean]
    #   A boolean stating whether the label was found.
    def self.check_for_label(client, repo_name, label)
      # Get labels from repository
      repo_labels = client.labels(repo_name)

      # Look for label in the repository's labels
      match = false
      repo_labels.each do |repo_label|
        if repo_label.name == label
          match = true
          break
        end
      end

      # Raise error if a match was not found else return true
      (match == false) ? (raise StandardError, "Label '#{label}' not found in #{repo_name}") : (return true)
    rescue StandardError => error
      PdkSync::Logger.fatal "Retrieving labels for #{repo_name} has failed. #{error}"
      return false
    end

    # @summary
    #   This method when called will retrieve the pdk_version of the current module, i.e. the one that was navigated into in the 'pdk_update' method.
    # @param [String] metadata_file
    #   An optional input that can be used to set the location of the metadata file.
    # @return [String]
    #   A string value that represents the current pdk version.
    def self.return_pdk_version(metadata_file = 'metadata.json')
      file = File.read(metadata_file)
      data_hash = JSON.parse(file)
      data_hash['pdk-version']
    end

    # @summary
    #   This method when called will stage all changed files within the given repository, conditional on them being managed via the pdk.
    # @param [Git::Base] git_repo
    #   A git object representing the local repository to be staged.
    def self.add_staged_files(git_repo)
      if !git_repo.status.changed.empty?
        git_repo.add(all: true)
        PdkSync::Logger.info 'All files have been staged.'
        true
      else
        PdkSync::Logger.info 'Nothing to commit.'
        false
      end
    end

    # @summary
    #   This method when called will create a commit containing all currently staged files, with the name of the commit containing the template ref as a unique identifier.
    # @param [Git::Base] git_repo
    #   A git object representing the local repository against which the commit is to be made.
    # @param [String] template_ref
    #   The unique template_ref that is used as part of the commit name.
    # @param [String] commit_message
    #   If specified it will be the message for the commit.
    def self.commit_staged_files(git_repo, template_ref, commit_message = nil)
      message = if commit_message.nil?
                  "pdksync_#{template_ref}"
                else
                  commit_message
                end
      git_repo.commit(message)
    end

    # @summary
    #   This method when called will push the given local commit to local repository's origin.
    # @param [Git::Base] git_repo
    #   A git object representing the local repository againt which the push is to be made.
    # @param [String] template_ref
    #   The unique reference that that represents the template the update has ran against.
    # @param [String] repo_name
    #   The name of the repository on which the commit is to be made.
    def self.push_staged_files(git_repo, current_branch, repo_name)
      git_repo.push(configuration.push_file_destination, current_branch)
    rescue StandardError => error
      PdkSync::Logger.error "Pushing to #{configuration.push_file_destination} for #{repo_name} has failed. #{error}"
    end

    # @summary
    #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the main with the pdk version as an identifier.
    # @param [PdkSync::GitPlatformClient] client
    #   The Git platform client used to gain access to and manipulate the repository.
    # @param [String] repo_name
    #   The name of the repository on which the commit is to be made.
    # @param [String] template_ref
    #   The unique reference that that represents the template the update has ran against.
    # @param [String] pdk_version
    #   The current version of the pdk on which the update is run.
    def self.create_pr(client, repo_name, template_ref, pdk_version, pr_title = nil)
      if pr_title.nil?
        title = "pdksync - Update using #{pdk_version}"
        message = "pdk version: `#{pdk_version}` \n pdk template ref: `#{template_ref}`"
        head = "pdksync_#{template_ref}"
      else
        title = "pdksync - #{pr_title}"
        message = "#{pr_title}\npdk version: `#{pdk_version}` \n"
        head = template_ref
      end
      client.create_pull_request(repo_name, configuration.create_pr_against,
                                 head,
                                 title,
                                 message)
    rescue StandardError => error
      PdkSync::Logger.fatal "PR creation for #{repo_name} has failed. #{error}"
      nil
    end

    # @summary
    #   Try to use a fully installed pdk, otherwise fall back to the bundled pdk gem.
    # @return String
    #   Path to the pdk executable
    def self.return_pdk_path
      full_path = '/opt/puppetlabs/pdk/bin/pdk'
      path = if File.executable?(full_path)
               full_path
             else
               PdkSync::Logger.warn "(WARNING) Using pdk on PATH not '#{full_path}'"
               'pdk'
             end
      path
    end

    # @return
    def self.create_commit(git_repo, branch_name, commit_message)
      checkout_branch(git_repo, branch_name)
      commit_staged_files(git_repo, branch_name, commit_message) if add_staged_files(git_repo)
    end

    # @summary
    #   This method when called will call the delete function against the given repository if it exists.
    # @param [String] output_path
    #   The repository that is to be deleted.
    def self.clean_env(output_path)
      # If a local copy already exists it is removed
      FileUtils.rm_rf(output_path)
    end

    # @summary
    #   This method when called will clone a given repository into a local location that has also been set.
    # @param [String] namespace
    #   The namespace the repository is located in.
    # @param [String] module_name
    #   The name of the repository.
    # @param [String] output_path
    #   The location the repository is to be cloned to.
    # @return [Git::Base]
    #   A git object representing the local repository or true if already exist
    def self.clone_directory(namespace, module_name, output_path)
      # not all urls are public facing so we need to conditionally use the correct separator
      sep = configuration.git_base_uri.start_with?('git@') ? ':' : '/'
      clone_url = "#{configuration.git_base_uri}#{sep}#{namespace}/#{module_name}.git"
      Git.clone(clone_url, output_path.to_s)
    rescue ::Git::GitExecuteError => error
      PdkSync::Logger.fatal "Cloning #{module_name} has failed. #{error}"
    end

    # @summary
    #   This method when called will run a command command at the given location, with an error message being thrown if it is not successful.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] command
    #   The command to be run.
    # @return [Integer]
    #   The status code of the command run.
    def self.run_command(output_path, command, option)
      stdout = ''
      stderr = ''
      status = Process::Status
      pid = ''
      Dir.chdir(output_path) unless Dir.pwd == output_path

      # Environment cleanup required due to Ruby subshells using current Bundler environment
      if option.nil? == true
        if command =~ %r{^bundle}
          Bundler.with_clean_env do
            stdout, stderr, status = Open3.capture3(command)
          end
        else
          stdout, stderr, status = Open3.capture3(command)
        end
        PdkSync::Logger.info "\n#{stdout}\n" unless stdout.empty?
        PdkSync::Logger.error "Unable to run command '#{command}': #{stderr}" unless status.exitstatus.zero?
        status.exitstatus
      else
        # Environment cleanup required due to Ruby subshells using current Bundler environment
        if command =~ %r{^sh }
          Bundler.with_clean_env do
            pid = spawn(command, out: 'run_command.out', err: 'run_command.err')
            Process.detach(pid)
          end
        end
        pid
      end
    end

    # @summary
    #   This method when called will run the 'pdk update --force' command at the given location, with an error message being thrown if it is not successful.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @return [Integer]
    #   The status code of the pdk update run.
    def self.pdk_update(output_path)
      # Runs the pdk update command
      Dir.chdir(output_path) do
        _, module_temp_ref = module_templates_url.split('#')
        module_temp_ref ||= configuration.pdk_templates_ref
        template_ref = configuration.module_is_authoritive ? module_temp_ref : configuration.pdk_templates_ref
        change_module_template_url(configuration.pdk_templates_url, template_ref) unless configuration.module_is_authoritive
        _stdout, stderr, status = Open3.capture3("#{return_pdk_path} update --force --template-ref=#{template_ref}")
        PdkSync::Logger.fatal "Unable to run `pdk update`: #{stderr}" unless status.exitstatus.zero?
        status.exitstatus
      end
    end

    # @summary
    #   This method when called will retrieve the template ref of the current module, i.e. the one that was navigated into in the 'pdk_update' method.
    # @param [String] metadata_file
    #   An optional input that can be used to set the location of the metadata file.
    # @return [String]
    #   A string value that represents the current pdk template.
    def self.return_template_ref(metadata_file = 'metadata.json')
      file = File.read(metadata_file)
      data_hash = JSON.parse(file)
      data_hash['template-ref']
    end

    # @summary
    #   This method when called will retrieve the tempalate-url of the current module,
    # @param metadata_file [String]
    #   An optional input that can be used to set the location of the metadata file.
    # @param url [String] - the url of the pdk-templates repo
    # @return [String]
    #   A string value that represents the current pdk tempalate-url.
    def self.module_templates_url(metadata_file = 'metadata.json')
      file = File.read(metadata_file)
      data_hash = JSON.parse(file)
      data_hash['template-url']
    end

    # @param [String] - the url of the pdk-templates
    # @param [String] -  the ref of the pdk templates you want to change to
    # @return [String] - the updated url
    def self.change_module_template_url(url, ref, metadata_file = 'metadata.json')
      content = File.read(metadata_file)
      uri = PDK::Util::TemplateURI.uri_safe(url.to_s + "##{ref}")
      data_hash = JSON.parse(content)
      data_hash['template-url'] = uri
      File.write(metadata_file, data_hash.to_json)
      uri.to_s
    end

    # @summary
    #   This method when called will checkout a new local branch of the given repository.
    # @param [Git::Base] git_repo
    #   A git object representing the local repository to be branched.
    # @param [String] branch_suffix
    #   The string that is appended on the branch name. eg template_ref or a friendly name
    def self.checkout_branch(git_repo, branch_suffix)
      git_repo.branch("pdksync_#{branch_suffix}").checkout
    end

    # @summary
    #   Check the local pdk version against the most recent tagged release on GitHub
    # @return [Boolean] true if the remote version is less than or equal to local version
    def self.check_pdk_version
      stdout, _stderr, status = Open3.capture3("#{return_pdk_path} --version")
      PdkSync::Logger.fatal "Unable to find pdk at '#{return_pdk_path}'." unless status.exitstatus
      local_version = stdout.strip
      remote_version = Octokit.tags('puppetlabs/pdk').first[:name][1..-1]
      up2date = Gem::Version.new(remote_version) <= Gem::Version.new(local_version)
      unless up2date
        PdkSync::Logger.warn "The current version of pdk is #{remote_version} however you are using #{local_version}"
      end
      up2date
    rescue StandardError => error
      PdkSync::Logger.warn "Unable to check latest pdk version. #{error}"
    end

    # @summary
    #   This method when called will create a directory identified by the set global variable 'configuration.pdksync_dir', on the condition that it does not already exist.
    def self.create_filespace
      FileUtils.mkdir_p configuration.pdksync_dir unless Dir.exist?(configuration.pdksync_dir)
      configuration.pdksync_dir
    end

    # @summary
    #   This method when called will create a directory identified by the set global variable 'configuration.pdksync_gem_dir', on the condition that it does not already exist.
    def self.create_filespace_gem
      FileUtils.mkdir_p configuration.pdksync_gem_dir unless Dir.exist?(configuration.pdksync_gem_dir)
      configuration.pdksync_gem_dir
    end

    # @summary
    #   This method when called will create and return an octokit client with access to the upstream git repositories.
    # @return [PdkSync::GitPlatformClient] client
    #   The Git platform client that has been created.
    def self.setup_client
      PdkSync::GitPlatformClient.new(configuration.git_platform, configuration.git_platform_access_settings)
    rescue StandardError => error
      raise "Git platform access not set up correctly: #{error}"
    end

    # @summary
    #   This method when called will create and return an octokit client with access to jenkins.
    # @return [PdkSync::JenkinsClient] client
    #   The Git platform client that has been created.
    def self.setup_jenkins_client(jenkins_server_url)
      require 'pdksync/jenkinsclient'
      if configuration.jenkins_platform_access_settings[:jenkins_username].nil?
        raise ArgumentError, "Jenkins access token for #{configuration.jenkins_platform.capitalize} not set"\
            " - use 'export #{configuration.jenkins_platform.upcase}_USERNAME=\"<your username>\"' to set"
      elsif configuration.jenkins_platform_access_settings[:jenkins_password].nil?
        raise ArgumentError, "Jenkins access token for #{jenkins_platform.capitalize} not set"\
        " - use 'export #{jenkins_platform.upcase}_PASSWORD=\"<your password>\"' to set"
      end
      PdkSync::JenkinsClient.new(jenkins_server_url, configuration.jenkins_platform_access_settings)
    rescue StandardError => error
      raise "Jenkins platform access not set up correctly: #{error}"
    end

    # @summary
    #   This method when called will access a file set by the global variable 'configuration.managed_modules' and retrieve the information within as an array.
    # @return [Array]
    #   An array of different module names.
    def self.return_modules
      raise "File '#{configuration.managed_modules}' is empty/does not exist" if File.size?(configuration.managed_modules).nil?
      YAML.safe_load(File.open(configuration.managed_modules))
    end

    # @summary
    #   This method when called will parse an array of module names and verify
    #   whether they are valid repo or project names on the configured Git
    #   hosting platform.
    # @param [PdkSync::GitPlatformClient] client
    #   The Git platform client used to get a repository.
    # @param [Array] module_names
    #   String array of the names of Git platform repos
    def self.validate_modules_exist(client, module_names)
      raise "Error reading in modules. Check syntax of '#{configuration.managed_modules}'." unless !module_names.nil? && module_names.is_a?(Array)
      invalid = module_names.reject { |name| client.repository?("#{configuration.namespace}/#{name}") }
      # Raise error if any invalid matches were found
      raise "Could not find the following repositories: #{invalid}" unless invalid.empty?
      true
    end

    # @summary
    #   This method when called will update a Gemfile and remove the existing version of gem from the Gemfile.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] gem_to_test
    #   The Gem to test.
    # @param [String] gem_line
    #   The gem line to replace
    # @param [String] gem_sha_finder
    #   The gem sha to find
    # @param [String] gem_sha_replacer
    #   The gem sha to replace
    # @param [String] gem_version_finder
    #   The gem version to find
    # @param [String] gem_version_replacer
    #   The gem version to replace
    # @param [String] gem_branch_finder
    #   The gem branch to find
    # @param [String] gem_branch_replacer
    #   The gem branch to replace
    def self.gem_file_update(output_path, gem_to_test, gem_line, gem_sha_finder, gem_sha_replacer, gem_version_finder, gem_version_replacer, gem_branch_finder, gem_branch_replacer, main_path)
      gem_file_name = 'Gemfile'
      validate_gem_update_module(gem_to_test, gem_line, output_path, main_path)

      if (gem_line.nil? == false) && (gem_sha_replacer != '\"\"')
        new_data = get_source_test_gem(gem_to_test, gem_line)
        new_data.each do |data|
          if data.include?('branch')
            gem_branch_replacer = data.split(' ')[1].strip.chomp('"').delete("'")
          elsif data.include?('ref')
            gem_sha_replacer = data.split(' ')[1].strip.chomp('').delete("'")
          elsif data =~ %r{~>|=|>=|<=|<|>}
            delimiters = ['>', '<', '>=', '<=', '=']
            version_to_check = data.split(Regexp.union(delimiters))[1].chomp('""').delete("'")
            validate_gem_version_replacer(version_to_check.to_s, gem_to_test)
          end
        end
      end

      if gem_sha_replacer.nil? == false && gem_sha_replacer != '\"\"' && gem_sha_replacer != ''
        validate_gem_sha_replacer(gem_sha_replacer.chomp('"').reverse.chomp('"').reverse, gem_to_test)
      end
      if gem_branch_replacer.nil? == false && gem_branch_replacer != '\"\"'
        validate_gem_branch_replacer(gem_branch_replacer.chomp('"').reverse.chomp('"').reverse, gem_to_test)
      end
      if gem_version_replacer.nil? == false && gem_version_replacer != '\"\"' && gem_version_replacer != ''
        delimiters = ['<', '>', '<=', '>=', '=']
        version_to_check = gem_version_replacer.split(Regexp.union(delimiters))
        version_to_check.each do |version|
          next if version.nil?
          validate_gem_version_replacer(version.to_s, gem_to_test) unless version == ''
        end
      end

      Dir.chdir(output_path) unless Dir.pwd == output_path

      line_number = 1
      gem_update_sha = [
        { finder: "ref: '#{gem_sha_finder}'",
          replacer: "ref: '#{gem_sha_replacer}'" }
      ]
      gem_update_version = [
        { finder: gem_version_finder,
          replacer: gem_version_replacer }
      ]
      gem_update_branch = [
        { finder: "branch: '#{gem_branch_finder}'",
          replacer: "branch: '#{gem_branch_replacer}'" }
      ]
      # gem_line option is passed

      if gem_line.nil? == false && (gem_line != '' || gem_line != '\"\"')

        # Delete the gem in the Gemfile to add the new line
        gem_test = gem_to_test.chomp('"').reverse.chomp('"').reverse
        File.open(temp_file_path, 'w') do |out_file|
          File.foreach(gem_file_name) do |line|
            out_file.puts line unless line =~ %r{#{gem_test}}
          end
        end
        FileUtils.mv(temp_file_path, gem_file_name)

        # Insert the new Gem to test
        file = File.open(gem_file_name)
        contents = file.readlines.map(&:chomp)
        contents.insert(line_number, gem_line.chomp('"').reverse.chomp('"').reverse)
        File.open(gem_file_name, 'w') { |f| f.write contents.join("\n") }
      end

      # gem_sha_finder and gem_sha_replacer options are passed
      if gem_sha_finder.nil? == false && gem_sha_replacer.nil? == false && gem_sha_finder != '' && gem_sha_finder != '\"\"' && gem_sha_replacer != '' && gem_sha_replacer != '\"\"'
        # Replace with SHA
        file = File.open(gem_file_name)
        contents = file.readlines.join
        gem_update_sha.each do |regex|
          contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer])
        end
        File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
      end

      # gem_version_finder and gem_version_replacer options are passed
      if gem_version_finder.nil? == false && gem_version_replacer.nil? == false && gem_version_finder != '' && gem_version_finder != '\"\"' && gem_version_replacer != '' && gem_version_replacer != '\"\"' # rubocop:disable Metrics/LineLength
        # Replace with version
        file = File.open(gem_file_name)
        contents = file.readlines.join
        gem_update_version.each do |regex|
          contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer])
        end
        File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
      end

      # gem_branch_finder and gem_branch_replacer options are passed
      if gem_branch_finder.nil? == false && gem_branch_replacer.nil? == false && gem_branch_finder != '' && gem_branch_finder != '\"\"' && gem_branch_replacer != '' && gem_branch_replacer != '\"\"' # rubocop:disable Metrics/LineLength, Style/GuardClause
        # Replace with branch
        file = File.open(gem_file_name)
        contents = file.readlines.join
        gem_update_branch.each do |regex|
          contents = contents.gsub(%r{#{regex[:finder]}}, regex[:replacer]) # unless contents =~ %r{#{gem_to_test}}
        end
        File.open(gem_file_name, 'w') { |f| f.write contents.to_s }
      end
    end

    # @summary
    #   This method is used to identify the type of module.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] repo_name
    #   The module name to identify the type
    def self.module_type(output_path, repo_name)
      if repo_name.nil? == false
        module_type = if File.exist?("#{output_path}/provision.yaml")
                        'litmus'
                      else
                        'traditional'
                      end
      end
      module_type
    end

    # @summary
    #   This method when called will run the 'module tests' command at the given location, with an error message being thrown if it is not successful.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] module_type
    #   The module type (litmus or traditional)
    # @param [String] module_name
    #   The module name
    # @param [String] puppet collection
    #   The puppet collection
    # @return [Integer]
    #   The status code of the pdk update run.
    def self.run_tests_locally(output_path, module_type, provision_type, module_name, puppet_collection)
      provision_type = provision_type.chomp('"').reverse.chomp('"').reverse
      status = Process::Status
      # Save the current path
      old_path = Dir.pwd

      # Create the acceptance scripts
      file = File.open('acc.sh', 'w')
      file.puts '#!/bin/sh'

      if puppet_collection
        file.puts "export PUPPET_GEM_VERSION='~> #{puppet_collection}'"
      end
      file.puts "rm -rf #{output_path}/Gemfile.lock;rm -rf #{output_path}/.bundle"
      file.puts 'bundle install --path .bundle/gems/ --jobs 4'
      file.puts "bundle exec rake 'litmus:provision_list[#{provision_type}]'"
      file.puts 'bundle exec rake litmus:install_agent'
      file.puts 'bundle exec rake litmus:install_module'
      file.puts 'bundle exec rake litmus:acceptance:parallel'
      file.puts 'bundle exec rake litmus:tear_down'
      file.close

      # Runs the module tests command
      if module_type == 'litmus'
        run_command(output_path, 'cp ../../acc.sh .', nil)
        Dir.chdir(old_path)
        run_command(output_path, 'chmod 777 acc.sh', nil)
        Dir.chdir(old_path)
        status = run_command(output_path, 'sh acc.sh 2>&1 | tee litmusacceptance.out', 'background')
        if status != 0
          PdkSync::Logger.info "SUCCESS:Kicking of module Acceptance tests to run for the module #{module_name} - SUCCEED.Results will be available in the following path #{output_path}/litmusacceptance.out.Process id is #{status}"
        else
          PdkSync::Logger.fatal "FAILURE:Kicking of module Acceptance tests to run for the module #{module_name} - FAILED.Results will be available in the following path #{output_path}/litmusacceptance.out."
        end
      end
      PdkSync::Logger.warn "(WARNING) Executing testcases locally supports only for litmus'" if module_type != 'litmus'
    end

    # @summary
    #   This method when called will fetch the module tests results.
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] module_type
    #   The module type (litmus or traditional)
    # @param [String] module_name
    #   The module name
    # @param [String] report_rows
    #   The module test results
    # @return [Integer]
    #   The status code of the pdk update run.
    def self.fetch_test_results_locally(output_path, module_type, module_name, report_rows)
      # Save the current path
      old_path = Dir.pwd
      if module_type != 'litmus'
        PdkSync::Logger.warn "(WARNING) Fetching test results locally supports only for litmus'"
      end

      # Run the tests
      Dir.chdir(old_path)
      lines = IO.readlines("#{output_path}/litmusacceptance.out")[-10..-1]
      if lines.find { |e| %r{exit} =~ e } # rubocop:disable Style/ConditionalAssignment
        report_rows << if lines.find { |e| %r{^Failed} =~ e } || lines.find { |e| %r{--trace} =~ e }
                         [module_name, 'FAILED', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                       else
                         [module_name, 'SUCCESS', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                       end
      else
        report_rows << if lines.find { |e| %r{^Failed} =~ e } || lines.find { |e| %r{--trace} =~ e } || lines.find { |e| %r{rake aborted} =~ e }
                         [module_name, 'FAILED', "Results are available in the following path #{output_path}/litmusacceptance.out"]
                       else
                         [module_name, 'PROGRESS', "Results will be available in the following path #{output_path}/litmusacceptance.out"]
                       end
      end
      return report_rows if module_type == 'litmus'
    end

    # @summary
    #   This method when called will find the source location of the gem to test
    # @param [String] gem_to_test
    #   The gem to test
    # @param [String] gem_line
    #   TThe line to update in the Gemfile
    # @return [String]
    #   The source location of the gem to test
    def self.get_source_test_gem(gem_to_test, gem_line)
      return gem_line.split(',') if gem_line
      return gem_to_test unless gem_to_test

      gemfile_line = File.readlines('Gemfile').find do |line|
        line.include?(gem_to_test.to_s)
      end

      return "https://github.com/puppetlabs/#{gem_to_test}" unless gemfile_line
      gemfile_line =~ %r{(http|https|ftp|ftps)\:\/\/[a-zA-Z0-9\-\.]+\.[a-zA-Z]{2,3}(\/\S*)?}
      line.split(',')[1].strip.to_s if line
    end

    # @summary
    #   This method when called will validate the gem_line to update in the Gemfile
    # @param [String] gem_to_test
    #   The gem to test
    # @param [String] gem_line
    #   The line to update in the Gemfile
    def self.validate_gem_update_module(gem_to_test, gem_line, output_path, main_path)
      gem_to_test = gem_to_test.chomp('"').reverse.chomp('"').reverse
      Dir.chdir(main_path)
      output_path = "#{configuration.pdksync_dir}/#{gem_to_test}"
      clean_env(output_path) if Dir.exist?(output_path)
      print 'delete module directory, '

      # when gem_line is specified, we need to parse the line and identify all the values
      # - we can have source url or we need to
      # - sha, branch, version
      if gem_line
        git_repo = get_source_test_gem(gem_to_test, gem_line)
        i = 0
        git_repo.each do |item|
          i += 1
          if item =~ %r{((git@|http(s)?:\/\/)([\w\.@]+)(\/|:))([\w,\-,\_]+)\/([\w,\-,\_]+)(.git){0,1}((\/){0,1})}
            git_repo = item.split('git:')[1].strip.delete("'")
            break
          elsif git_repo.size == i
            # git_repo = "https://github.com/puppetlabs#{gem_to_test}"
            sep = configuration.git_base_uri.start_with?('git@') ? ':' : '/'
            git_repo = "#{configuration.git_base_uri}#{sep}#{configuration.namespace}/#{gem_to_test}"
          end
        end
        print 'clone module directory, '
        git_repo = run_command(configuration.pdksync_dir.to_s, "git clone #{git_repo}", nil)
      elsif gem_to_test
        git_repo = clone_directory(configuration.namespace, gem_to_test, output_path.to_s)
      end

      Dir.chdir(main_path)
      raise "Unable to clone repo for #{gem_to_test}. Check repository's url to be correct!".red if git_repo.nil?

      @all_versions = ''
      @all_refs = ''
      @all_branches = ''

      Dir.chdir(output_path)

      stdout_refs, stderr_refs, status_refs = Open3.capture3('git show-ref -s')
      @all_refs = stdout_refs
      stdout_branches, stderr_branches, status_branches = Open3.capture3('git branch -a')
      @all_branches = stdout_branches
      stdout_versions, stderr_versions, status_versions = Open3.capture3('git tag')
      @all_versions = stdout_versions

      raise "Couldn't get references due to #{stderr_refs}".red unless status_refs.exitstatus.zero?
      raise "Couldn't get branches due to #{stderr_branches}".red unless status_branches.exitstatus.zero?
      raise "Couldn't get versions due to #{stderr_versions}".red unless status_versions.exitstatus.zero?
      Dir.chdir(main_path)
    end

    # @summary
    #   This method when called will validate the gem_sha_replacer to update in the Gemfile
    # @param [String] gem_to_test
    #   The gem to test
    # @param [String] gem_sha_replacer
    #   The sha to update in the Gemfile
    def self.validate_gem_sha_replacer(gem_sha_replacer, gem_to_test)
      found = false
      @all_refs.split(' ').each do |sha|
        puts "SHA #{gem_sha_replacer} valid.\n".green if gem_sha_replacer == sha
        found = true if gem_sha_replacer == sha
      end
      raise "Couldn't find sha: #{gem_sha_replacer} in your repository: #{gem_to_test}".red if found == false
    end

    # @summary
    #   This method when called will validate the gem_branch_replacer to update in the Gemfile
    # @param [String] gem_to_test
    #   The gem to test
    # @param [String] gem_branch_replacer
    #   The branch to update in the Gemfile
    def self.validate_gem_branch_replacer(gem_branch_replacer, gem_to_test)
      raise "Couldn't find branch: #{gem_branch_replacer} in your repository: #{gem_to_test}".red unless @all_branches.include?(gem_branch_replacer)
      puts "Branch #{gem_branch_replacer} valid.\n".green
    end

    # @summary
    #   This method when called will validate the gem_version_replacer to update in the Gemfile
    # @param [String] gem_to_test
    #   The gem to test
    # @param [String] gem_version_replacer
    #   The version to update in the Gemfile
    def self.validate_gem_version_replacer(gem_version_replacer, gem_to_test)
      found = false
      @all_versions.split(' ').each do |version|
        puts "Version #{gem_version_replacer} valid.\n".green if gem_version_replacer == version
        found = true if gem_version_replacer == version
      end
      raise "Couldn't find version: #{gem_version_replacer} in your repository: #{gem_to_test}".red if found == false
    end

    # @summary
    #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the main with the pdk version as an identifier.
    # @param [PdkSync::GitPlatformClient] client
    #   The Git platform client used to gain access to and manipulate the repository.
    # @param [String] ouput_path
    #   The location that the command is to be run from.
    # @param [String] jenkins_client
    #   Jenkins authentication.
    # @param [String] repo_name
    #   Module to run on Jenkins
    # @param [String] current_branch
    #   The branch against which the user needs to run the jenkin jobs
    def self.run_tests_jenkins(jenkins_client, repo_name, current_branch, github_user, job_name)
      if jenkins_client.nil? == false || repo_name.nil? == false || current_branch.nil? == false
        pr = jenkins_client.create_adhoc_job(repo_name,
                                             current_branch,
                                             github_user,
                                             job_name)
        pr
      end
    rescue StandardError => error
      puts "(FAILURE) Jenkins Job creation for #{repo_name} has failed. #{error}".red
    end

    # convert duration from ms to format h m s ms
    def self.duration_hrs_and_mins(ms)
      return '' unless ms
      hours, ms   = ms.divmod(1000 * 60 * 60)
      minutes, ms = ms.divmod(1000 * 60)
      seconds, ms = ms.divmod(1000)
      "#{hours}h #{minutes}m #{seconds}s #{ms}ms"
    end

    # return jenkins job urls
    def self.adhoc_urls(job_name, jenkins_server_urls)
      adhoc_urls = []
      # get adhoc jobs
      adhoc_urls.push("#{jenkins_server_urls}/job/#{job_name}")
      adhoc_urls.each do |url|
        conn = Faraday::Connection.new "#{url}/api/json"
        res = conn.get
        build_job_data = JSON.parse(res.body.to_s)
        downstream_job = build_job_data['downstreamProjects']
        break if downstream_job.empty?
        downstream_job.each do |item|
          next if item.nil?
          adhoc_urls.push(item['url']) unless item['url'].nil? && item['url'].include?('skippable_adhoc')
        end
      end
      adhoc_urls
    end

    # test_results_jenkins
    def self.test_results_jenkins(jenkins_server_url, build_id, job_name, module_name)
      PdkSync::Logger.info 'Fetch results from jenkins'
      # remove duplicates and sort the list
      adhoc_urls = adhoc_urls(job_name, jenkins_server_url).uniq.sort_by { |url| JSON.parse(Faraday.get("#{url}/api/json").body.to_s)['fullDisplayName'].scan(%r{[0-9]{2}\s}).first.to_i }
      report_rows = []
      @failed = false
      @in_progress = false
      @aborted = false

      File.delete("results_#{module_name}.out") if File.exist?("results_#{module_name}.out")
      # analyse each build result - get status, execution time, logs_link
      @data = "MODULE_NAME=#{module_name}\nBUILD_ID=#{build_id}\nINITIAL_job=#{jenkins_server_url}/job/#{job_name}/#{build_id}\n\n"
      write_to_file("results_#{module_name}.out", @data)
      PdkSync::Logger.info "Analyse test execution report \n"
      adhoc_urls.each do |url|
        # next if skipped in build name
        current_build_data = JSON.parse(Faraday.get("#{url}/api/json").body.to_s)
        next if url.include?('skippable_adhoc') || current_build_data['color'] == 'notbuilt'
        next if current_build_data['fullDisplayName'].downcase.include?('skipped')
        returned_data = get_data_build(url, build_id, module_name) unless @failed || @in_progress
        generate_report_table(report_rows, url, returned_data)
      end

      table = Terminal::Table.new title: "Module Test Results for: #{module_name}\nCheck results in #{Dir.pwd}/results_#{module_name}.out ", headings: %w[Status Result Execution_Time], rows: report_rows
      PdkSync::Logger.info "SUCCESSFUL test results!\n".green unless @failed || @in_progress
      PdkSync::Logger.info "\n#{table} \n"
    end

    # generate report table when running tests on jenkins
    def self.generate_report_table(report_rows, url, data)
      if @failed
        report_rows << ['FAILED', url, data[1]] unless data.nil?
      elsif @aborted
        report_rows << ['ABORTED', url, data[1]] unless data.nil?
      else
        report_rows << [data[0], url, data[1]] unless data.nil?
      end
    end

    # for each build from adhoc jobs, get data
    # if multiple platforms under current url, get data for each platform
    def self.get_data_build(url, build_id, module_name)
      current_build_data = JSON.parse(Faraday.get("#{url}/api/json").body.to_s)
      if current_build_data['activeConfigurations'].nil?
        returned_data = analyse_jenkins_report(url, module_name, build_id)
        if returned_data[0] == 'in progress'
          @in_progress = true
        elsif returned_data[0] == 'FAILURE'
          @failed = true
        elsif returned_data[0] == 'ABORTED'
          @aborted = true
        end
      else
        platforms_list = []
        current_build_data['activeConfigurations'].each do |url_child|
          next if url_child['color'] == 'notbuilt'
          platforms_list.push(url_child['url'])
        end

        platforms_list.each do |platform_build|
          returned_data = analyse_jenkins_report(platform_build, module_name, build_id)
          if returned_data[0] == 'in progress'
            @in_progress = true
          elsif returned_data[0] == 'FAILURE'
            @failed = true
          elsif returned_data[0] == 'ABORTED'
            @aborted = true
          end
        end
      end

      @data = "\nFAILURE. Fix the failures and rerun tests!\n" if @failed
      @data = "\nIN PROGRESS. Please check test report after the execution is done!\n" if @in_progress
      write_to_file("results_#{module_name}.out", @data) if @failed || @in_progress
      PdkSync::Logger.info 'Failed status! Fix errors and rerun.'.red if @failed
      PdkSync::Logger.info 'Aborted status! Fix errors and rerun.'.red if @aborted
      PdkSync::Logger.info 'Tests are still running! You can fetch the results later by using this task: test_results_jenkins'.blue if @in_progress
      returned_data
    end

    # write test report to file
    def self.write_to_file(file, _data)
      File.open(file, 'a') do |f|
        f.write @data
      end
    end

    # analyse jenkins report
    def self.analyse_jenkins_report(url, module_name, build_id)
      # builds don't have the same build_id. That's why just the init build will be identified by id, rest of them by lastBuild
      last_build_job_data = JSON.parse(Faraday.get("#{url}/#{build_id}/api/json").body.to_s) if url.include?('init-manual-parameters_adhoc')
      last_build_job_data = JSON.parse(Faraday.get("#{url}/lastBuild/api/json").body.to_s) unless url.include?('init-manual-parameters_adhoc')

      # status = 'not_built' unless last_build_job_data
      if last_build_job_data['result'].nil?
        status = 'in progress'
        execution_time = 'running'
      else
        status = last_build_job_data['result']
        execution_time = duration_hrs_and_mins(last_build_job_data['duration'].to_i)
      end

      # execution_time = 0 unless last_build_job_data
      logs_link = "#{url}/#{build_id}/" if url.include?('init-manual-parameters_adhoc')
      logs_link = "#{url}lastBuild/" unless url.include?('init-manual-parameters_adhoc')
      @data = "Job title =#{last_build_job_data['fullDisplayName']}\n logs_link = #{logs_link}\n status = #{status}\n"
      return_data = [status, execution_time]
      write_to_file("results_#{module_name}.out", @data)
      return_data
    end

    # @summary
    #   Check the most recent tagged release on GitHub for the gem
    # @param [String] gem_to_test
    #   The gem to test
    #   The current version of the gem
    def self.check_gem_latest_version(gem_to_test)
      remote_version = Octokit.tags("puppetlabs/#{gem_to_test}").first[:name]
    rescue StandardError => error
      puts "(WARNING) Unable to check latest gem version. #{error}".red
      remote_version
    end

    # @summary
    #   Update the gem version by one
    # @param [String] gem_version
    #   The current version of the gem
    #   The bump version by one of the gem
    def self.update_gem_latest_version_by_one(gem_version)
      current_version = Gem::Version.new gem_version
      new_version = current_version.bump
    rescue StandardError => error
      puts "(WARNING) Unable to check latest gem version. #{error}".red
      new_version
    end

    # @summary
    #   Update Gemfile with multigem
    # @param [String] output_path
    #   The location that the command is to be run from.
    # @param [String] gem_name
    #   The gem name
    # @param [String] gemfury_token
    #   The gemfury token
    # @param [String] gemfury_user
    #   The gemfury user
    def self.update_gemfile_multigem(output_path, gem_name, gemfury_token, gemfury_user)
      gem_file_name = 'Gemfile'
      gem_source_line = "source \"https://#{gemfury_token}@gem.fury.io/#{gemfury_user}/\""
      Dir.chdir(output_path) unless Dir.pwd == output_path

      if gem_name.nil? == false && gemfury_token.nil? == false && gemfury_user.nil? == false # rubocop:disable Style/GuardClause
        # Append the gem with new source location
        gem_name = gem_name.chomp('"').reverse.chomp('"').reverse
        begin
          File.open(temp_file_path, 'w') do |out_file|
            File.foreach(gem_file_name) do |line|
              if line =~ %r{#{gem_name}}
                line = line.chomp
                if line =~ %r{"https://#{gemfury_token}@gem.fury.io/#{gemfury_user}/"}
                  puts 'GemFile Already updated'.green
                  out_file.puts line.to_s
                else
                  out_file.puts "#{line} , :source => \"https://#{gemfury_token}@gem.fury.io/#{gemfury_user}/\""
                end
              else
                out_file.puts line
              end
            end
          end
          FileUtils.mv(temp_file_path, gem_file_name)

          # Insert the new source Gem location to Gemfile
          file = File.open(gem_file_name)
          contents = file.readlines.map(&:chomp)
          contents.insert(2, gem_source_line) unless contents.include?(gem_source_line)
          File.open(gem_file_name, 'w') { |f| f.write contents.join("\n") }
        rescue Errno::ENOENT => e
          raise "Couldn't find file: #{gem_file_name} #{e} in your repository: #{gem_file_name}".red
        rescue Errno::EACCES => e
          raise "Does not have required permissions to the #{gem_file_name} #{e} in your repository: #{gem_file_name}".red
        end
      end
    end

    # @summary
    #   Adds an entry to the 'provision.yaml' of a module with the values given
    # @param [String] module_path
    #   Path to the module root dir
    # @param [String] key
    #   Key name in 'provision.yaml' (e.g. "release_checks_7)
    # @param [String] provisioner
    #   The value for the provisioner key (e.g. "abs")
    # @param [Array] images
    #   The list of images for the images key (e.g. ['ubuntu-1804-x86_64, ubuntu-2004-x86_64', 'centos-8-x86_64'])
    # @return [Boolean]
    #   True if entry was successfully added to 'provision.yaml'
    #   False if 'provision.yaml' does not exist or is an empty file
    def self.add_provision_list(module_path, key, provisioner, images)
      path_to_provision_yaml = "#{module_path}/provision.yaml"
      return false unless File.exist? path_to_provision_yaml
      PdkSync::Logger.info "Updating #{path_to_provision_yaml}"
      provision_yaml = YAML.safe_load(File.read(path_to_provision_yaml))
      return false if provision_yaml.nil?
      provision_yaml[key] = {}
      provision_yaml[key]['provisioner'] = provisioner
      provision_yaml[key]['images'] = images
      File.write(path_to_provision_yaml, YAML.dump(provision_yaml))
    end

    # @summary
    #   Query the 'metadata.json' in the given module path and return the compatible platforms
    # @param [String] module_path
    #   Path to the module root dir
    # @return [Hash]
    #   The compatible OSs defined in the 'operatingsystem_support' key of the 'metadata.json'
    def self.module_supported_platforms(module_path)
      PdkSync::Logger.info 'Determining supported platforms from metadata.json'
      os_support_key = 'operatingsystem_support'
      metadata_json = "#{module_path}/metadata.json"
      raise 'Could not locate metadata.json' unless File.exist? metadata_json
      module_metadata = JSON.parse(File.read(metadata_json))
      raise "Could not locate '#{os_support_key}' key from #{metadata_json}" unless module_metadata.key? os_support_key
      module_metadata[os_support_key]
    end

    # @summary
    #   Take a Windows version extracted from the module's 'metadata.json' and normalize it to the version conventions
    #   that VMPooler uses
    # @param ver
    #   Version from 'metadata.json'
    # @return [String]
    #   Normalised version that is used by VMPooler templates
    def self.normalize_win_version(ver)
      PdkSync::Logger.debug "Normalising Windows version from metadata.json: #{ver}"
      win_ver_matcher = ver.match(%r{(?:Server\s)?(?<ver>\d+)(?:\s(?<rel>R\d))?})
      raise "Unable to determine Windows version from metadata.json: #{ver}" unless win_ver_matcher
      normalized_version = win_ver_matcher['ver']
      normalized_version += " #{win_ver_matcher['rel'].upcase}" if win_ver_matcher['rel']
      normalized_version
    end

    # @summary
    #   Normalize the given os name
    # @param os
    #   The OS name to normalize
    # @return [String]
    #   Normalized os name
    def self.normalize_os(os)
      case os
      when %r{aix}i
        'AIX'
      when %r{cent}i
        'CentOS'
      when %r{darwin}i
        'Darwin'
      when %r{deb}i
        'Debian'
      when %r{fedora}i
        'Fedora'
      when %r{oracle}i
        'OracleLinux'
      when %r{osx}i
        'OSX'
      when %r{pan}i
        'PAN-OS'
      when %r{red}i
        'RedHat'
      when %r{sci}i
        'Scientific'
      when %r{suse|sles}i
        'SLES'
      when %r{sol}i
        'Solaris'
      when %r{ubuntu}i
        'Ubuntu'
      when %r{win}i
        'Windows'
      when %r{rocky}i
        'Rocky'
      when %r{almalinux}i
        'AlmaLinux'
      else
        raise "Could not normalize OS value: #{os}"
      end
    end

    # @summary
    #   Get the metadata.json of the given module
    # @param module_path
    #   Path to the root dir of the module
    # @return [JSON]
    #   JSON of the metadata.json
    def self.metadata_json(module_path)
      metadata_json = "#{module_path}/metadata.json"
      raise 'Could not locate metadata.json' unless File.exist? metadata_json
      JSON.parse(File.read(metadata_json))
    end

    OPERATINGSYSTEM = 'operatingsystem'.freeze
    OPERATINGSYSTEMRELEASE = 'operatingsystemrelease'.freeze
    OPERATINGSYSTEM_SUPPORT = 'operatingsystem_support'.freeze

    # @summary
    #   Write the given metadata in JSON format to the given module root dir path
    # @param module_path
    #   Path to the root dir of the module
    # @param metadata_json
    #   Metadata in JSON format to write to the module root dir
    def self.write_metadata_json(module_path, metadata_json)
      File.open(File.join(module_path, 'metadata.json'), 'w') do |f|
        f.write(JSON.pretty_generate(metadata_json) + "\n")
      end
    end

    # @summary
    #   Normalize the 'operatingsystem_support' entries in the metadata.json
    # @param module_path
    #   Path to the root dir of the module
    def self.normalize_metadata_supported_platforms(module_path)
      new_metadata_json = metadata_json(module_path)

      new_metadata_json[OPERATINGSYSTEM_SUPPORT].each do |os_vers|
        normalized_os = normalize_os(os_vers[OPERATINGSYSTEM])
        unless normalized_os == os_vers[OPERATINGSYSTEM]
          PdkSync::Logger.info "Corrected OS Name: '#{os_vers[OPERATINGSYSTEM]}' -> '#{normalized_os}'"
          os_vers[OPERATINGSYSTEM] = normalized_os
        end
        next unless normalized_os == 'Windows'
        normalized_vers = os_vers[OPERATINGSYSTEMRELEASE].map { |v| normalize_win_version(v) }
        unless normalized_vers == os_vers[OPERATINGSYSTEMRELEASE]
          PdkSync::Logger.info "Corrected OS Versions: #{os_vers[OPERATINGSYSTEMRELEASE]} -> #{normalized_vers}"
          os_vers[OPERATINGSYSTEMRELEASE] = normalized_vers
        end
      end

      write_metadata_json(module_path, new_metadata_json)
    end

    # @summary
    #   Removes the OS version from the supported platforms
    #   TODO: Remove entire OS entry when version is nil
    #   TODO: Remove entire OS entry when versions is empty
    # @param module_path
    #   Path to the root dir of the module
    # @param os_to_remove
    #   OS we want to remove version from
    # @param version_to_remove
    #   Version from OS we want to remove
    def self.remove_platform_from_metadata(module_path, os_to_remove, version_to_remove)
      new_metadata_json = metadata_json(module_path)
      new_metadata_json[OPERATINGSYSTEM_SUPPORT].each do |os_vers|
        if (os = normalize_os(os_vers[OPERATINGSYSTEM]))
          next unless os.downcase == os_to_remove.downcase
          vers = os_vers[OPERATINGSYSTEMRELEASE]
          next unless (ver_index = vers.find_index(version_to_remove))
          PdkSync::Logger.info "Removing #{os} #{vers[ver_index]} from metadata.json"
          vers.delete_at(ver_index)
        else
          PdkSync::Logger.info 'No entry in metadata.json to replace'
          return true
        end
      end
      write_metadata_json(module_path, new_metadata_json)
    end

    # @summary
    #   Adds an OS version to the supported platforms. Creates a new OS entry if it does not exist
    # @param module_path
    #   Path to the root dir of the module
    # @param os_to_add
    #   OS we want to add
    # @param version_to_add
    #   Version we want to add
    def self.add_platform_to_metadata(module_path, os_to_add, version_to_add)
      os_to_add = normalize_os(os_to_add)
      new_metadata_json = metadata_json(module_path)
      updated_existing_entry = false
      new_metadata_json[OPERATINGSYSTEM_SUPPORT].each do |os_vers|
        next unless (os = normalize_os(os_vers[OPERATINGSYSTEM]))
        next unless os == os_to_add
        PdkSync::Logger.info "Adding #{os_to_add} version #{version_to_add} to existing entry"
        os_vers[OPERATINGSYSTEMRELEASE] << version_to_add
        os_vers[OPERATINGSYSTEMRELEASE].uniq!
        os_vers[OPERATINGSYSTEMRELEASE].sort_by!(&:to_f)
        updated_existing_entry = true
        break
      end
      unless updated_existing_entry
        PdkSync::Logger.info "Adding #{os_to_add} version #{version_to_add} to new entry"
        supported_platform_entry = {}
        supported_platform_entry[OPERATINGSYSTEM] = os_to_add
        supported_platform_entry[OPERATINGSYSTEMRELEASE] = [version_to_add]
        new_metadata_json[OPERATINGSYSTEM_SUPPORT] << supported_platform_entry
      end
      write_metadata_json(module_path, new_metadata_json)
    end

    NAME = 'name'.freeze
    REQUIREMENTS = 'requirements'.freeze

    # @summary
    #   Updates the requirements parameter in the metadata.json. If the requirement or  a key within it doesn't exist,
    #   it is created.
    #   TODO: Ability to remove requirement
    # @param module_path
    #   Path to the root dir of the module
    # @param name
    #   Name attribute of the requirement
    # @param key
    #   The key name of a K/V pair to be added / updated in the requirement
    # @param value
    #   The value of the key to be added / updated in the requirement
    def self.update_requirements(module_path, name, key, value)
      new_metadata_json = metadata_json(module_path)
      updated_existing_entry = false
      new_metadata_json[REQUIREMENTS].each do |requirement|
        next unless requirement[NAME] == name
        PdkSync::Logger.info "Updating [#{requirement['name']}] #{requirement.key? key ? "dependency's existing" : 'with a new'} key [#{key}] to value [#{value}]"
        requirement[key] = value
        updated_existing_entry = true
      end
      unless updated_existing_entry
        PdkSync::Logger.info "Adding new requirement [#{name}] with key [#{key}] of value [#{value}]"
        new_requirement = {}
        new_requirement[NAME] = name
        new_requirement[key] = value
        new_metadata_json[REQUIREMENTS] << new_requirement
      end
      write_metadata_json(module_path, new_metadata_json)
    end

    # @summary
    #   Generate an entry in the 'provision.yaml' for running release checks against the platforms that the given
    #   Puppet version. Will compare the supported platforms for the given Puppet version against the compatible
    #   platforms defined in the module's 'metadata.json' and generate a list of platforms that are the same.
    # @param [String] module_path
    #   Path to the module root dir
    # @param [String] puppet_version
    #   Puppet version we are generating platform checks for
    def self.generate_vmpooler_release_checks(module_path, puppet_version)
      PdkSync::Logger.info "Generating release checks provision.yaml key for Puppet version #{puppet_version}"
      # This YAML is where the compatible platforms for each Puppet version is stored
      agent_test_platforms_yaml_file_path = 'lib/pdksync/conf/puppet_abs_supported_platforms.yaml'
      agent_test_platforms = YAML.safe_load(File.read(agent_test_platforms_yaml_file_path))
      raise "No configuration for Puppet #{puppet_version} found in #{agent_test_platforms_yaml_file_path}" unless agent_test_platforms.key? puppet_version
      agent_test_platforms = agent_test_platforms[puppet_version]
      module_supported_platforms = module_supported_platforms(module_path)
      images = []
      PdkSync::Logger.debug 'Processing compatible platforms from metadata.json'
      module_supported_platforms.each do |os_vers|
        os = os_vers['operatingsystem'].downcase
        # 'Windows' and 'OracleLinux' are the definitions in 'metadata.json', however the VMPooler images are 'win' and 'oracle'
        os = 'win' if os == 'windows'
        os = 'oracle' if os == 'oraclelinux'
        vers = os_vers['operatingsystemrelease']
        if agent_test_platforms.keys.select { |k| k.start_with? os }.empty?
          PdkSync::Logger.warn "'#{os}' is a compatible platform but was not defined as test platform for Puppet #{puppet_version} in #{agent_test_platforms_yaml_file_path}"
          next
        end
        vers.each do |ver|
          PdkSync::Logger.debug "Checking '#{os} #{ver}'"
          if os == 'win'
            win_ver = normalize_win_version(ver)
            PdkSync::Logger.debug "Normalised Windows version: #{win_ver}"
            next unless agent_test_platforms['win'].include? win_ver
            PdkSync::Logger.debug "'#{os} #{ver}' SUPPORTED by Puppet #{puppet_version}"
            images << "win-#{win_ver}-x86_64"
          else
            next unless agent_test_platforms[os].include? ver
            PdkSync::Logger.debug "'#{os} #{ver}' SUPPORTED by Puppet #{puppet_version}"
            images << "#{os}-#{ver.delete('.')}-x86_64"
          end
        end
      end
      images.uniq!
      result = add_provision_list(module_path, "release_checks_#{puppet_version}", 'abs', images)
      PdkSync::Logger.warn "#{module_path}/provision.yaml does not exist" unless result
    end
  end
end
