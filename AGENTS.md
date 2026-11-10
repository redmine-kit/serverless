# AGENTS.md

Guidelines for people and coding agents working in this repository. See [README.md](README.md) for an overview and [docs/](docs/README.md) for the design.

## What this project does

It runs the latest Redmine on AWS Lambda (Event Functions), with RDS for PostgreSQL as the database and S3 for attachments. It is in early development: the image, the infrastructure templates and the deploy commands are built and tested on LocalStack; it has not run on AWS yet.

## Rules

- **Plugins and themes:** no third-party plugins, and Redmine's default themes only. Extensions go in the project's own plugins, each developed in its own repository: [`redmine_serverless`](https://github.com/redmine-kit/redmine_serverless) (running on Lambda), [`redmine_serverless_s3`](https://github.com/redmine-kit/redmine_serverless_s3) (attachments in S3) and [`redmine_serverless_ses`](https://github.com/redmine-kit/redmine_serverless_ses) (mail through SES); Redmine's own files are not edited. Only the settings needed before plugins load (loading SSM, cache, jobs) go in configuration files.
- **Replaced code:** when Redmine code is replaced, update the table of [replaced code](https://github.com/redmine-kit/redmine_serverless_s3/blob/main/docs/attachments.md#replaced-code) in the plugin repository. When upgrading Redmine, check that the original code in that table has not changed.
- **Tests:** replaced and added code has tests. The test plan is in [docs/testing.md](docs/testing.md). Tests run with `bin/test`; changes that do not pass are neither committed nor deployed.
- **No fixed names:** AWS resource names, SSM paths and tags are derived from the instance name (`instance` in `redmine.json`, default `redmine`), so that several Redmines can run in one account ([docs/deploy-config.md](docs/deploy-config.md)).
- **Commands in `bin/`:** `bin/rake` and `bin/rails` act on the deployed Redmine and are not for local tests. There is no Makefile; commands used locally and in CI are scripts in `bin/`.
- **Keep digests SHA256:** attachment tokens, ETags, thumbnails and the sharing of identical content rely on them.
- **No secrets in the repository:** secrets such as `SECRET_KEY_BASE` go in SSM Parameter Store under `/<instance>/env/` (the database password too), never in this repository or in Lambda environment variables.
- **Security:** when a change affects protection (permissions, entry points, WAF, logs, retention periods, secrets), update [docs/security.md](docs/security.md) too. A change that weakens protection states the reason and the remaining risk.
- **Pin by digest:** the base image and Lambda Web Adapter are referenced by digest, not by tag. Downloads of Redmine and Pandoc are checked against their SHA256.

## Documentation

- **Two languages.** English is the source (`README.md`, `docs/`); the Japanese translation is `README.ja.md` and `docs/ja/`, with the same file names. Change both together.
- **Layout.** The READMEs stay short. The details go in `docs/`, published at https://redmine-kit.github.io/serverless/ with [redmine-kit/docs-skeleton](https://github.com/redmine-kit/docs-skeleton). `docs/README.md` is the home page and links every page; each page starts with a `#` heading; links between pages point to the `.md` files.
- **Anchors in Japanese.** Put `<a id="..."></a>` with the English heading's anchor before each Japanese heading, so that links work in both languages.
- **Facts.** State only what has been checked, with the date and the source ([docs/sources.md](docs/sources.md)). Mark what has not been checked yet. Keep decisions and proposals apart, and move a proposal to the decisions with the date it was decided.
- **Diagrams** are Mermaid, without colors or themes.
- **Japanese wording.** Plain, precise Japanese. Keep established technical terms. Do not use "版" for a version, and write "通知" rather than the noun "知らせ".

## Commits

- English, imperative mood, 72 characters or fewer in the first line, no trailing period. Explain the reason after a blank line when the first line does not show it.
- One purpose per commit.
- Do not rewrite pushed history (`--amend`, rebase, force push).
