# frozen_string_literal: true

# Loaded via RUBYOPT (-r) to restore bundler source credentials in PDK subprocesses.
#
# PDK runs bundler inside Bundler.with_unbundled_env which strips ALL BUNDLE_*
# environment variables, including source authentication credentials like
# BUNDLE_RUBYGEMS___PUPPETCORE__PUPPET__COM. PDK also sets BUNDLE_IGNORE_CONFIG=1,
# preventing bundler from reading credentials from config files.
#
# To work around this, pdksync passes credentials under a PDKSYNC_BUNDLE_ prefix
# (which survives the stripping) and this script restores them to their original
# BUNDLE_ names before Bundler initializes.
ENV.each_pair do |key, value|
  next unless key.start_with?('PDKSYNC_BUNDLE_')

  bundle_key = key.sub('PDKSYNC_BUNDLE_', 'BUNDLE_')
  ENV[bundle_key] = value
end
