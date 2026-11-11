# frozen_string_literal: true

# Loaded inside config/application.rb, before production.rb. Only settings
# that production.rb does not set are effective here (docs/lambda.md).

# Settings and secrets from SSM Parameter Store are already in ENV here: the
# plugin redmine_aws_ssm reads them before the configuration
# (REDMINE_SSM_PATH).

config.cache_store = :memory_store, { size: 64 * 1024 * 1024 }
# Jobs run in the request unless redmine_aws_sqs switches them to SQS
# (when REDMINE_JOBS_QUEUE_URL is set; docs/lambda.md#background-jobs).
config.active_job.queue_adapter = :inline
config.active_record.dump_schema_after_migration = false
config.hosts << ENV['REDMINE_HOST'] if ENV['REDMINE_HOST'].present?
# Redirects to attachments' signed URLs on CloudFront (/files/ and /tmp/,
# redmine_aws_s3) are written to the log as [FILTERED], so that the
# log does not hand out working URLs (docs/security.md#logs).
config.filter_redirect << %r{\Ahttps://[^/]+/(?:files|tmp)/}

# Redmine's session cookie (config/application.rb) with Secure added, so that
# it is sent only over HTTPS (docs/session.md). Only in production: Redmine's
# own tests send plain HTTP requests, which would get no session cookie.
if Rails.env.production?
  config.session_store :cookie_store, key: '_redmine_session', path: config.relative_url_root || '/',
                                      same_site: :lax, secure: true
end
