# Pdksync

[![Code Owners](https://img.shields.io/badge/owners-DevX--team-blue)](https://github.com/puppetlabs/pdksync/blob/main/CODEOWNERS)]
![ci](https://github.com/puppetlabs/pdksync/actions/workflows/ci.yml/badge.svg)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/puppetlabs/pdksync)

Table of Contents
-----------------

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Usage](#usage)
4. [How it works](#how-it-works)
5. [Configuration](#configuration)
6. [Workflow](#workflow)
7. [Migrating from modulesync to pdksync](#migrating-from-modulesync-to-pdksync)
8. [Contributing](#contributing)

### Overview
--------

Pdksync is an efficient way to run a `pdk update` command against the various Puppet module repositories that you manage — keeping them up-to-date with the changes made to PDK. It is a solution for converted modules that no longer run with modulesync.

Pdksync by default expects that your Puppet module repositories live on GitHub and will behave accordingly. It also supports GitLab as an alternative Git hosting platform.

### Requirements
--------
* Ruby >= 2.7
* Bundler >= 1.15

### Usage
----------

> Note: This tool creates a 'live' pull (merge) request against the main branch of the module it is running against — defined in `managed_modules.yml`. Before running this tool, ensure this file reflects the modules you wish it to run against. Additionally make sure that the Pdksync configuration file `$HOME/.pdksync.yml` sets the correct namespace, Git platform and Git base URI for your modules. See section [Configuration](#configuration) for details.

1. To use pdksync, clone the GitHub repo or install it as a gem. Set up the environment by exporting a GitHub token:

   ```shell
   export GITHUB_TOKEN=<access_token>
   ```

   If you use GitLab instead of GitHub export your GitLab access token:

   ```shell
   export GITLAB_TOKEN=<access_token>
   ```
2. Before the script will run, you need to install the gems:
```shell
bundle install --path .bundle/gems/
```
3. Once this is complete, call the built-in rake task to run the module:
```shell
bundle exec rake pdksync
```

### Github Token Permissions
----------

Follow the steps below to set up a Github token with the minimum level of permissions required by `pdksync`:

- Log in to your Github account and navigate to the [Personal Access Tokens](https://github.com/settings/tokens) section under `Settings -> Developer settings`
- Click [`Generate new token`](https://github.com/settings/tokens/new)
- Select the check boxes appropriate for your use case below

#### **Public Repos, No Workflow Modifications Permitted**

- [ ] **repo**
  - [ ] repo:status
  - [ ] repo_deployment
  - [x] public_repo
  - [ ] repo:invite
  - [ ] security_events
- [ ] workflow  

#### **Private Repos or Public Repos with Workflow Modifications Permitted**

- [x] **repo**
  - [x] repo:status
  - [x] repo_deployment
  - [x] public_repo
  - [x] repo:invite
  - [x] security_events
- [x] workflow  

### How it works
------------

Pdksync is a gem that works to clone, update, and push module repositories. Create a new git repository to store your working config. You need the following files in there:

Rakefile:
```ruby
require 'pdksync/rake_tasks'
```

Gemfile:
```ruby
# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'pdksync'
gem 'rake'
```

managed_modules.yml:
```yaml
---
- repo1
- repo2
- repo3
- repo4
```

pdksync.yml:
```yaml
---
namespace: 'YOUR GITHUB NAME'
git_base_uri: 'git@github.com'
```


Run the following commands to check that everything is working as expected:

```shell
bundle install --path .bundle/gems/
bundle exec rake git:clone_managed_modules
```

pdksync tool is extended with the feature to update the Gemfile. Puppet provides a lot of useful gems to access and manage their functionality between modules. This functionality will help user to perform gem testing prior to release. User is given new rake tasks to update SHA/Version/Branch/line in the Gemfile. Then the changes can be committed, PR can be created which will run the acceptance tests in the PR. If all the tests are executing successfully then the user can close the PRS and release the gem. Below given are the workflows for doing module gem testing with pdksync.


In Workflow 1 we can clone modules, update the gem file, create the commit, push the changes and create the PR using separate rake tasks.
```shell
bundle install --path .bundle/gems/
bundle exec rake git:clone_managed_modules
bundle exec rake 'pdksync:gem_file_update[]'
bundle exec rake 'git:create_commit[]'
bundle exec rake 'git:push'
bundle exec rake 'git:create_pr[]'
```

In Workflow 2 we can clone modules, update the gem file, create the commit, push the changes and create the PR using single rake task
```
Using single rake job
bundle install --path .bundle/gems/
bundle exec rake 'gem_testing[]'
```

In Workflow 3 we can clone modules, update the gem file, run the tests locally for litmus modules without creating commit,pushing or creating the PR
```
Using single rake job
bundle install --path .bundle/gems/
bundle exec rake git:clone_managed_modules
bundle exec rake 'pdksync:gem_file_update[]'
bundle exec rake 'pdksync:run_tests_locally[]'
bundle exec rake 'pdksync:fetch_test_results_locally[]'
```

Once the verified gem is released we can use pdksync to update the the new version of gem released in the  .sync.yaml file.

pdksync tool is extended with the feature to perform multi gem testing (`puppet-module-gems`). This functionality will identify the current version and bump the version by one. Then it will build and push the gems to gemfury account. Export the GEMFURY_TOKEN to use this rake task.

 ```shell
   export GEMFURY_TOKEN=<access_token>
   ```

Run the following commands to check that everything is working as expected:

```shell
bundle install --path .bundle/gems/
bundle exec rake -D
bundle exec rake 'git:clone_gem['gem_name']'
```
Below given are the workflows for doing multi gem testing with pdksync.

In this workflow we can clone gems, update the version, build the gem, push the changes to gemfury and update the gem file of the required modules with the latest gem updated in the fury. Then we can create PR or run tests locally or run tests through jenkins to verify the module test results.

```shell
bundle install --path .bundle/gems/
bundle exec rake 'git:clone_gem[]'
bundle exec rake 'pdksync:multi_gem_testing[]'
bundle exec rake 'pdksync:multigem_file_update[]'
```

The rake tasks take in a file, `managed_modules.yml`, stored within the local directory that lists all the repositories that need to be updated. It then clones them, one after another, so that a local copy exists. The `pdk update` command is ran against this local copy, with the subsequent changes being added into a commit on a unique branch. It is then pushed back to the remote origin — where the local copy was originally cloned. A pull request against main is opened, and pdksync begins to clone the next repository.

By default, pdksync will supply a label to a PR (default is 'maintenance'). This can be changed by creating `pdksync.yml` in the local directory and setting the `pdksync_label` key. You must ensure that the label selected exists on the modules that you are applying pdksync to. Should you wish to disable this feature, set `pdksync_label` to an empty string i.e. `''`. Similarly, when supplying a label using the `git:create_pr` rake task, the label must exist on each of the managed modules to run successfully.

The following rake tasks are available with pdksync:
- `pdksync:show_config` Display the current configuration of pdksync
- `git:clone_managed_modules` Clone managed modules.
- `git:create_commit[:branch_name, :commit_message]` Stage commits for modules, branchname and commit message eg rake 'git:create_commit[flippity, commit messagez]'.
- `git:push` Push staged commits eg rake 'git:push'.
- `git:create_pr[:pr_title, :label]` Create PR for modules. Label is optional eg rake 'git:create_pr[pr title goes here, optional label right here]'.
- `git:clean[:branch_name]` Clean up origin branches, (branches must include pdksync in their name) eg rake 'git:clean[pdksync_origin_branch]'.
- `pdksync:pdk_convert` Runs PDK convert against modules.
- `pdksync:pdk_validate` Runs PDK validate against modules.
- `pdksync[:additional_title]` Run full pdksync process, clone repository, pdk update, create pr. Additional information can be added to the title, which will be appended before the reference section.
  - `rake pdksync` PR title outputs as `pdksync - pdksync_heads/main-0-gabccfb1`
  - `rake 'pdksync[MODULES-8231]'` PR title outputs as `pdksync - MODULES-8231 - pdksync_heads/main-0-gabccfb1`
- `pdksync:run_a_command[:command, :option]` Run a command against modules eg rake 'pdksync:run_a_command[complex command here -f -gx, 'background']'. :option is an optional parameter which states to run command in backgroud.
- `pdksync:gem_file_update[[:gem_to_test, :gem_line, :gem_sha_finder, :gem_sha_replacer, :gem_version_finder, :gem_version_replacer, :gem_branch_finder, :gem_branch_replacer]]` Run gem_file_update against modules
  - eg rake to update gem line `pdksync:gem_file_update['puppet_litmus', "gem 'puppet_litmus'\, git: 'https://github.com/test/puppet_litmus.git'\, branch: 'testbranch'"]'`
  - eg rake to update sha `pdksync:gem_file_update['puppet_litmus', '', '20ee04ba1234e9e83eb2ffb5056e23d641c7a018', '20ee04ba1234e9e83eb2ffb5056e23d641c7a31']`
  - eg rake to update version`pdksync:gem_file_update['puppet_litmus', '', '', '', "= 0.9.0", "<= 0.10.0", '', '']`
  - eg rake to update branch `pdksync:gem_file_update['puppet_litmus', '', '', '', '', '', 'testbranch', 'testbranches']`
- `rake 'gem_testing[:additional_title, :gem_to_test, :gem_line, :gem_sha_finder, :gem_sha_replacer, :gem_version_finder, :gem_version_replacer, :gem_branch_finder, :gem_branch_replacer]'` Run complete Gem file testing (cloning, gemfileupdate, create commit, create PR)PR title outputs as `pdksync_gemtesting - MODULES-8231 - pdksync_heads/main-0-gabccfb1`
  - eg rake to perform gem file testing `gem_testing['MODULES-testing', 'puppet_litmus', '', '20ee04ba1234e9e83eb2ffb5056e23d641c7a018', 'testsha']`
- `pdksync:run_tests_locally[:provision_type, :puppet_collection]` Run litmus modules locally
  - eg rake 'pdksync:run_tests_locally["default"]'
- `pdksync:fetch_test_results_locally[]` Fetch litmus modules local run results
  - eg rake 'pdksync:fetch_test_results_locally[]'
- `pdksync:run_tests_jenkins[:jenkins_server_url, :github_branch, :test_framework, :github_user]` Run traditional modules on jenkins. For now this rake task works just for test_framework: jenkins.
  - eg rake 'pdksync:run_tests_jenkins[test_branch, '', test_user]'
- `pdksync:test_results_jenkins[]` Fetch traditional modules jenkins run results
  - eg rake 'pdksync:test_results_jenkins[jenkins_server_url]'
- `git:clone_gem[:gem_name]` Clone gem.
- `pdksync:multi_gem_testing[:gem_name, :version_file, :build_gem, :gem_path, :gemfury_username]` Build and Push new gems built to the gemfury account for testing eg rake 'pdksync:multi_gem_testing[]'
- `pdksync:multigem_file_update[:gem_name, :gemfury_username]` Update Gemfile of the modules with the new gem should be pushed to Gemfury.'
- `pdksync:add_provision_list[:key, :provisioner, :images]` Add a provision list key to provision.yaml.
- `pdksync:generate_vmpooler_release_checks[:puppet_version]` Generates release checks in provision.yaml based on module compatible platforms and puppet version
- `pdksync:add_platform_to_metadata[:os, :version]` Add a given OS Version to the metadata
- `pdksync:remove_platform_from_metadata[:os, :version]` Remove a given OS Version from the metadata


You can run ```bundle exec rake -D``` to view the list of available rake tasks.

### Adding/Updating `provision.yaml`
To add/update an entry in the `provision.yaml`, run the following task:
```ruby
bundle exec rake pdksync:add_provision_list[:key, :provisioner, :images]
```
The `:images` parameter is a variable in length - everything from the 3rd arg onwards, separated by commas, will be treated as an image.
For example:
```ruby
bundle exec rake "pdksync:add_provision_list[release_checks_latest_os, abs, 'redhat-8-x86_64', 'centos-8-x86_64', 'debian-10-x86_64', 'sles-15-x86_64', 'ubuntu-2004-x86_64', 'win-2019-core-x86_64', 'win-10-pro-x86_64']"
```
This will create a new entry (or update an existing entry, if it already exists) in the `provision.yaml`:
```yaml
release_checks_latest_os:
    provisioner: abs
    images:
    - redhat-8-x86_64
    - centos-8-x86_64
    - debian-10-x86_64
    - sles-15-x86_64
    - ubuntu-2004-x86_64
    - win-2019-core-x86_64
    - win-10-pro-x86_64
```

### Generating Release Checks Config in `provision.yaml` for Given Puppet Version
To generate a release checks configuration that will use VMPooler (via the ABS provisioner) in the `provision.yaml` that satisfies both:
- The supported platforms of the given Puppet version
- The supported platforms of the module

...you can run:
```ruby
pdksync:generate_vmpooler_release_checks[:puppet_version]
```

#### Step 1: Create Puppet version supported platform config entry
Ensure that the there is an entry in the `lib/pdksync/conf/puppet_abs_support_platforms.yaml` config for the Puppet version you wish to add an entry for:
```yaml
7:
  centos: ['7', '8']
  debian: ['9', '10']
  oracle: ['7']
  redhat: ['7', '8']
  sles: ['12', '15']
  scientific: ['7']
  ubuntu: ['18.04', '20.04']
  win: ['2012r2', '2016-core', '2019-core', '10']
```
**NOTE: Please be aware of the requirements regarding the platform naming and version syntax. Instructions and an explanation are within the `puppet_support_platforms.yaml`**

The platforms specified above do not necessarily have to reflect ALL the platforms that Puppet version supports - this is the configuration we wish to test against.
If you do not wish to test against `solaris` then simply omit it from the above config.

#### Step 2: Add the config entries to `provision.yaml`
Say you want to add a configuration key for Puppet 7 (_and you have ensured the `puppet_support_platforms.yaml` is correct as defined in the step above_), you would run:
```ruby
bundle exec rake 'pdksync:generate_vmpooler_release_checks[7]'
```
This will create a `release_checks_7` entry in the `provision.yaml` of the managed modules cloned down that contains a list of appropriate number of platforms to satisfy the conditions outlined above.

### Adding a new platform to `metadata.json`

To add a new OS or OS version to the `operatingsystem_support` key in the `metadata.json`:

```ruby
bundle exec rake 'pdksync:add_platform_to_metadata[:os, :version]'
```

For example, to add a new OS called 'FooBar OS' and versions `1`, `2` and `3`:

```ruby
bundle exec rake 'pdksync:add_platform_to_metadata[FooBar,1]'
bundle exec rake 'pdksync:add_platform_to_metadata[FooBar,2]'
bundle exec rake 'pdksync:add_platform_to_metadata[FooBar,3]'
```

To add a new version (e.g. `22.04`) to an existing entry (e.g. `Ubuntu`):

```ruby
bundle exec rake 'pdksync:add_platform_to_metadata[Ubuntu,22.04]'
```

**PLEASE NOTE: All OS names are normalised to the conventions defined in the `normalize_os` method - see below for more details.**

### Removing a platform from `metadata.json`

To remove a platform version from `metadata.json`:

```ruby
bundle exec rake 'pdksync:remove_platform_from_metadata[:os, :version]'
```

**PLEASE NOTE: There is currently a limitation on removing an entire OS if no versions are specified - feel free to enhance with a PR :)**

For example, to remove version `14.04` from `Ubuntu`:

```ruby
bundle exec rake 'pdksync:remove_platform_from_metadata[Ubuntu,14.04]'
```

### Update requirements

To add / modify a requirement from the `requirements` key of the `metadata.json`:

```ruby
bundle exec rake 'pdksync:update_requirements[:name, :key, :value]'
```

**PLEASE NOTE: There is currently a limitation on removing an entire requirement entry - feel free to enhance with a PR :)**

To update the `puppet` `version_requirement` requirement to `>= 6.0.0 < 8.0.0`:

```ruby
bundle exec rake 'pdksync:update_requirements[puppet,version_requirement,>= 6.0.0 < 8.0.0]'
```

To add a new requirement called `foobar` with a parameter called `baz` which has a value of `123`:

```ruby
bundle exec rake 'pdksync:update_requirements[foobar,baz,123]'
```

### Normalize Supported Platforms

To normalize the platforms and versions (Windows only) defined in the `operatingsystem_support` key of the `metadata.json` based on [these rules](https://github.com/puppetlabs/pdksync/blob/ebb84d81d2c15115f896995043eac6d666a114a0/lib/pdksync/utils.rb#L1043-L1098):

```ruby
bundle exec rake 'pdksync:normalize_metadata_supported_platforms'
```

### Configuration

By default pdksync will use hardcoded values for configuring itself. However, if you wish to override these values, create a `pdksync.yml` in your working directory and use the following format:
```yaml
---
namespace: 'puppetlabs'
pdksync_dir: 'modules_pdksync'
pdksync_gem_dir: 'gems_pdksync',
push_file_destination: 'origin'
create_pr_against: 'main'
managed_modules: 'managed_modules.yml'
pdksync_label: 'maintenance'
git_platform: :github
git_base_uri: 'https://github.com'
# Only used when git_platform is set to :gitlab
gitlab_api_endpoint: 'https://gitlab.com/api/v4'
```

You may override any property. Those that are not specified in your config file will use their corresponding default value from `lib/pdksync/constants.rb`.

#### Git platform support

By default pdksync assumes you are hosting your Puppet modules on GitHub, and GitHub is the only platform officially supported by Puppetlabs in pdksync.

Pdksync also supports the GitLab platform, but without official support by Puppetlabs.

##### GitHub
Github.com and Github enterprise both work with octokit which is used in pdksync.  There are some settings
you will need to adjust if using the on premise github enterprise edition.

1. `api_endpoint: https://mygithub.mycompany.com/api/v3`
2. `git_base_uri: git@mygithub.mycompany.com`
3. `export GITHUB_TOKEN=k3939isdiasdf93i_`  (your token goes here)

To use GitHub.com you only need to export your GitHub access token as the
environment variable `GITHUB_TOKEN` and configure the namespace in which your
modules are hosted in `$HOME/.pdksync.yml` as described above.

##### GitLab

To use GitLab at `https://gitlab.com` you need to set `git_platform: :gitlab`
and configure the namespace of your modules in `$HOME/.pdksync.yml`. You also
need to export your GitLab access token as the environment variable
`GITLAB_TOKEN`.

Your `$HOME/.pdksync.yml` then looks like this:

```yaml
# ~/pdksync.yml
---
namespace: 'acme'
git_platform: :gitlab
```

Export your GitLab access token:

```shell
export GITLAB_TOKEN=<your GitLab access token here>
```

If you are running your own GitLab instance on premise or use a GitLab instance
other than the official one at `https://gitlab.com` you also need to configure
`git_base_uri` and `api_endpoint` in `$HOME/.pdksync.yml` so that
pdksync knows from where to clone your modules and where to access to GitLab
API to create the live merge requests:

```yaml
# ~/pdksync.yml
---
namespace: 'puppetmodules'
git_platform: :gitlab
git_base_uri: 'https://gitlab.example.com'
# alternatively use SSH:
#git_base_uri: 'ssh://git@gitlab.example.com:2222'
api_endpoint: 'https://gitlab.example.com/api/v4'
```

### Setting who has the authoritive
It may be desirable to allow modules to dictate which version of the pdk-templates they should sync with.
There are a few settings you can tune to allow for this kind of flexability.  These settings are in the pdksync.yml file.  All of these settings are optional and have sane defaults.  See `rake pdksync:show_config` for the settings that will be used.

- pdk_templates_prefix: 'nwops-'  (example only, keep as empty string)
- pdk_templates_ref: 1.12.0
- pdk_templates_url: https://github.com/puppetlabs/pdk-templates.git
- module_is_authoritive: true

The first setting is `module_is_authoritive`.  When this is set to true the templates and ref specified in the metadata become the authoritive source for these settings.  Even if you have pdk_templates_ref and pdk_templates_url specified in pdksync.yml the metadata settings will alwasys be used.

```json
# module/metadata.json
{
"pdk-version": "1.11.1",
"template-url": "https://github.com/puppetlabs/pdk-templates#main",
"template-ref": "heads/main-0-gb096033"
}

```

When `module_is_authoritive` is set to false the pdk_templates_ref and pdk_templates_url will override what is found in the modules's metadata.json file.  This is very useful when you have to control pdk-template upgrades on modules.

The other settings dictiate where the templates are located and which branch, tag or reference you want to use.
`pdk_templates_ref: 'main'` and `pdk_templates_url: https://github.com/puppetlabs/pdk-templates.git`.  These settings will only be utilized if module_is_authoritive is set to false.  However, if you are performing a conversion via pdksync these settings will also be used since the metadata in the module being converted doesn't have pdk settings yet.

The last setting `pdk_templates_prefix` is a special use case that allows folks with internal forks of pdk-templates to keep branches of the pdk-template tags with additional custom changes. Setting this to an empty string disables this.  You will most likely need to resolve conflicts with this workflow, so it is not for everyone.  If you know of a better way please submmit a pull request.

This strategy works in conjunction with the pdk-template git tags and the workflow looks like:
  1. git fetch upstream (github.com/puppetlabs/pdk-templates)
  2. git checkout main && git rebase upstream/main
  3. git checkout -b nwops-1.0.13 nwops-1.0.12
  4. git rebase 1.0.13
  5. git push origin nwops-1.0.13


### Supporting multiple namespaces
If you have multiple namespaces that you need to support you will need to create a pdksync.yml config
file for each namespace.  This will allow you to create a folder structure and keep a separate
managed_modules.yml for that namespace too.

You can set a PDKSYNC_CONFIG_PATH environment variable that points to the specific pdksync.yml config file for use in a CI or on the CLI. This allows you to set custom names for pdksync.yml file.

example: `PDKSYNC_CONFIG_PATH=pdksync_ops.yml`

Or you can set a different HOME environment variable that tells pdksync where to find the pdksync.yml file.  Pdksync will locate the pdksync.yml file in the HOME folder you specify.  The config file name is not changable in this case.

example: `HOME=ops`

### Logging output
Pdksync uses a logger class to log all output.  You can control how the logger works via a few environment variables.

To control the level set the `LOG_LEVEL` to one of
1. info
2. debug
3. fatal
4. error
5. warn

To control where the logs are sent (defaults to stdout) set the `PDKSYNC_LOG_FILENAME` to a file path.

### Workflow
--------

It currently runs without additional arguments. To alter how it runs, make alterations to either `HOME/.pdksync.yml` or `managed_modules.yml`.

### Managed modules
----------

This module runs through a pre-set array of modules, with this array set within the `managed_modules.yml` file. This file makes use of a simple `yaml` style format to set out the different module names, for example:

```yaml
---
- puppetlabs-motd
- puppetlabs-stdlib
- puppetlabs-mysql
```

To add a module, add it to the list. To remove a module, remove it from the list. If you wish to specify a custom managed modules file, use the `managed_modules` property in your configuration file to specify the path to the file.

### Migrating from modulesync to pdksync
--------

If your modules are currently managed by modulesync, and you want to use PDK and keep your modules up-to-date, read the following.

#### Terminology
- `pdk convert` - A command to convert your module, for example, to make it compatible with the PDK.
- `convert_report.txt` - A report that shows the changes PDK will make to your module when `pdk convert` is ran.
- `pdk update` - A command to consume any changes that have been made to the pdk-template used to convert the module.
- `update_report.txt` - A report that shows the changes PDK will make to your module when `pdk update` is ran.
- `pdk validate` - A command to run basic validation checks on your module.
- `pdk test unit` - A command to run all available unit tests on your module.
- `.sync.yml` - A file that lists all of of your module customizations — and will require  work before module conversion.

##### Prerequisites
* Unit tests are in a good state — with no failures. Check by running `pdk test unit`.
* The module is in good shape. Check by running `pdk validate`.

When you're confident everything is in good shape, you can start converting your module to make it compatible with PDK.

##### Getting started

1) Run `pdk convert --noop`. This will output to the console a high level overview of the changes that PDK is planning to make to your files.

> Note: For an in-depth diff, see the convert_report.txt that is output in the module root directory.

2) Make changes to your .sync.yml. State any configuration that the custom [pdk-templates](https://github.com/puppetlabs/pdk-templates) plan to remove.

Useful commands via the .sync.yml:

- Add additional gem dependencies:
```yaml
Gemfile:
  required:
    ':system_tests':
      - gem 'octokit'
        platforms: ruby
```
- Make changes to your travis configuration:
```yaml
.travis.yml:
  branches:
    - release
```
- Delete files that you don't want to exist in the repo:
```yaml
.gitlab-ci.yml:
  delete: true
```
- Unmanage files that you don't want to be managed:
```yaml
.gitlab-ci.yml:
  unmanaged: true
```
> Note: It is unlikely your module will work out of the box.

3) When you are finished customizing your .sync.yml file, run `pdk convert --noop` and confirm the changes that PDK will make when you convert. Changes can be found in the `convert_report.txt`

4) Run `pdk convert` to convert. You will be prompted to pass in Y/N — type Y and all your changes will be applied.

> Note: If you have any concerns it is not too late — type N.

5) Run your unit tests to confirm that nothing has broken. If there are breakages, you might need to require a library or include a missing gem — address this issue before you continue.

6) Run `pdk validate` to ensure there are no failures.

7) Commit the changes that the `pdk convert` has made and create your pull request.

8) Remove your module from being managed via `modulesync`, and start using `pdksync` going forward — no more manually creating pull requests.

For more information on keeping your module up to date with the PDK check out [Helens blog post](https://puppet.com/blog/guide-converting-module-pdk).

### Compatibility
----------

This tool has been developed and tested on OSX and Linux. **It currently does not run on Windows.**

### Contributing
--------

1. Fork the repo
2. Create your feature branch:
```shell
git checkout -b my-new-feature
```
3. Commit your changes:
```shell
git commit -am 'Add some feature'
```
4. Push to the branch:
```shell
git push origin my-new-feature
```
5. Create a new pull request
