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

Pdksync was first created in order to allow for a more efficient method of running a `pdk update` command against the various repositories that we manage, keeping them up to date with the changes made to the `pdk`.

Usage
----------

To use pdksync you must first either clone the github repo or install it as a gem. You must then set up the environment by exporting a github token, as shown below:
```
export GITHUB_TOKEN=<access_token>
```
Once this is done you may then call the built in rake task to run the module.
```
bundle exec rake pdksync
```

How It Works
------------

Pdksync is a gem that works to clone, update and push module repositories. It currently expects to be activated from within the pdksync module itself.

The gem first takes in a file, `managed_modules.yml`, stored within the gem that list's out all of the repositories that need to be updated and then proceeds to, one after another, clone them down so that a local copy exists. This local copy then has the update command ran against it, the subsequent changes being promptly added into a commit, with it's own unique branch, that is then pushed back to the remote master from which the local copy was originally cloned. A pull request is then made to merge the commit to the master branch, thus finishing the process for this repo and causing the gem to begin to clone the next repository.

Installing
----------

Currently this is run as a rake task so it must be either cloned down locally or installed as a gem. If cloned down you must also run a local command in order to install it's gems:
```
bundle install --path .bundle/gems/
```

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
