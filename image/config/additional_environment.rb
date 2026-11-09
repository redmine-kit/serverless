# frozen_string_literal: true

# Loaded inside config/application.rb, before production.rb. Only settings
# that production.rb does not set are effective here (docs/lambda.md).

# Settings and secrets from SSM Parameter Store are already in ENV here: the
# plugin redmine_serverless_ssm reads them before the configuration
# (REDMINE_SSM_PATH).

config.cache_store = :memory_store, { size: 64 * 1024 * 1024 }
config.active_job.queue_adapter = ENV['REDMINE_ROLE'] ? :sqs : :inline
config.active_record.dump_schema_after_migration = false
config.hosts << ENV['REDMINE_HOST'] if ENV['REDMINE_HOST'].present?
