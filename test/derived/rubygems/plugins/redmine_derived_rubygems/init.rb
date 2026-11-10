# frozen_string_literal: true

# A plugin with a gem from RubyGems, for a derived image built without a
# GitHub token (bin/test-derived-image).
require 'chronic'

Redmine::Plugin.register :redmine_derived_rubygems do
  name 'Derived image with a RubyGems gem'
  author 'Redmine Serverless tests'
  version '0.0.1'
end
