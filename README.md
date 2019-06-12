# Pdksync

Table of Contents
-----------------

1. [Overview](#overview)
2. [Usage](#usage)
3. [How it works](#how-it-works)
4. [Configuration](#configuration)
5. [Workflow](#workflow)
6. [Migrating from modulesync to pdksync](#migrating-from-modulesync-to-pdksync)
7. [Contributing](#contributing)

### Overview
--------

Pdksync is an efficient way to run a `pdk update` command against the various Puppet module repositories that you manage — keeping them up-to-date with the changes made to PDK. It is a solution for converted modules that no longer run with modulesync.

Pdksync by default expects that your Puppet module repositories live on GitHub and will behave accordingly. It also supports GitLab as an alternative Git hosting platform.

### Usage
----------

> Note: This tool creates a 'live' pull (merge) request against the master branch of the module it is running against — defined in `managed_modules.yml`. Before running this tool, ensure this file reflects the modules you wish it to run against. Additionally make sure that the Pdksync configuration file `$HOME/.pdksync.yml` sets the correct namespace, Git platform and Git base URI for your modules. See section [Configuration](#configuration) for details.

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

gem 'pdksync', github: 'puppetlabs/pdksync', ref: 'pdksync-externalisation-fixes'
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
git_base_uri: 'git@github.com:'
```


Run the following commands to check that everything is working as expected:

```shell
bundle install --path .bundle/gems/
bundle exec rake -T
bundle exec rake git:clone_managed_modules
```

The rake tasks take in a file, `managed_modules.yml`, stored within the local directory that lists all the repositories that need to be updated. It then clones them, one after another, so that a local copy exists. The `pdk update` command is ran against this local copy, with the subsequent changes being added into a commit on a unique branch. It is then pushed back to the remote master — where the local copy was originally cloned. A pull request against master is opened, and pdksync begins to clone the next repository.

By default, pdksync will supply a label to a PR (default is 'maintenance'). This can be changed by creating `pdksync.yml` in the local directory and setting the `pdksync_label` key. You must ensure that the label selected exists on the modules that you are applying pdksync to. Should you wish to disable this feature, set `pdksync_label` to an empty string i.e. `''`. Similarly, when supplying a label using the `git:push_and_create_pr` rake task, the label must exist on each of the managed modules to run successfully.

The following rake tasks are available with pdksync:
- `pdksync:show_config` Display the current configuration of pdksync
- `git:clone_managed_modules` Clone managed modules.
- `git:create_commit[:branch_name, :commit_message]` Stage commits for modules, branchname and commit message eg rake 'git:create_commit[flippity, commit messagez]'.
- `git:push_and_create_pr[:pr_title, :label]` Push commit, and create PR for modules. Label is optional eg rake 'git:push_and_create_pr[pr title goes here, optional label right here]'.
- `git:clean[:branch_name]` Clean up origin branches, (branches must include pdksync in their name) eg rake 'git:clean[pdksync_origin_branch]'.
- `pdksync:pdk_convert` Runs PDK convert against modules.
- `pdksync:pdk_validate` Runs PDK validate against modules.
- `pdksync[:additional_title]` Run full pdksync process, clone repository, pdk update, create pr. Additional information can be added to the title, which will be appended before the reference section.
  - `rake pdksync` PR title outputs as `pdksync - pdksync_heads/master-0-gabccfb1`
  - `rake 'pdksync[MODULES-8231]'` PR title outputs as `pdksync - MODULES-8231 - pdksync_heads/master-0-gabccfb1`
- `pdksync:run_a_command[:command]` Run a command against modules eg rake 'pdksync:run_a_command[complex command here -f -gx]'

### Configuration

By default pdksync will use hardcoded values for configuring itself. However, if you wish to override these values, create a `pdksync.yml` in your working directory and use the following format:
```yaml
---
namespace: 'puppetlabs'
pdksync_dir: 'modules_pdksync'
push_file_destination: 'origin'
create_pr_against: 'master'
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

To use GitHub you only need to export your GitHub access token as the
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
`git_base_uri` and `gitlab_api_endpoint` in `$HOME/.pdksync.yml` so that
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
gitlab_api_endpoint: 'https://gitlab.example.com/api/v4'
```

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
