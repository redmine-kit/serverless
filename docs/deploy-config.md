# Deployment configuration

This design uses one configuration file for each Redmine you set up, and the same deployment command to set it up. One AWS account can hold any number of Redmine instances. The configuration is the same whether you set up a single one for yourself or manage many together.

## Approach

- **One configuration file per Redmine:** For each Redmine you set up (called an "instance" in this project), write one configuration file, `redmine.json`.
- **Names come from the instance name:** AWS resource names, SSM paths and tags are all derived from the instance name (`instance`). No fixed names are used, so any number of instances in the same account do not collide.
- **The default is `redmine`:** If no instance name is given, it is `redmine`. When an account holds only one Redmine (for example, when accounts are split per tenant or purpose), you do not need to set it. Give a distinct name only when you set up a second one in the same account.
- **Secrets are not written in the file:** `SECRET_KEY_BASE` and the database password are created by the deployment command when the instance is first set up, and stored in SSM Parameter Store. It is not written in the configuration file.
- **Redmine settings in the same file:** The Redmine administration settings (host name, default language, etc.) and the initial values of plugin settings can also be written in the same file.

## Names derived from the instance name

| Resource | Name |
| --- | --- |
| Lambda functions | `<instance>-web`, `<instance>-worker`, `<instance>-task` |
| SSM Parameter Store | `/<instance>/env/…` |
| S3 buckets | `<instance>-files-<account ID>-<Region>`; `-assets-` and `-mail-` follow the same pattern |
| SQS queues | `<instance>-jobs`, `<instance>-jobs-dlq`, `<instance>-task-failures` (destination for failed invocations from SES) |
| Database | `<instance>` (the RDS instance identifier) |
| Attachments through CloudFront | Behaviors on the instance's own distribution (no second distribution); the trusted key group `<instance>-attachments`, whose private key is a SecureString under `/<instance>/env/` |
| CloudFormation stacks | `<instance>` (per instance), `<instance>-edge` (per instance; the CloudFront certificate in us-east-1), `redmine-shared` (shared base; below), `redmine-shared-edge` (shared base; Lambda@Edge in us-east-1) |
| Tags | Every resource gets `redmine:instance=<instance>`. Cost can be viewed per instance |

Names in other pages (`redmine-web`, the stack `redmine`, etc.) assume the default instance name `redmine`.

## Shared base and per-instance resources

When several instances are set up in the same account, resources that can be combined into one go in the shared base (CloudFormation stack `redmine-shared`).

| Location | Resources | Reason |
| --- | --- | --- |
| Shared base | ECR repository | Reuse images of the same version across instances |
| Shared base (us-east-1) | Lambda@Edge function `redmine-body-hash` (stack `redmine-shared-edge`) | Lambda@Edge functions must be created in us-east-1. The same code is reused across instances ([lambda.md](lambda.md#function-that-adds-the-body-hash-lambdaedge)) |
| Shared base | VPC, private subnets, the S3 gateway endpoint, and VPC endpoints or a NAT instance (`network.shared`) | The endpoints and the NAT instance have a fixed monthly cost, so instances share them ([rds.md](rds.md#routes-out-of-the-vpc)) |
| Shared base | SES receipt rule set | A Region has only one active rule set. Each instance adds its rules to the set ([mail.md](mail.md#receipt-rules)) |
| Per instance | Lambda functions, RDS instance, security groups, S3 buckets, SQS queues, CloudFront, DNS records, SES identities, SSM parameters, alarms | Do not mix an instance's data and permissions with other instances |

- **When you set up only one:** Set up one shared base and one instance. The steps are the same.
- **What goes in us-east-1:** Besides the Lambda@Edge function, the CloudFront certificate (ACM) is also created in us-east-1 (a CloudFront rule). Certificates are per instance, in the us-east-1 stack `<instance>-edge`.
- **VPC:** Each instance's Lambda functions and RDS instance go into the shared private subnets, with security groups of their own. With `network.shared` set to `false`, an instance gets a VPC of its own instead ([rds.md](rds.md)).

## Fields of `redmine.json`

| Field | Required | Default | Description |
| --- | --- | --- | --- |
| `instance` | | `redmine` | Instance name. Lowercase letters, digits and `-`, up to 20 characters. Set it when you set up a second one in the same account |
| `region` | ○ | | Region to set up in |
| `deployRoleArn` | ○ | | The role the deployment command assumes. Points to the role for deploying infrastructure in the target account ([iam.md](iam.md#role-for-deploying-infrastructure)) |
| `domain` | ○ | | Host name for web and email (for example `redmine.example.com`) |
| `dns.mode` | | `route53` | `route53` (put records in a Route 53 hosted zone) or `external` (put the displayed records in another DNS yourself) ([mail.md](mail.md#receiving-domain)) |
| `network.mode` | | `endpoints` | The route out of the VPC: `endpoints` (VPC endpoints; no way out to the internet) or `nat` (a NAT instance; webhooks and external APIs can be reached) ([rds.md](rds.md#which-to-choose)) |
| `network.shared` | | `true` | Whether to use the shared base's network or create one per instance |
| `database.instanceClass` | | `db.t4g.micro` | RDS instance class ([rds.md](rds.md#database)) |
| `database.storageGb` | | 20 | RDS storage (gp3) |
| `lambda.webMemoryMb` | | 2048 | Memory of `redmine-web` |
| `lambda.webReservedConcurrency` | | 10 | Reserved concurrency of `redmine-web` |
| `lambda.workerReservedConcurrency` | | 3 | Reserved concurrency of `redmine-worker`. `redmine-task` is fixed at 2 ([tasks.md](tasks.md#kinds-of-events)) |
| `lambda.warmup` | | `false` | Whether to send warm-up invocations during business hours ([lambda.md](lambda.md#waiting-for-start-up)) |
| `mail.receive` | | `true` | Whether to receive email |
| `mail.perProjectAddresses` | | `false` | Whether to use addresses per project. If `false`, the same as standard Redmine ([mail.md](mail.md#addresses-per-project)) |
| `mail.globalLocalPart` | | `redmine` | The part before `@` of the global address |
| `webhooks` | | `false` | Initial value of Redmine's webhook setting (`webhooks_enabled`). Webhooks work only with `network.mode` set to `nat` ([lambda.md](lambda.md#background-jobs)) |
| `cloudfront.plan` | | `free` | CloudFront pricing plan. `free`, `pro` or `payg` (pay-per-use) ([security.md](security.md#plan-and-cost)) |
| `waf.loginRateLimit` | | 20 | WAF login rate limit (per 5 minutes; [security.md](security.md#rules)) |
| `waf.rateLimit` | | 1000 | WAF overall rate limit (per 5 minutes) |
| `waf.commonRuleSet` | | `count` | Whether the WAF Common Rule Set is `count` (count only) or `block` |
| `waf.commonRuleSetCountOnly` | | `["SizeRestrictions_BODY"]` | Rules that only count even with `block` |
| `cloudfront.webAclArn` | | none | To use a web ACL you prepared yourself. If set, `waf.*` is not used |
| `redmine.version` | | The version in `redmine.lock` | The Redmine version to use. How to check before upgrading is in [upgrade.md](upgrade.md) |
| `image` | | This project's image | To use a derived image built by the adopter (with added themes or plugins), its location and digest (`image.repository`, `image.digest`). How to build a derived image is in [architecture.md](architecture.md#derived-images) |
| `redmine.settings` | | none | Values of Redmine administration settings (`host_name`, `default_language`, `mail_from`, etc.) |
| `redmine.settingsMode` | | `initial` | `initial` (set only when first set up; can be changed on the page afterwards) or `enforce` (set again on every deployment) |
| `redmine.pluginSettings` | | none | Setting values for the plugins, by plugin name (`redmine_serverless`, `redmine_serverless_s3`, `redmine_serverless_ses`, `redmine_serverless_sqs`) |
| `logs.retentionDays` | | 90 | CloudWatch Logs retention in days (including Lambda@Edge log groups) |
| `retention.recordsDays` | | 90 | Days to keep the plugin's records (received email, failed jobs) |
| `retention.mailDays` | | 30 | Days to keep email in the mail bucket (`processed/` and `inbound/`) |
| `retention.noncurrentVersionDays` | | 30 | Days to keep old versions of attachments |
| `retention.backupDays` | | 7 | Days to keep RDS automated backups (up to 35). Backups up to the provisioned storage are free ([rds.md](rds.md#settings)) |
| `alarms.snsTopicArn` | | none | SNS topic to send alarms to |
| `tags` | | none | Tags added to every resource |

The list of retention periods is in [security.md](security.md#retention-periods).

The shape of the configuration file is defined by a JSON Schema (`schema/redmine.schema.json`), which the deployment command checks first.

### Example

```json
{
  "region": "ap-northeast-1",
  "deployRoleArn": "arn:aws:iam::111122223333:role/redmine-infra-deploy",
  "domain": "redmine.example.com",
  "network": { "mode": "endpoints" },
  "mail": { "receive": true, "perProjectAddresses": true },
  "redmine": {
    "settings": {
      "app_title": "Redmine",
      "default_language": "ja",
      "mail_from": "redmine@redmine.example.com"
    }
  }
}
```

## Deployment commands

```sh
bin/deploy path/to/redmine.json --dry-run   # only show what will change
bin/deploy path/to/redmine.json             # set up or update
```

| Step | What it does |
| --- | --- |
| 1 | Check the configuration file against the JSON Schema |
| 2 | Create the shared base stacks (`redmine-shared` and `redmine-shared-edge` in us-east-1) if they do not exist, or update them if they do |
| 3 | Create the secrets in SSM if they do not exist (leave them unchanged if they do), including the private key of the CloudFront key pair for attachment URLs; its public key goes into the instance stack. This comes before the instance stack, because RDS reads the database password from SSM when it is created |
| 4 | Create or update the instance stacks (`<instance>` and `<instance>-edge` in us-east-1). Reapply the retention period to the log groups Lambda@Edge created in each Region ([security.md](security.md#retention-periods)) |
| 5 | Put the image of the version to use into that account's ECR (Lambda can use only images in ECR in the same Region) |
| 6 | Sync assets to S3 |
| 7 | Update the image of `redmine-task` and run `db:migrate` and `redmine:plugins:migrate`. On the first setup, they create the schema in the empty database |
| 8 | When setting up for the first time, load the initial data in `redmine-task` (`redmine:load_default_data`; the language is `redmine.settings.default_language`, English if not set) |
| 9 | Update the images of `redmine-web` and `redmine-worker` |
| 10 | Apply Redmine and plugin settings (according to `redmine.settingsMode`; rake task `redmine_serverless:apply_settings`) |
| 11 | Checks after deployment ([testing.md](testing.md#checks-after-deployment)) |

- **Two ways to run it:** All steps run with the role for deploying infrastructure (an SSO administrator, or a GitHub Environment that requires approval). To update only the Redmine image, `bin/deploy --code-only` runs only steps 5–7, 9 and 11 with the GitHub Actions role for deploying code ([iam.md](iam.md)).
- **Maintenance page:** Writes can be stopped by setting the reserved concurrency of `redmine-web` and `redmine-worker` to 0 (for example, during an incident; [security.md](security.md)). While the reserved concurrency of `redmine-web` is 0, the function URL rejects requests. CloudFront's custom error response settings return the maintenance page from S3 in that case.
- **No changes for the same configuration:** If the configuration file and the image have not changed, nothing is changed.
- **When setting up many instances:** Repeat the same command for each instance. The order (starting with a small instance used for trying things first) is decided by the adopter.
- **Images:** This project's CI builds an image for each Redmine version and publishes it to the GitHub Packages container registry (`ghcr.io`) (proposal; [architecture.md](architecture.md#distribution)). The deployment command pulls that image by digest and puts it in the target account's ECR.

### Templates

The stacks are written in CloudFormation in `infra/`. `bin/lint` checks them with cfn-lint.

| File | Stack | Contents now |
| --- | --- | --- |
| `infra/shared.yaml` | `redmine-shared` | The ECR repository, the VPC with two private subnets in two AZs (no internet gateway), the S3 gateway endpoint, and the SSM and SQS interface endpoints in one AZ with `network.mode` `endpoints` |
| `infra/instance.yaml` | `<instance>` | RDS for PostgreSQL (TLS required by the parameter group, encrypted, deletion protection, automated backups), the `REDMINE_DB_HOST` parameter in SSM, the job queue and its dead-letter queue, `redmine-web` with its function URL (IAM authentication) and `redmine-task` in the private subnets, their execution roles and log groups |

- **Secrets:** CloudFormation cannot create SecureString parameters. `bin/deploy` creates `SECRET_KEY_BASE` and `REDMINE_DB_PASSWORD` (step 3), and the RDS instance takes the password with a dynamic reference (`{{resolve:ssm-secure:/<instance>/env/REDMINE_DB_PASSWORD}}`).
- **The image:** The instance stack takes the image in the account's ECR by digest (`ImageUri`).
- **The PostgreSQL version:** `DbMajorVersion` has no default. The major version is checked against the versions RDS offers when the instance is created ([rds.md](rds.md#database)).
- **Added in later stages:** `redmine-worker` and its SQS event source (jobs and mail sending), CloudFront, the S3 buckets and Lambda@Edge, SES, the NAT instance (`network.mode` `nat`), alarms, the us-east-1 stacks and `bin/deploy` itself ([architecture.md](architecture.md#order-of-work)).

## To verify

- Whether CloudFormation can build the layout where the SES receipt rule set is in the shared base and instance stacks add rules to it
- Whether the RDS instance accepts the password through the `ssm-secure` dynamic reference on creation and on updates (it is a property that supports it in the CloudFormation documentation; not tried yet)
- How to copy an image from `ghcr.io` to the target account's ECR without changing its digest (including whether ECR pull through cache can be used with `ghcr.io`)
