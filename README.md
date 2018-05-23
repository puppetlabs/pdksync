# Pdksync

Table of Contents
-----------------

1. [Overview](#overview)
2. [Usage](#usage)
3. [How it works](#how-it-works)
4. [Installing](#installing)
5. [Workflow](#workflow)
6. [Migrating from modulesync to pdksync](#migrating-from-modulesync-to-pdksync)
7. [Contributing](#contributing)

### Overview
--------

Pdksync is an efficient way to run a `pdk update` command against the various repositories that we manage — keeping them up-to-date with the changes made to PDK. It is a solution for converted modules that no longer run with modulesync.

### Usage
----------

> Note: This tool creates a 'live' pull request against the master branch of the module it is running against — defined in `managed_modules.yml`. Before running this tool, ensure this file  reflects the modules you wish it to run against, and that `constants.rb` is up-to-date with the correct namespace your modules reside in.

1. To use pdksync, clone the GitHub repo or install it as a gem. Set up the environment by exporting a GitHub token:
```
export GITHUB_TOKEN=<access_token>
```
2. Before the script will run, you need to install the gems:
```
bundle install --path .bundle/gems/
```
3. Once this is complete, call the built-in rake task to run the module:
```
bundle exec rake pdksync
```

### How it works
------------

Pdksync is a gem that works to clone, update, and push module repositories. It is activated from within the pdksync module.

The gem takes in a file, `managed_modules.yml`, stored within the gem that lists all the repositories that need to be updated. It then clones them, one after another, so that a local copy exists. The update command is ran against this local copy, with the subsequent changes being added into a commit on a unique branch. It is then pushed back to the remote master — where the local copy was originally cloned. The commit is merged to the master via a pull request, causing the gem to begin to clone the next repository.

### Workflow
--------

It currently runs without additional arguments. To alter how it runs, make alterations to either the `constants.rb` or `managed_modules.yml`.

### Managed modules
----------

This module runs through a pre-set array of modules, with this array set within the `managed_modules.yml` file. This file makes use of a simple `yaml` style format to set out the different module names, for example:

```
---
- puppetlabs-motd
- puppetlabs-stdlib
- puppetlabs-mysql
```
To add a module, add it to the list. To remove a module, remove it from the list.

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
```
Gemfile:
  required:
    ':system_tests':
      - gem 'octokit'
        platforms: ruby
```
- Make changes to your travis configuration:
```
.travis.yml:
  branches:
    - release
```
- Delete files that you don't want to exist in the repo:
```
.gitlab-ci.yml:
  delete: true
```
- Unmanage files that you don't want to be managed:
```
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
```
git checkout -b my-new-feature
```
3. Commit your changes:
```
git commit -am 'Add some feature'
```
4. Push to the branch:
```
git push origin my-new-feature
```
5. Create a new pull request
