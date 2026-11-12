# Sources

Information referred to in these docs.

- Unless a row says otherwise, everything was checked on 2026-11-08.
- Specifications can change. When building, check the latest content and update the check date.

## Redmine

| Page | What was checked |
| --- | --- |
| [Download](https://www.redmine.org/projects/redmine/wiki/Download) | The latest stable version is 7.0.3 (2026-11-01). 6.1 receives only bug fixes and security fixes |
| [RedmineInstall](https://www.redmine.org/projects/redmine/wiki/RedmineInstall) | For 7.0: Ruby (3.2–4.0), Rails 8.1, databases (PostgreSQL 14, MySQL 8.0–8.4, etc.), ImageMagick, Ghostscript, Pandoc, and that the `:async` job adapter is not recommended for production |
| [Changelog 7.0](https://www.redmine.org/projects/redmine/wiki/Changelog_7_0) | Dates of 7.0.0–7.0.3 |
| [Roadmap](https://www.redmine.org/projects/redmine/roadmap) | 7.1.0 and 7.0.4 are in development |
| [EmailConfiguration](https://www.redmine.org/projects/redmine/wiki/EmailConfiguration) | How to write `email_delivery` |
| [7.0-stable of redmine/redmine](https://github.com/redmine/redmine/tree/7.0-stable) (d718d63). OAuth 2 provider (doorkeeper in `Gemfile`, `config/initializers/doorkeeper.rb`), mailer headers (`X-Redmine-Project`), how the project for imported email is chosen (`MailHandler#target_project`) | Attachment handling (`app/models/attachment.rb`, `app/controllers/attachments_controller.rb`, `app/assets/javascripts/attachments.js`), temporary files for imports, automatic asset export, jobs, sessions |
| [redmine on Docker Hub](https://hub.docker.com/_/redmine) | 7.0.3 tag, arm64 build (updated on 2026-11-06) |
| [The 7.0 Dockerfile (trixie) in docker-library/redmine](https://github.com/docker-library/redmine/blob/master/7.0/trixie/Dockerfile) | Base of the official image (`ruby:4.0-slim-trixie`), included tools, permissions, entry point. SHA256 of the Redmine 7.0.3 tar.gz |

## Redmine's S3 plugin (reference)

| Page | What was checked |
| --- | --- |
| [hgyoon-w/redmine5_amazon_s3](https://github.com/hgyoon-w/redmine5_amazon_s3) | 1.0.0, last commit on 2025-12-17, Redmine 5.0 or later. Storing, deleting, redirects for downloads and thumbnails, replacing `thumbnail_tag`. Replaces the digest with the time of storage |
| [redmine_cloud_attachment_pro](https://www.redmine.org/plugins/redmine_cloud_attachment_pro) | 0.0.1, Redmine 4.0–6.1. Fetches from S3 into a temporary file on every `diskfile` |
| [ka8725/redmine_s3](https://github.com/ka8725/redmine_s3) | An S3 plugin from long ago (the Redmine 3.x era) |

## Rails

| Page | What was checked |
| --- | --- |
| [configuration.rb in railties (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/configuration.rb) | Default cache (file), how `SECRET_KEY_BASE` is read |
| [railtie in activejob (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activejob/lib/active_job/railtie.rb) | The default job adapter is `:async` |
| [mail_delivery_job.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionmailer/lib/action_mailer/mail_delivery_job.rb) | The mail job passes exceptions to the mailer's `handle_exception` (if there is no handler, the exception is raised as is) |
| [railtie in Propshaft (v1.3.1)](https://github.com/rails/propshaft/blob/v1.3.1/lib/propshaft/railtie.rb) | Asset output directory `public/assets` |
| [active_record.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record.rb) | The default of `dump_schema_after_migration` is `true` |
| [databases.rake (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/activerecord/lib/active_record/railties/databases.rake) | The schema is dumped after `db:migrate` |
| [bootstrap.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/bootstrap.rb) | The cache is created in `initialize_cache`, before the application's initializers |
| [host_authorization.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/middleware/host_authorization.rb) | A request is blocked with 403 when `Host` is not allowed, or when `X-Forwarded-Host` is present and its last value is not allowed (`blocked_hosts`). `exclude` gets only the request (checked on 2026-11-10). [lambda.md](lambda.md#host-and-scheme) |
| [request_forgery_protection.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_controller/metal/request_forgery_protection.rb) | `forgery_protection_origin_check` is `false` unless set; `load_defaults` 5.0 or later sets it to `true` (`configuration.rb`). Redmine 7.0.3 does not call `load_defaults` (`config/application.rb`; checked on 2026-11-10). [lambda.md](lambda.md#host-and-scheme) |
| [default_middleware_stack.rb (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/railties/lib/rails/application/default_middleware_stack.rb) | `HostAuthorization` is the first middleware, and only when `config.hosts` is not empty (checked on 2026-11-10) |
| [url.rb in actionpack (v8.1.4)](https://github.com/rails/rails/blob/v8.1.4/actionpack/lib/action_dispatch/http/url.rb) | The host comes from the last value of `X-Forwarded-Host`, otherwise `Host` (`raw_host_with_port`); the port from that value, otherwise the scheme's standard port; the protocol from `ssl?` (checked on 2026-11-10) |
| [request.rb in Rack (v3.2.8)](https://github.com/rack/rack/blob/v3.2.8/lib/rack/request.rb) | The scheme comes from `HTTPS`, then the `Forwarded` header, then `X-Forwarded-Proto` (`forwarded_priority` defaults to `[:forwarded, :x_forwarded]`; checked on 2026-11-10) |

## AWS Lambda

| Page | What was checked |
| --- | --- |
| [Lambda runtimes](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html) | `ruby4.0` and `ruby3.4` (Amazon Linux 2023) and their deprecation dates |
| [Lambda quotas](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html) | Synchronous invocation request and response are 6 MB. Container images are 10 GB; zip is 250 MB unzipped. `/tmp` is 512–10,240 MB |
| [Execution environment lifecycle](https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtime-environment.html) | Initialization is limited to 10 seconds. Beyond that, it is retried on the first invocation |
| [SnapStart](https://docs.aws.amazon.com/lambda/latest/dg/snapstart.html) | Java, Python and .NET only. Ruby is not supported |
| [Response streaming](https://docs.aws.amazon.com/lambda/latest/dg/configuration-response-streaming.html) | Streaming responses are up to 200 MB. This design does not use streaming so that compression can be used (`AWS_LWA_INVOKE_MODE` is buffered; [lambda.md](lambda.md#lambda-web-adapter-settings)) |
| [Building Lambda functions with Ruby](https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html) | YJIT is recommended for Rails (`RUBY_YJIT_ENABLE=1`) |
| [Configuring S3 Files access](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem-s3files.html) | Requirements of S3 Files, which was considered and not used (same VPC as the mount target, NFS) |
| [File systems](https://docs.aws.amazon.com/lambda/latest/dg/configuration-filesystem.html) | Event Functions can mount either EFS or S3 Files |
| [Lambda Managed Instances](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances-runtimes.html) | Ruby is not among the supported languages. Minimum number of execution environments |
| [Web Functions runtimes](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-runtimes.html) | `nodejs24.x` only |
| [Web Functions revisions](https://docs.aws.amazon.com/lambda/latest/dg/web-functions-revisions.html) | There are no file system settings |
| [AWS Lambda Web Adapter](https://github.com/aws/aws-lambda-web-adapter) | 1.1.0 (2026-09-18), readiness check (`tcp`), `AWS_LWA_ASYNC_INIT`, handling of non-HTTP events |
| [Lambda Web Adapter 1.1.0 source](https://github.com/aws/aws-lambda-web-adapter/tree/v1.1.0/src) | List of environment variables it reads (no setting to turn it off). It registers as an extension with `{"events": []}` and also talks to the Runtime API itself (`src/main.rs`, `register_extension_internal` in `src/lib.rs`) |
| [Lambda Web Adapter 1.1.0 `src/lib.rs`](https://github.com/aws/aws-lambda-web-adapter/blob/v1.1.0/src/lib.rs) | The request headers, `Host` included, go to the web application as they are, with `x-amzn-request-context` and `x-amzn-lambda-context` added (checked on 2026-11-10). [lambda.md](lambda.md#host-and-scheme) |
| [Invoking Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-invocation.html) | The event has the request headers and `requestContext.domainName`, the function URL's domain. The page does not say how the function URL treats `X-Forwarded-Host` or `X-Forwarded-Proto` (checked on 2026-11-10) |
| [Using the Lambda Extensions API](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-extensions-api.html) | `Lambda-Extension-Name` is the same as the file name. `events` is not required. If an extension fails, the execution environment is recreated |
| [Create a Lambda Event Function using a container image](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html) | Read-only file system, the default user must be able to read all files, single-architecture images only, `Inactive` after not being invoked for several weeks, `Failed` if the ECR image is deleted |
| [Control access to Lambda function URLs](https://docs.aws.amazon.com/lambda/latest/dg/urls-auth.html) | Since October 2025, function URLs need both `lambda:InvokeFunctionUrl` and `lambda:InvokeFunction`. For OAC, this design allows both to CloudFront with the distribution's `AWS:SourceArn` ([iam.md](iam.md#resource-based-policies)) |
| [Lambda Ruby base image](https://gallery.ecr.aws/lambda/ruby) | Has `/lambda-entrypoint.sh` and `curl`. `ruby:4.0` is Ruby 4.0.9 on Amazon Linux 2023. Checked by running it in local Docker (arm64). ImageMagick 6.9.12, ghostscript 9.56.1, libpq 15.0, ipa-gothic-fonts, gcc and make are in the standard repositories (`microdnf repoquery`). Pandoc is not |
| [Lambda S3 Files announcement](https://aws.amazon.com/about-aws/whats-new/2026/04/aws-lambda-amazon-s3/) | April 2026. No additional charge for Lambda |

## S3, CloudFront and databases

| Page | What was checked |
| --- | --- |
| [S3 Files synchronization](https://docs.aws.amazon.com/AmazonS3/latest/userguide/s3-files-synchronization.html) | One of the reasons it was considered and not used. Data is written to S3 after writes stop for 60 seconds |
| [S3 pricing](https://aws.amazon.com/s3/pricing/) | How S3 Files is priced. The ap-northeast-1 unit price in the price list (AmazonS3) is USD 0.36 per GB-month of stored data |
| [GetObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html) | A (presigned) GET can override only `response-content-type`, `-language`, `-expires`, `-cache-control`, `-disposition` and `-encoding`, so it cannot add a CSP; the reason attachments go through CloudFront |
| [Implementing secure file uploads to Amazon S3 at the edge: Choosing the right pattern](https://aws.amazon.com/blogs/networking-and-content-delivery/implementing-secure-file-uploads-to-amazon-s3-at-the-edge-choosing-the-right-pattern/) | AWS blog, 2026-02-24. Origin access control does not sign POST policies, so uploads through CloudFront use PUT |
| [Checking object integrity for data uploads](https://docs.aws.amazon.com/AmazonS3/latest/userguide/checking-object-integrity-upload.html) | A copy with a checksum algorithm gets a checksum of the full object, also when the source was a multipart upload; `PutObject` uses the full object checksum type; `HeadObject` with `ChecksumMode` returns the checksum (checked on 2026-11-10) ([attachments.md](https://redmine-kit.github.io/redmine_aws_s3/attachments.html#upload)) |
| [Restricting access to a function URL origin with OAC](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-lambda.html) | PUT and POST need `x-amz-content-sha256`. Lambda does not accept unsigned bodies. The function URL uses `AWS_IAM`. Allow `lambda:InvokeFunctionUrl` and `lambda:InvokeFunction` to CloudFront with the distribution's `AWS:SourceArn` (checked on 2026-11-09) |
| [Add custom headers to origin requests](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/add-origin-custom-headers.html) | When the viewer request has a header of the same name, CloudFront overwrites its value before forwarding the request to the origin. Headers CloudFront cannot add include `Host`, `Cookie`, `Via`, `X-Real-Ip` and headers that begin with `X-Amz-` or `X-Edge-`, not `X-Forwarded-Host` or `X-Forwarded-Proto` (checked on 2026-11-10). [lambda.md](lambda.md#host-and-scheme) |
| [Request and response behavior for custom origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/RequestAndResponseBehaviorCustomOrigin.html) | Unless `Host` is forwarded, CloudFront sets it to the origin's domain name. CloudFront removes the viewer's `X-Forwarded-Proto` and forwards `X-Forwarded-For` with the viewer's address appended (checked on 2026-11-10) |
| [CloudFront Functions event structure](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/functions-event-structure.html) | Request data is only the method, URI, query, headers and cookies; there is no body (checked on 2026-11-09). [lambda.md](lambda.md#cloudfront-and-function-urls) |
| [Restrictions on Lambda@Edge](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/lambda-at-edge-function-restrictions.html) | The body is passed as base64. It is truncated at 1 MB for origin requests and 40 KB for viewer requests. us-east-1, Node.js and Python; container images and arm64 cannot be used. The execution role must also allow `edgelambda.amazonaws.com` to assume it (checked on 2026-11-09) |
| [New features of CloudFront flat-rate plans (AWS blog)](https://aws.amazon.com/blogs/networking-and-content-delivery/amazon-cloudfront-flat-rate-pricing-plans-new-features-and-expanded-capabilities/) | 2026-03-24. Lambda@Edge became available on all flat-rate plans. Invocations are paid pay-per-use, separately from the plan |
| [Computing a content hash with Lambda@Edge to make POST/PUT requests with CloudFront and Lambda function URLs (Classmethod, in Japanese)](https://dev.classmethod.jp/articles/cloudfront-lambda-url-with-post-put-request) | An unofficial write-up of practice (2024-07-29). Lambda@Edge adds `x-amz-content-sha256`, and the function URL accepted POST with the OAC signature. It computes the hash after converting the body to a string, so this design computes it on the bytes as they are |
| Price list (AWSLambda, ap-northeast-1, published 2026-10-30) | Lambda@Edge is USD 0.60 per million requests and USD 0.00005001 per GB-second |
| [Route 53 price list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonRoute53/current/index.json) | USD 0.50 per hosted zone per month (up to 25), queries from inside AWS to alias records are free, other queries USD 0.40 per million (published 2026-11-04) |
| [Setting up CNAME flattening in Cloudflare](https://developers.cloudflare.com/dns/cname-flattening/set-up-cname-flattening/) | The apex and proxied records are flattened on every plan. Paid plans can flatten all CNAMEs or per record. Nothing is written about an MX with the same name |
| Price lists (ap-northeast-1. AmazonEC2 published 2026-11-07, AmazonECS 2026-10-19, AWSELB 2026-11-05, AmazonLightsail 2026-09-15) | EC2 t4g.small USD 0.0216 per hour, gp3 USD 0.096 per GB-month, Fargate Arm USD 0.04045 per vCPU-hour and USD 0.00442 per GB-hour of memory, ALB USD 0.0243 per hour and USD 0.008 per LCU-hour, Lightsail 2 GB USD 0.01612 per hour (including a public IPv4 address). [comparison.md](comparison.md) |
| [Migrating Redmine's database from MySQL to PostgreSQL (Qiita, in Japanese)](https://qiita.com/SKYS/items/2004c60000ddfeaa20b3) | An unofficial write-up of practice (by @SKYS, 2026-08-09). Redmine 6.1, from MySQL 8.0 to PostgreSQL 18. The schema is created by Redmine's migrations, and Embulk copies only the data. Exclude `schema_migrations`, fix sequences, copy `wiki_content_versions.data` as base64. pgloader 3.6.9 did not work. [migration.md](migration.md#migrating-from-mysql) |
| [dimitri/pgloader](https://github.com/dimitri/pgloader) | The last release is v3.6.9 (2022-10-24). The repository is still being updated (2026-09-14) |
| [CloudFront pricing](https://aws.amazon.com/cloudfront/pricing/) | The Free flat-rate plan is USD 0 per month, 1 million requests and 100 GB per month, up to 5 WAF rules. Logs, custom cache rules and origins inside a VPC are not included |
| [CloudFront quotas](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-limits.html) | Origin response timeout is 1–120 seconds |
| [Aurora Serverless v2 automatic pause](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html) | Supported versions, about 15 seconds to resume, 30 seconds or more after more than 24 hours, does not pause while there are connections |
| [Stopping RDS](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_StopInstance.html) | Can be stopped for up to 7 days. Starting can take time |
| [IAM database authentication](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.IAMDBAuth.html) | 300–1,000 MiB of additional memory |
| [Using SQLite over a network](https://www.sqlite.org/useovernet.html) | There are cases of corruption because of locking problems |
| [SES VPC endpoints](https://docs.aws.amazon.com/ses/latest/dg/send-email-set-up-vpc-endpoints.html) | Interface endpoints for the API (`email`) and for SMTP. The API uses port 443 |
| [SES endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/ses.html) | The receiving endpoint in ap-northeast-1 is `inbound-smtp.ap-northeast-1.amazonaws.com` |
| [SES email receiving concepts](https://docs.aws.amazon.com/ses/latest/dg/receiving-email-concepts.html) | Only email to verified identities is received, up to 40 MB can be stored in S3, the `X-SES-Spam-Verdict`, `X-SES-Virus-Verdict` and `Authentication-Results` headers |
| [SES and Regions](https://docs.aws.amazon.com/ses/latest/dg/regions.html) | The Lambda function used for receiving is in the same Region as SES. One active rule set per Region |

## Prices

The publication dates of the price lists are in [cost.md](cost.md#sources-of-the-prices).

## Gems and tools

| Page | What was checked |
| --- | --- |
| [aws/aws-actionmailer-ses-ruby](https://github.com/aws/aws-actionmailer-ses-ruby) | Delivery method `:ses_v2`, `ses_v2_settings`, passing the full message (raw) and To, Cc and Bcc to SES v2 `SendEmail` (`lib/aws/action_mailer/ses_v2/mailer.rb`) |
| [aws-actionmailer-ses on RubyGems](https://rubygems.org/gems/aws-actionmailer-ses) | 1.2.0 (2026-05-21), `actionmailer` 7.1 or later |
| [Pandoc releases](https://github.com/jgm/pandoc/releases) | 3.13 (2026-10-26), `pandoc-3.13-linux-arm64.tar.gz` |
| [pandoc in Debian (trixie)](https://sources.debian.org/src/pandoc/) | 3.1.11.1 |
| [aws/aws-activejob-sqs-ruby](https://github.com/aws/aws-activejob-sqs-ruby) | Adapter `:sqs`, the Lambda handler (`Aws::ActiveJob::SQS::LambdaHandler.job_handler`; runs each message and deletes it on success; `lib/aws/active_job/sqs/lambda_handler.rb`), loading Rails in a container image |
| [aws-activejob-sqs on RubyGems](https://rubygems.org/gems/aws-activejob-sqs) | 1.2.0 (2026-08-17), `activejob` 7.1 or later |
| [getmoto/moto](https://github.com/getmoto/moto) | Apache-2.0, still being updated (2026-11-06). Used in tests in place of AWS |
| [CloudFront flat-rate plans](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html) | Free: 5 WAF rules; per-IP rate limits and country blocking are available; CAPTCHA, header and regular-expression rules, custom responses for blocked requests and Bot Control are not. Bodies are inspected up to 16 KB. AWS-managed cache, origin request and response headers policies can be used; custom ones from Business. CloudFront Functions are included; Lambda@Edge can be used and is charged per invocation; KeyValueStore from Pro. Access logs and WAF logs from Pro. Up to 3 Free plans per account (cannot be raised). 5 cache behaviors on Free. The web ACL cannot be removed. Rule groups cannot be used. A web ACL or CloudFront Function used by another distribution cannot be attached. Accounts on the AWS Free Tier cannot use the plans (checked on 2026-11-10). [lambda.md](lambda.md#flat-rate-free-plan-and-waf), [security.md](security.md#aws-waf) |
| [CloudFront pricing](https://aws.amazon.com/cloudfront/pricing/) | Free is USD 0 (1 million requests, 100 GB per month), Pro is USD 15 per month (10 million requests, 50 TB). Requests blocked by WAF do not count toward usage (checked on 2026-11-09) |
| [AWS WAF pricing](https://aws.amazon.com/waf/pricing/) | Pay-per-use: USD 5 per month per web ACL, USD 1 per month per rule or managed rule group, USD 0.60 per million requests. Inspecting bodies larger than the default costs USD 0.30 per million requests for each 16 KB (checked on 2026-11-09) |
| [WAF rate-based rule settings](https://docs.aws.amazon.com/waf/latest/developerguide/waf-rule-statement-type-rate-based-high-level-settings.html) | Counting windows are 60, 120, 300 and 600 seconds. The minimum count is 10. Blocking at the exact count is not guaranteed (checked on 2026-11-09) |
| [AWS-managed response headers policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html) | Contents of `SecurityHeadersPolicy` (`67f7725c-6f97-4210-82d7-5512b31e9d03`) (checked on 2026-11-09) |
| [Permissions for GitHub Packages](https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages), [RubyGems registry](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-rubygems-registry) | Only the container registry lets anyone pull public packages without authentication. The RubyGems registry needs a token to install even public gems (checked on 2026-11-09). [architecture.md](architecture.md#distribution) |
| [bundle-config(1) of Bundler 4.0.24, `cooldown`](https://github.com/rubygems/rubygems/blob/v4.0.24/bundler/lib/bundler/man/bundle-config.1.ronn) | The cooldown depends on the gem server giving each version's `created_at` in the compact index; versions without it are treated as outside the cooldown window and can be resolved. GitHub Packages' RubyGems registry (`/info/<gem>`) gives only the dependencies and the checksum, without `created_at` (checked on 2026-11-12). [testing.md](testing.md#updates) |
| [localstack/localstack](https://github.com/localstack/localstack) | The GitHub repository is archived (2026-03). Instead of the repository, use the product with pricing plans (LocalStack for AWS) |
| [minio/minio](https://github.com/minio/minio) | The GitHub repository is archived (2026-04). Not chosen as a test tool |
| [Embulk](https://www.embulk.org/), [embulk-input-mysql and embulk-output-postgresql](https://github.com/embulk/embulk-input-jdbc) | Tools that copy only the data from MySQL to PostgreSQL ([migration.md](migration.md#migrating-from-mysql)). Check the versions to use when building (not checked yet) |
| [Lambda in LocalStack](https://docs.localstack.cloud/aws/services/lambda/) | Lambda and function URLs are available from Hobby. Plan rules for container images are not documented (checked on 2026-11-09) |
| [LocalStack pricing](https://www.localstack.cloud/pricing) | Hobby is free and limited to non-commercial use (the terms forbid use for commercial purposes). Hobby has Lambda, S3, SQS, SSM, IAM and SES (v1), but not SES v2, RDS or CloudFront. CI use is within each plan's rules and Fair Use (checked on 2026-11-09) |

## Other AWS services

| Page | What was checked |
| --- | --- |
| [SES v2 SendEmail](https://docs.aws.amazon.com/ses/latest/APIReference-V2/API_SendEmail.html) | List of errors (`TooManyRequestsException` is 429, the others are 400 or 404) and their meaning. Used to decide how to resend email |
| [EventBridge pricing](https://aws.amazon.com/eventbridge/pricing/) | For a setup that was considered and not used. Custom events are USD 1.00 per million. The price of S3 events is not listed |
| [EventBridge retries](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rule-retry-policy.html) | By default 24 hours, up to 185 attempts. Events that cannot be delivered are received in a dead-letter queue |
