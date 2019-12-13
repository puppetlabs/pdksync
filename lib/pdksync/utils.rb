# @summary provides a module with various methods for performing the desired tasks
require 'git'
require 'open3'
require 'fileutils'
require 'pdk'
require 'pdksync/configuration'
require 'pdksync/gitplatformclient'
require 'colorize'
require 'bundler'
require 'octokit'
require 'pdk/util/template_uri'
require 'pdksync/logger'

module PdkSync
  module Utils
    def self.configuration
      @configuration ||= PdkSync::Configuration.new
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
    #   This method when called will create a pr on the given repository that will create a pr to merge the given commit into the master with the pdk version as an identifier.
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
    def self.run_command(output_path, command)
      stdout = ''
      stderr = ''
      status = Process::Status

      Dir.chdir(output_path) unless Dir.pwd == output_path

      # Environment cleanup required due to Ruby subshells using current Bundler environment
      if command =~ %r{^bundle}
        Bundler.with_clean_env do
          stdout, stderr, status = Open3.capture3(command)
        end
      else
        stdout, stderr, status = Open3.capture3(command)
      end

      PdkSync::Logger.info "\n#{stdout}\n"
      PdkSync::Logger.fatal "Unable to run command '#{command}': #{stderr}" unless status.exitstatus.zero?
      status.exitstatus
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
    #   This method when called will create and return an octokit client with access to the upstream git repositories.
    # @return [PdkSync::GitPlatformClient] client
    #   The Git platform client that has been created.
    def self.setup_client
      PdkSync::GitPlatformClient.new(configuration.git_platform, configuration.git_platform_access_settings)
    rescue StandardError => error
      raise "Git platform access not set up correctly: #{error}"
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
  end
end
