# frozen_string_literal: true

# The Ruby code that bin/deploy runs with rails runner to apply
# redmine.settings and redmine.pluginSettings (settings_code in
# deploy/lib.sh), against a stand-in for Redmine's Setting.
require 'json'
require 'minitest/autorun'
require 'open3'

class Setting
  Relation = Struct.new(:found) do
    def exists? = found
  end

  class << self
    attr_accessor :store

    def where(name:) = Relation.new(store.key?(name))
    def [](name) = store.fetch(name)

    def []=(name, value)
      store[name] = value
    end
  end
end

class SettingsCodeTest < Minitest::Test
  LIB = File.expand_path('../../deploy/lib.sh', __dir__)
  STORED = {
    'app_title' => 'Old',
    'plugin_redmine_serverless_s3' => { 'cache_size_mb' => '512', 'reconciled_at' => '2026-11-01' }
  }.freeze

  def apply(mode)
    config = {
      'mode' => mode,
      'settings' => { 'app_title' => %(It's "new" `x` $(y)), 'default_language' => 'ja' },
      'plugins' => { 'redmine_serverless_s3' => { 'download_url_expiry' => '600' } }
    }
    code, status = Open3.capture2('bash', '-c', 'source "$0"; settings_code "$1"', LIB, JSON.generate(config))
    assert status.success?
    Setting.store = JSON.parse(JSON.generate(STORED))
    out, = capture_io { eval(code, binding, 'settings_code') } # rubocop:disable Security/Eval
    [Setting.store, out]
  end

  def test_initial_sets_only_what_is_not_stored
    store, out = apply('initial')
    assert_equal 'Old', store['app_title']
    assert_equal 'ja', store['default_language']
    assert_equal STORED['plugin_redmine_serverless_s3'], store['plugin_redmine_serverless_s3']
    assert_equal "settings: 1 applied (initial)\n", out
  end

  def test_enforce_sets_everything_and_merges_plugin_settings
    store, out = apply('enforce')
    assert_equal %(It's "new" `x` $(y)), store['app_title']
    assert_equal 'ja', store['default_language']
    assert_equal({ 'cache_size_mb' => '512', 'reconciled_at' => '2026-11-01', 'download_url_expiry' => '600' },
                 store['plugin_redmine_serverless_s3'])
    assert_equal "settings: 3 applied (enforce)\n", out
  end
end
