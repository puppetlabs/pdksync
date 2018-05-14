# PdkSync

Table of Contents
-----------------

1. [Overview](#overview)
2. [Usage](#usage)
3. [How it works](#how-it-works)
4. [Installing](#installing)
5. [Workflow](#workflow)
6. [Contributing](#contributing)

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

Contributing
--------

1. Fork it
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request
