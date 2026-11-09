# Serverless

[![CI](https://img.shields.io/github/actions/workflow/status/redmine-kit/serverless/ci.yml?branch=main&label=CI)](https://github.com/redmine-kit/serverless/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/codecov/c/github/redmine-kit/serverless?label=Coverage)](https://codecov.io/gh/redmine-kit/serverless)
[![License](https://img.shields.io/github/license/redmine-kit/serverless?label=License)](LICENSE)
[![Tested with LocalStack](https://img.shields.io/badge/Tested%20with-LocalStack-39227A?logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9Ii0wLjM4IC0wLjAwIDg4Ljg4IDg4Ljg4Ij48cGF0aCBmaWxsLXJ1bGU9ImV2ZW5vZGQiIGNsaXAtcnVsZT0iZXZlbm9kZCIgZD0iTTc2LjI5ODMgNjEuODcyN0M3Ny4zMDA2IDYxLjg3MjcgNzcuODAyNSA2My4wODQ1IDc3LjA5MzggNjMuNzkzMkw1Mi43MTYzIDg4LjE2ODhDNTIuMDA3NiA4OC44Nzc1IDUwLjc5NTcgODguMzc1NiA1MC43OTU3IDg3LjM3MzRMNTAuNzk1NyA2Mi45OTc3QzUwLjc5NTcgNjIuMzc2NCA1MS4yOTk0IDYxLjg3MjcgNTEuOTIwOCA2MS44NzI3TDc2LjI5ODMgNjEuODcyN1pNMS4xMjczMiAzOC45MDM2QzAuMTI1MDIgMzguOTAzNiAtMC4zNzY5MzMgMzcuNjkxOCAwLjMzMTgwNyAzNi45ODMyTDI0LjcwOTMgMTIuNjA3NUMyNS40MTggMTEuODk4OCAyNi42Mjk4IDEyLjQwMDcgMjYuNjI5OCAxMy40MDI5TDI2LjYyOTggMzcuNzc4NkMyNi42Mjk4IDM4LjM5OTkgMjYuMTI2MSAzOC45MDM2IDI1LjUwNDggMzguOTAzNkwxLjEyNzMyIDM4LjkwMzZaIiBmaWxsPSJ1cmwoI3BhaW50MF9saW5lYXJfMjBfMykiLz48cGF0aCBkPSJNNTQuMTkzNCAzNC45MDI5TDg2Ljg0ODkgMzQuOTAyOUM4Ny40NzAyIDM0LjkwMjkgODcuOTczOSAzNC4zOTkzIDg3Ljk3MzkgMzMuNzc4TDg3Ljk3MzkgMS4xMjQ4OEM4Ny45NzM5IDAuNTAzNTgyIDg3LjQ3MDIgLTguMDE1MjdlLTA1IDg2Ljg0ODkgLTguMDIwN2UtMDVMNTQuMTkzNCAtOC4zMDYxOGUtMDVDNTMuNTcyMSAtOC4zMTE2MmUtMDUgNTMuMDY4NCAwLjUwMzU3OSA1My4wNjg0IDEuMTI0ODdMNTMuMDY4NCAzMy43NzhDNTMuMDY4NCAzNC4zOTkzIDUzLjU3MjEgMzQuOTAyOSA1NC4xOTM0IDM0LjkwMjlaIiBmaWxsPSJ1cmwoI3BhaW50MV9saW5lYXJfMjBfMykiLz48cGF0aCBkPSJNNzguMzgxOCA1Ni4yNDhMMzMuMzgwMSA1Ni4yNDhDMzIuNzU4OCA1Ni4yNDggMzIuMjU1MSA1NS43NDQzIDMyLjI1NTEgNTUuMTIzTDMyLjI1NTEgMTAuMTI0NkMzMi4yNTUxIDkuNTAzMzMgMzIuNzU4OCA4Ljk5OTY3IDMzLjM4MDEgOC45OTk2N0w0Ni4zMTgxIDguOTk5NjdDNDYuOTM5NCA4Ljk5OTY3IDQ3LjQ0MzEgOS41MDMzMyA0Ny40NDMxIDEwLjEyNDZMNDcuNDQzMSAzOS4zNzM2QzQ3LjQ0MzEgMzkuOTk0OSA0Ny45NDY4IDQwLjQ5ODYgNDguNTY4MiA0MC40OTg2TDc4LjM4MTggNDAuNDk4NkM3OS4wMDMxIDQwLjQ5ODYgNzkuNTA2OCA0MS4wMDIyIDc5LjUwNjggNDEuNjIzNUw3OS41MDY4IDU1LjEyM0M3OS41MDY4IDU1Ljc0NDMgNzkuMDAzMSA1Ni4yNDggNzguMzgxOCA1Ni4yNDhaIiBmaWxsPSJ1cmwoI3BhaW50Ml9saW5lYXJfMjBfMykiLz48ZGVmcz4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDBfbGluZWFyXzIwXzMiIHgxPSI3Ny41MDM1IiB5MT0iMTIuMDQ0NCIgeDI9IjEzLjk1MTYiIHkyPSI3NC45NjgiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9uVXNlIj4KPHN0b3Agc3RvcC1jb2xvcj0iIzREMjlCNCIvPgo8c3RvcCBvZmZzZXQ9IjEiIHN0b3AtY29sb3I9IiM4MzZGRkYiLz4KPC9saW5lYXJHcmFkaWVudD4KPGxpbmVhckdyYWRpZW50IGlkPSJwYWludDFfbGluZWFyXzIwXzMiIHgxPSI1MC4wMTA3IiB5MT0iMzYuNjU3IiB4Mj0iOTMuOTk2NCIgeTI9Ii02LjU0ODg3IiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+CjxzdG9wIHN0b3AtY29sb3I9IiM3MEZGRTUiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNjI5NUUxIi8+CjwvbGluZWFyR3JhZGllbnQ+CjxsaW5lYXJHcmFkaWVudCBpZD0icGFpbnQyX2xpbmVhcl8yMF8zIiB4MT0iNzMuODM3NyIgeTE9IjE5LjM3NTkiIHgyPSIzMi40NzA1IiB5Mj0iNTguNjU0NCIgZ3JhZGllbnRVbml0cz0idXNlclNwYWNlT25Vc2UiPgo8c3RvcCBvZmZzZXQ9IjAuMDA3NDc1MTEiIHN0b3AtY29sb3I9IiM2NTRGRUMiLz4KPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjNzFCMkZGIi8+CjwvbGluZWFyR3JhZGllbnQ+CjwvZGVmcz48L3N2Zz4=)](https://localstack.cloud)

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

## Sponsors

<a href="https://www.keyselect.co.jp/">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/keyselect-logo-dark.svg">
    <img alt="KEY SELECT" src=".github/assets/keyselect-logo.svg" width="113" height="24">
  </picture>
</a>

<a href="https://localstack.cloud">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/localstack-logo-dark.svg">
    <img alt="LocalStack" src=".github/assets/localstack-logo.svg" width="120" height="28">
  </picture>
</a>

## License

Serverless is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](LICENSE). An unofficial project for Redmine.
