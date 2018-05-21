# PdkSync

Table of Contents
-----------------

1. [Overview](#overview)
2. [Usage](#usage)
3. [How it works](#how-it-works)
4. [Installing](#installing)
5. [Workflow](#workflow)
6. [Migrating from modulesync to pdksync](#migrating-from-modulesync-to-pdksync)
7. [Contributing](#contributing)

Overview
--------

Pdksync was first created in order to allow for a more efficient method of running a `pdk update` command against the various repositories that we manage, keeping them up to date with the changes made to the `pdk`. Made as a solution for converted modules that can no longer run with modulesync.

Usage
----------

*Please Note:* This tool creates a 'live' pull request against the master branch of the module it's running against (which are defined in `managed_modules.yml`). If you wish to run this tool ensure this file properly reflects the modules you wish to run against before doing so. Also ensure `constants.rb` is up to date with the correct namespace your modules reside in.

To use pdksync you must first either clone the github repo or install it as a gem. You must then set up the environment by exporting a github token, as shown below:
```
export GITHUB_TOKEN=<access_token>
```
You also need to install the gems before the script will run, try using:
```
bundle install --path .bundle/gems/
```
Once this is done you may then call the built in rake task to run the module.
```
bundle exec rake pdksync
```

How It Works
------------

Pdksync is a gem that works to clone, update and push module repositories. It currently expects to be activated from within the pdksync module itself.

The gem first takes in a file, `managed_modules.yml`, stored within the gem that list's out all of the repositories that need to be updated and then proceeds to, one after another, clone them down so that a local copy exists. This local copy then has the update command ran against it, the subsequent changes being promptly added into a commit, with it's own unique branch, that is then pushed back to the remote master from which the local copy was originally cloned. A pull request is then made to merge the commit to the master branch, thus finishing the process for this repo and causing the gem to begin to clone the next repository.

Workflow
--------

As it stands it currently runs with no additional arguments and if you wish to alter how it runs you must make alterations to either the `constants.rb` or `managed_modules.yml`.

### Managed Modules

This module as it currently works, runs through a preset array of modules, this array being set within the `managed_modules.yml` file. This file makes use of a simple `yaml` style format in order to set out the different module names, the format is shown below:

```
---
- puppetlabs-motd
- puppetlabs-stdlib
- puppetlabs-mysql
```
In order to add a module you must simply add it to the list, and remove it from the list to accomplish the opposite.

### Migrating from modulesync to pdksync
--------
If your modules are currently managed by modulesync and you are interested in using the `pdk` and also keep your modules up to date then this is the section that you will be interested in!

#### Terminology:
- `pdk convert` - A command provided by the pdk to convert your module eg. make it compatible with the pdk.
- `convert_report.txt` - This is a report that will show the changes that the pdk will make to your module when `pdk convert` is ran.
- `pdk update` - A command provided by the pdk to consume any changes that have been made to the pdk-template used to convert the module.
- `update_report.txt` - This is a report that will show changes that the pdk will make to your module when `pdk update` is ran.
- `pdk validate` - A command provided by the `pdk` to run basic validation checks on your module.
- `pdk test unit` - A command provided by the `pdk` to run all available unit tests on your module.
- `.sync.yml` - All of your module customizations will be listed in this file and will require some work in preparation for a module conversion.

##### Prerequisites
* Unit tests are in a good state with no failures, you can check this by running: `pdk test unit`.
* The module in general is in good shape, you can check this by running: `pdk validate`.

When your confident everything is looking in tip top shape it is time to start converting your module to make it compatible with the pdk.

##### Getting Started

1) Run `pdk convert --noop`. This will output to the console a highlevel overview on the changes that the pdk is planning to make to your files.

**Note:** You can then inspect the convert_report.txt that is output in the moduleroot directory for an in-depth diff.

2) Time to make changes to your .sync.yml. In here you should state any configuration that the custom [pdk-templates](https://github.com/puppetlabs/pdk-templates) plan to remove.

Handy actions that you can do via the .sync.yml:

- Add additional gem dependencies
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
**Note:** It is unlikely your module will work out of the box, but if it does thats great!

3) When you are finished customizing your .sync.yml file it is important to run `pdk convert --noop` and confirm you are happy with the changes that the pdk will make when you go ahead to convert. Changes can be found in the `convert_report.txt`

4) Now it is time to run the actual convert! Run `pdk convert`, you will be prompted to pass in Y/N, type Y and all your changes will be applied.

**Note:** If you have any concerns its still not too late! You can choose to type N.

5) Run your unit tests to confirm nothing has broken, if there are breakages, chances are you need to require a library or include a missing gem. If so address this issue before you continue.

6) Run `pdk validate` to ensure nothing is out of the ordinary and there are no failures.

7) Commit the changes that the `pdk convert` has made and create your PR.

8) Remove your module from being managed via `modulesync` and you can start making use of `pdksync` going forward! Yay no more manual PR creation.

### Contributing
--------

1. Fork it
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
