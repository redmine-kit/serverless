# frozen_string_literal: true

# Loaded inside config/application.rb, before production.rb. Only settings
# that production.rb does not set are effective here (docs/lambda.md).

# Settings and secrets from SSM Parameter Store, before database.yml and
# SECRET_KEY_BASE are read. REDMINE_SSM_PATH (such as /redmine/env/) is set
# on the functions; without it, as in local tests, nothing is read.
if ENV['REDMINE_SSM_PATH'].present?
  require config.root.join('config/serverless_env').to_s
  ServerlessEnv.load(ENV.fetch('REDMINE_SSM_PATH'))
end

config.cache_store = :memory_store, { size: 64 * 1024 * 1024 }
config.active_job.queue_adapter = ENV['REDMINE_ROLE'] ? :sqs : :inline
config.active_record.dump_schema_after_migration = false
config.hosts << ENV['REDMINE_HOST'] if ENV['REDMINE_HOST'].present?
