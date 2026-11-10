# frozen_string_literal: true

# A plugin for the derived image tests (test/derived): a setting, a migration
# and a stylesheet.
Redmine::Plugin.register :redmine_derived_sample do
  name 'Derived image sample'
  author 'Redmine Serverless tests'
  version '0.0.1'
  settings default: { 'greeting' => '' }
end
