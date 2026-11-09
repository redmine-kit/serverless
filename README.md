# Serverless

[![codecov](https://codecov.io/gh/redmine-kit/serverless/graph/badge.svg)](https://codecov.io/gh/redmine-kit/serverless)

A design for running the latest Redmine (7.0.3) on AWS Lambda (Event Functions), with RDS for PostgreSQL as the database and S3 for attachments and assets. No third-party plugins are installed, and the theme stays the default. Extensions for Lambda and AWS are the project's own plugins: [`redmine_serverless`](https://github.com/redmine-kit/redmine_serverless) (running on Lambda), [`redmine_serverless_s3`](https://github.com/redmine-kit/redmine_serverless_s3) (attachments in S3) and [`redmine_serverless_ses`](https://github.com/redmine-kit/redmine_serverless_ses) (mail through SES).

[日本語](README.ja.md)

> **Status:** early development. The image and its tests are built; the rest is in the design stage.

## Documentation

- Website: https://redmine-kit.github.io/serverless/ (日本語: https://redmine-kit.github.io/serverless/ja/)
- Markdown: [docs/README.md](docs/README.md) (日本語: [docs/ja/README.md](docs/ja/README.md))

Start with [docs/architecture.md](docs/architecture.md). The plugins' designs are in [Redmine Serverless](https://redmine-kit.github.io/redmine_serverless/), [Redmine Serverless S3](https://redmine-kit.github.io/redmine_serverless_s3/) and [Redmine Serverless SES](https://redmine-kit.github.io/redmine_serverless_ses/).

## Key points of the design

- **Runtime:** A container image (arm64) built on the Lambda Ruby base image (Ruby 4.0, Amazon Linux 2023), with Redmine and Lambda Web Adapter installed, runs on Event Functions. The web, worker and task functions use the same image and switch roles with an environment variable.
- **Entry point:** CloudFront forwards requests to a function URL. The function URL uses IAM authentication and accepts only requests signed by CloudFront OAC. Lambda@Edge adds the body hash for POST and other requests with a body. CloudFront serves assets (`/assets/*`) from S3.
- **Database:** RDS for PostgreSQL in a VPC. The Lambda functions run in the VPC's private subnets and reach AWS services through VPC endpoints or a NAT instance ([docs/rds.md](docs/rds.md)).
- **Attachments:** Stored in S3. Browsers upload directly to S3, and downloads redirect to an S3 presigned URL. Built in the plugin `redmine_serverless_s3`, based on the approach of the Redmine S3 plugins.
- **Jobs:** ActiveJob jobs are queued in SQS (`aws-activejob-sqs`) and run by the worker function.
- **Mail:** For sending, the worker function sends mail from Rails ActionMailer through the SES API (`aws-actionmailer-ses`). For receiving, SES receives mail and stores it in S3, and the task function imports it into Redmine.
- **Settings and secrets:** Stored in SSM Parameter Store and read by Redmine at start-up.
- **Migrations and rake:** Run in the task function from a local command (`bin/rake`).
- **Tests:** CI runs, in order, tests for each piece of replaced code, Redmine's own tests, image tests, Lambda integration tests (LocalStack), and checks after deployment ([docs/testing.md](docs/testing.md)).

## License

Serverless is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](LICENSE). Not affiliated with the Redmine project.
