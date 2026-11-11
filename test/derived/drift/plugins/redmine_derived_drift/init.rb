# frozen_string_literal: true

# A plugin whose Gemfile would move a gem of the base image
# (bin/test-derived-image).
Redmine::Plugin.register :redmine_derived_drift do
  name 'Derived image drift'
  author 'Serverless tests'
  version '0.0.1'
end
