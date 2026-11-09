# Serverless

Design documentation for Serverless. It describes a design that runs the latest Redmine on AWS Lambda, with RDS for PostgreSQL as the database and S3 for attachments.

## Find by purpose

| What you want to do | Page |
| --- | --- |
| Understand the overall architecture, the decisions and the open questions | [architecture.md](architecture.md) |
| Build the image and the Lambda settings | [lambda.md](lambda.md) |
| Build storing and retrieving attachments | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html) |
| Create the database and the VPC | [rds.md](rds.md) |
| Run migrations or rake | [tasks.md](tasks.md) |
| Send and receive mail | [mail.md](mail.md) |
| Build the administration pages | [admin.md](https://redmine-kit.github.io/redmine_serverless/admin.html) |
| Decide permissions | [iam.md](iam.md) |
| Learn about security protections, WAF, log retention and incident procedures | [security.md](security.md) |
| Set up the AWS-side security settings (GuardDuty, CloudTrail, Access Analyzer and so on) | [aws-security.md](aws-security.md) |
| Write the configuration and deploy, set up several instances | [deploy-config.md](deploy-config.md) |
| Connect AI features | [ai.md](ai.md) |
| Decide on the cache and tune it | [cache.md](cache.md) |
| Understand and set sessions | [session.md](session.md) |
| See the monthly cost | [cost.md](cost.md) |
| Compare with ordinary servers | [comparison.md](comparison.md) |
| Write tests, build CI | [testing.md](testing.md) |
| Upgrade Redmine | [upgrade.md](upgrade.md) |
| Move data from an older Redmine | [migration.md](migration.md) |

## Pages

| Page | Contents |
| --- | --- |
| [architecture.md](architecture.md) | Overall architecture, decisions and their reasons, the project's own plugins, open questions |
| [lambda.md](lambda.md) | Event Functions, the container image, Lambda Web Adapter, the read-only file system, SSM Parameter Store, Rails settings, jobs with SQS, CloudFront and assets |
| [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html) | Design based on the S3 plugins, bucket layout, uploads and downloads through CloudFront with signed URLs, the sandbox CSP, the `/tmp` cache |
| [rds.md](rds.md) | The database (RDS for PostgreSQL) and the VPC: settings, routes out of the VPC (VPC endpoints or a NAT instance), access through Systems Manager, cost |
| [tasks.md](tasks.md) | How one image switches between three roles. Migrations, arbitrary rake tasks, `rails runner` and mail import in the task function |
| [mail.md](mail.md) | Mail sent from Rails ActionMailer through the SES API, and mail received by SES and imported |
| [admin.md](https://redmine-kit.github.io/redmine_serverless/admin.html) | Administration pages added by the plugins, as tabs under one shared "Serverless" menu item (status and connections in `redmine_serverless`; jobs in `redmine_serverless_sqs`; mail sending and receiving in `redmine_serverless_ses`; S3 attachments in `redmine_serverless_s3`) |
| [iam.md](iam.md) | Execution roles, resource-based policies, the deployment role, permissions for people |
| [security.md](security.md) | What to protect, threats and protections, the entry point and AWS WAF, Redmine settings, data protection, retention periods, logs, the supply chain, remaining risks, incidents |
| [aws-security.md](aws-security.md) | The AWS-side security settings: what each protects, who sets it up, cost, defaults (GuardDuty and its malware scan of uploads, CloudTrail, IAM Access Analyzer, Security Hub, Config, Block Public Access, EBS encryption, the root user, budgets) |
| [deploy-config.md](deploy-config.md) | The configuration file for each Redmine (`redmine.json`), naming rules, the shared foundation, deployment commands |
| [ai.md](ai.md) | Integration with AI features from a separate project (Redmine's standard REST API, OAuth, webhooks) and safety rules |
| [cache.md](cache.md) | What Redmine caches, the cache in each environment, what can be tuned, the cost of a shared cache (ElastiCache for Valkey) |
| [session.md](session.md) | Sessions in encrypted cookies checked against tokens in the database, the session settings, the `Secure` attribute |
| [cost.md](cost.md) | Monthly cost estimate in the Tokyo Region |
| [comparison.md](comparison.md) | Comparison with ordinary servers (EC2, Lightsail, ECS Fargate) on price, security and operations |
| [testing.md](testing.md) | Kinds of tests, plugin and Redmine tests, image tests, checks after deployment, the CI order |
| [upgrade.md](upgrade.md) | How to check a Redmine upgrade (sorting the new migrations, running them on a test database, keeping records) |
| [migration.md](migration.md) | Migrating from an older Redmine running elsewhere. How to move from MySQL |
| [sources.md](sources.md) | Sources consulted and the dates they were checked |

## Sponsors

<Sponsors><a href="https://www.keyselect.co.jp/">KEY SELECT</a> <a href="https://localstack.cloud">LocalStack</a></Sponsors>

## License

Serverless is released under the GNU General Public License, version 2 or (at your option) any later version. See [LICENSE](../LICENSE). An unofficial project for Redmine.
