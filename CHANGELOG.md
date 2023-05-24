<!-- markdownlint-disable MD024 -->
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org).

## [v0.6.1](https://github.com/puppetlabs/pdksync/tree/v0.6.1) - 2023-05-24

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/v0.6.0...v0.6.1)

### Added

- (maint) Add Support for AlmaLinux and Rocky [#165](https://github.com/puppetlabs/pdksync/pull/165) ([david22swan](https://github.com/david22swan))

### Fixed

- Fix `Logger.error` [#173](https://github.com/puppetlabs/pdksync/pull/173) ([alexjfisher](https://github.com/alexjfisher))

## [v0.6.0](https://github.com/puppetlabs/pdksync/tree/v0.6.0) - 2021-08-16

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/0.5.0...v0.6.0)

### Added

- (FEAT) Add tasks for updating supported platforms / requirements [#142](https://github.com/puppetlabs/pdksync/pull/142) ([sanfrancrisko](https://github.com/sanfrancrisko))
- Add tasks to add / update entries in module's provision.yaml [#136](https://github.com/puppetlabs/pdksync/pull/136) ([sanfrancrisko](https://github.com/sanfrancrisko))
- (MODULES-10379) Multi Gem testing [#128](https://github.com/puppetlabs/pdksync/pull/128) ([sheenaajay](https://github.com/sheenaajay))
- (maint) Add bundler tasks and pdk requirement [#120](https://github.com/puppetlabs/pdksync/pull/120) ([logicminds](https://github.com/logicminds))
- (MODULES-9786) Using pdksync to update the Gemfile [#114](https://github.com/puppetlabs/pdksync/pull/114) ([sheenaajay](https://github.com/sheenaajay))
- Major refactor and new features [#105](https://github.com/puppetlabs/pdksync/pull/105) ([logicminds](https://github.com/logicminds))

### Fixed

- (GH-148) Fix logging for pdksync:pdk_validate task [#150](https://github.com/puppetlabs/pdksync/pull/150) ([sanfrancrisko](https://github.com/sanfrancrisko))
- (MODULES-8440) Ensure pdksync works on windows [#133](https://github.com/puppetlabs/pdksync/pull/133) ([michaeltlombardi](https://github.com/michaeltlombardi))
- (maint) fix gemfury upload [#132](https://github.com/puppetlabs/pdksync/pull/132) ([sheenaajay](https://github.com/sheenaajay))
- fix gemfury testing upload [#131](https://github.com/puppetlabs/pdksync/pull/131) ([DavidS](https://github.com/DavidS))
- (IAC-354) Fix Gemfile update [#130](https://github.com/puppetlabs/pdksync/pull/130) ([sheenaajay](https://github.com/sheenaajay))
- (maint) 27x performance improvement [#123](https://github.com/puppetlabs/pdksync/pull/123) ([DavidS](https://github.com/DavidS))
- (maint) Add Requirements to README.md and fix travis [#118](https://github.com/puppetlabs/pdksync/pull/118) ([mihaibuzgau](https://github.com/mihaibuzgau))

## [0.5.0](https://github.com/puppetlabs/pdksync/tree/0.5.0) - 2019-08-21

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/0.4.0...0.5.0)

### Added

- pdksync externalisation fixes [#95](https://github.com/puppetlabs/pdksync/pull/95) ([DavidS](https://github.com/DavidS))
- (MODULES-8730) Display warning on outdated pdk version [#92](https://github.com/puppetlabs/pdksync/pull/92) ([eimlav](https://github.com/eimlav))

### Fixed

- (MODULES-9011) deal with modules that do not need updating [#101](https://github.com/puppetlabs/pdksync/pull/101) ([DavidS](https://github.com/DavidS))

## [0.4.0](https://github.com/puppetlabs/pdksync/tree/0.4.0) - 2019-02-04

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/v0.3.0...0.4.0)

### Added

- (MODULES-8419) Refactor to add support for GitLab [#85](https://github.com/puppetlabs/pdksync/pull/85) ([antaflos](https://github.com/antaflos))
- (MODULES-7233) - Add configurable file option [#81](https://github.com/puppetlabs/pdksync/pull/81) ([eimlav](https://github.com/eimlav))

### Fixed

- (MODULES-8283) - Fix PR title overwritten in pdksync runs [#84](https://github.com/puppetlabs/pdksync/pull/84) ([eimlav](https://github.com/eimlav))
- (MODULES-8382) - Fix API rate limit false positive [#83](https://github.com/puppetlabs/pdksync/pull/83) ([eimlav](https://github.com/eimlav))

## [v0.3.0](https://github.com/puppetlabs/pdksync/tree/v0.3.0) - 2018-11-15

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/0.2.0...v0.3.0)

### Added

- (MODULES-8231) - Add additional title info for pdksync runs [#76](https://github.com/puppetlabs/pdksync/pull/76) ([eimlav](https://github.com/eimlav))
- (MODULES-7695) - Add maintenance labels for PRs [#75](https://github.com/puppetlabs/pdksync/pull/75) ([eimlav](https://github.com/eimlav))

### Fixed

- (MODULES-8002) - Fix bundle commands not running in correct dir [#79](https://github.com/puppetlabs/pdksync/pull/79) ([eimlav](https://github.com/eimlav))

## [0.2.0](https://github.com/puppetlabs/pdksync/tree/0.2.0) - 2018-11-02

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/0.1.0...0.2.0)

### Added

- (feat) add colourised output, fix pdk path [#68](https://github.com/puppetlabs/pdksync/pull/68) ([tphoney](https://github.com/tphoney))
- (CLOUD-2094) adding container modules to the list [#67](https://github.com/puppetlabs/pdksync/pull/67) ([sheenaajay](https://github.com/sheenaajay))
- (feat) adding git commit rake task [#63](https://github.com/puppetlabs/pdksync/pull/63) ([tphoney](https://github.com/tphoney))
- (FEAT) add clone_managed_modules task [#58](https://github.com/puppetlabs/pdksync/pull/58) ([tphoney](https://github.com/tphoney))

### Fixed

- Use https instead of ssh for the clone [#72](https://github.com/puppetlabs/pdksync/pull/72) ([HelenCampbell](https://github.com/HelenCampbell))

## [0.1.0](https://github.com/puppetlabs/pdksync/tree/0.1.0) - 2018-05-23

[Full Changelog](https://github.com/puppetlabs/pdksync/compare/73bf282b297781bc26562bfb51b91b4f7b1632d1...0.1.0)
