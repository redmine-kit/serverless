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
| Lambda functions | `<instance>-web`<br>`<instance>-worker`<br>`<instance>-task` |
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

To set up only one Redmine, set up one shared base and one instance; the steps are the same.

Besides the Lambda@Edge function, the CloudFront certificate (ACM) is also created in us-east-1, because CloudFront requires it there. Certificates are per instance, in the us-east-1 stack `<instance>-edge`.

Each instance's Lambda functions and RDS instance go into the shared private subnets, with security groups of their own. With `network.shared` set to `false`, an instance gets a VPC of its own instead ([rds.md](rds.md)).

## Fields of `redmine.json`

| Field | Required | Default | Description |
| --- | --- | --- | --- |
| `instance` | | `redmine` | Instance name. Lowercase letters, digits and `-`, up to 20 characters. Set it when you set up a second one in the same account |
| `region` | ○ | | Region to set up in |
| `deployRoleArn` | ○ | | The role the deployment command assumes. Points to the role for deploying infrastructure in the target account ([iam.md](iam.md#role-for-deploying-infrastructure)) |
| `domain` | ○ | | Host name for web and email (for example `redmine.example.com`) |
| `dns.mode` | | `route53` | `route53` (put records in a Route 53 hosted zone) or `external` (put the displayed records in another DNS yourself) ([mail.md](mail.md#receiving-domain)) |
| `dns.hostedZoneId` | With `route53` | | The Route 53 hosted zone of the domain |
| `account.*` | | | The account stack, used only by `bin/deploy --account`: the roles (`ssoPermissionSet`, default `AdministratorAccess`; `githubRepository`, `owner/repository`, without it no GitHub Actions roles; `githubInfraEnvironment`, default `infrastructure`; `githubCodeEnvironment`, default `production`; `githubOidcProviderArn`, when the account already has the GitHub OIDC provider; [iam.md](iam.md#account-roles)), and the account's security settings (`cloudTrail` and `accessAnalyzer`, by default created only when the account has none; `trailDays`, default 365; `unusedAccessAnalyzer`, default `false`; [aws-security.md](aws-security.md)) |
| `network.mode` | | `endpoints` | The route out of the VPC: `endpoints` (VPC endpoints; no way out to the internet) or `nat` (a NAT instance; webhooks and external APIs can be reached) ([rds.md](rds.md#which-to-choose)) |
| `network.shared` | | `true` | Whether to use the shared base's network. Only `true` for now; a VPC per instance is not built |
| `database.majorVersion` | ○ | | The PostgreSQL major version, for example `"17"`. Checked against the versions RDS offers when the instance is created ([rds.md](rds.md#database)) |
| `database.instanceClass` | | `db.t4g.micro` | RDS instance class |
| `database.storageGb` | | 20 | RDS storage (gp3) |
| `lambda.webMemoryMb` | | 2048 | Memory of `redmine-web` |
| `lambda.webReservedConcurrency` | | 10 | Reserved concurrency of `redmine-web` |
| `lambda.workerReservedConcurrency` | | 3 | Reserved concurrency of `redmine-worker`. `redmine-task` is fixed at 2 ([tasks.md](tasks.md#kinds-of-events)) |
| `lambda.warmup` | | `false` | Whether to send warm-up invocations during business hours ([lambda.md](lambda.md#waiting-for-start-up)). Only `false` for now |
| `uploads.malwareScan` | | `true` | Whether GuardDuty Malware Protection for S3 scans uploads and imports before Redmine reads them ([aws-security.md](aws-security.md#malware-protection-for-s3)). `false` turns it off |
| `uploads.maxBytes` | | 104857600 (100 MB) | The largest attachment. The CloudFront Function on `/tmp/*` rejects larger uploads (`/tmp/incoming/`) with 413, and step 10 sets Redmine's maximum attachment size (`attachment_max_size`, in KB) to the same limit unless `redmine.settings` sets it |
| `mail.receive` | | `true` | Whether to receive email |
| `mail.perProjectAddresses` | | `false` | Whether to use addresses per project. If `false`, the same as standard Redmine ([mail.md](mail.md#addresses-per-project)) |
| `mail.globalLocalPart` | | `redmine` | The part before `@` of the global address |
| `webhooks` | | `false` | Initial value of Redmine's webhook setting (`webhooks_enabled`). Webhooks work only with `network.mode` set to `nat` ([lambda.md](lambda.md#background-jobs)) |
| `cloudfront.plan` | | `free` | CloudFront pricing plan. `free`, `pro` or `payg` (pay-per-use) ([security.md](security.md#plan-and-cost)) |
| `cloudfront.webAclArn` | | none | To use a web ACL you prepared yourself (in us-east-1). If set, `waf.*` is not used |
| `waf.loginRateLimit` | | 20 | WAF login rate limit (per 5 minutes; [security.md](security.md#rules)) |
| `waf.rateLimit` | | 1000 | WAF overall rate limit (per 5 minutes) |
| `waf.commonRuleSet` | | `count` | Whether the WAF Common Rule Set is `count` (count only) or `block` |
| `waf.commonRuleSetCountOnly` | | `["SizeRestrictions_BODY"]` | The rule that only counts even with `block` (one rule) |
| `image.repository` | | `ghcr.io/redmine-kit/serverless` | The image to use. A derived image that the adopter builds is set here ([architecture.md](architecture.md#derived-images)). The image decides the Redmine version; how to check before upgrading is in [upgrade.md](upgrade.md) |
| `image.digest` | With `image.repository` | The digest of the tag with the Redmine version at that moment | The image's digest (`sha256:…`). Without it, `bin/deploy` uses the current digest of the tag with the Redmine version this checkout builds (for example `7.0.3`, from `ARG REDMINE_VERSION` in `image/Dockerfile`) and shows it so that it can be pinned |
| `image.plugins` | | none | Plugins to add to the image. `bin/deploy` builds a derived image with them on top of the image above ("Adding plugins and themes" below). Each entry has `name` (the plugin's directory under `plugins/`, which is its id) and one source: `version` (the gem `name` at that exact version, from RubyGems or from `source`, such as `https://rubygems.pkg.github.com/<owner>`), `git` with `ref` (an HTTPS repository at a tag or a full commit hash), or `path` (a directory relative to `redmine.json`) |
| `image.themes` | | none | Themes to add, into `themes/<name>/`. Each entry has `name` and `git` with `ref`, or `path` |
| `redmine.settings` | | none | Values of Redmine administration settings (`host_name`, `default_language`, `mail_from`, etc.) |
| `redmine.settingsMode` | | `initial` | `initial` (set only the settings not stored yet; can be changed on the page afterwards) or `enforce` (set again on every deployment) |
| `redmine.pluginSettings` | | none | Setting values for the plugins, by plugin name (`redmine_serverless`, `redmine_serverless_s3`, `redmine_serverless_ses`, `redmine_serverless_sqs`). They are merged into the plugin's stored settings. For example, `{"redmine_serverless_ses": {"import_spam": "0", "import_without_dmarc_pass": "0"}}` keeps spam and email that fails DMARC out (the defaults; [receiving.md](https://redmine-kit.github.io/redmine_serverless_ses/receiving.html#spoofing-and-spam)) |
| `costExplorer.enabled` | | `false` | For an image that adds the plugin `redmine_serverless_costexplorer` (a derived image; Serverless's image does not include it): whether the plugin shows the account's costs from Cost Explorer on the administration pages. `redmine-web` and `redmine-task` get `REDMINE_COSTEXPLORER_ENABLED`, `redmine-task` gets `ce:GetCostAndUsage` and `ce:GetCostForecast`, and `redmine_serverless_costexplorer:refresh` runs once a day (the plugin's only fetch) ([tasks.md](tasks.md#scheduled-runs)). Cost Explorer's API (`ce.us-east-1.amazonaws.com`) is reached through the NAT instance (`network.mode` `nat`); the PrivateLink guide lists an interface endpoint `com.amazonaws.<region>.ce`, but whether it can be used from a VPC in another Region is unverified ([Redmine Serverless Cost Explorer](https://redmine-kit.github.io/redmine_serverless_costexplorer/)). Each request costs USD 0.01 ([cost.md](cost.md#what-adds-cost)) |
| `costExplorer.allocationTag` | | empty | A cost allocation tag (for example `redmine:instance`) to show the costs of this instance only; `redmine-task` gets it as `REDMINE_COSTEXPLORER_TAG_KEY`. The tag must be activated as a cost allocation tag in the Billing console |
| `schedule.timezone` | | `UTC` | The time zone of the scheduled rake ([tasks.md](tasks.md#scheduled-runs)) |
| `schedule.sendReminders` | | `false` | Whether to send the reminder mails (`redmine:send_reminders`) on weekday mornings |
| `logs.retentionDays` | | 90 | CloudWatch Logs retention in days (including Lambda@Edge log groups) |
| `retention.recordsDays` | | 90 | Days to keep the plugin's records (received email, failed jobs) |
| `retention.mailDays` | | 30 | Days to keep email in the mail bucket (`processed/` and `inbound/`) |
| `retention.noncurrentVersionDays` | | 30 | Days to keep old versions of attachments |
| `retention.backupDays` | | 7 | Days to keep RDS automated backups (up to 35). Backups up to the provisioned storage are free ([rds.md](rds.md#settings)) |
| `alarms.snsTopicArn` | | none | SNS topic to send alarms to |
| `tags` | | none | Tags added to every stack, and so to the resources |

The schema already checks `mail.perProjectAddresses`, `mail.globalLocalPart`, `webhooks`, `cloudfront.plan` and `retention.recordsDays`, but the stacks do not use them yet. They take effect with the plugins' settings and the CloudFront plan, which come later.

The list of retention periods is in [security.md](security.md#retention-periods).

The shape of the configuration file is defined by a JSON Schema (`schema/redmine.schema.json`), which the deployment command checks first.

### Example

```json
{
  "region": "ap-northeast-1",
  "deployRoleArn": "arn:aws:iam::111122223333:role/redmine-infra-deploy",
  "domain": "redmine.example.com",
  "dns": { "hostedZoneId": "Z0123456789ABCDEFGHIJ" },
  "database": { "majorVersion": "17" },
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

### Adding plugins and themes

Plugins and themes are added per instance in `image.plugins` and `image.themes`, each at a fixed version: a gem at its exact version, a Git repository at a tag or a commit, or a directory next to `redmine.json`. A branch is not taken, so the same configuration builds the same plugins every time.

```json
{
  "image": {
    "plugins": [
      { "name": "redmine_example", "version": "1.2.0" },
      { "name": "redmine_example_private", "version": "0.3.1", "source": "https://rubygems.pkg.github.com/example" },
      { "name": "redmine_example_git", "git": "https://github.com/example/redmine_example_git.git", "ref": "v2.0.1" },
      { "name": "redmine_example_local", "path": "plugins/redmine_example_local" }
    ],
    "themes": [
      { "name": "example", "git": "https://github.com/example/redmine-theme-example.git", "ref": "3f2c9a1e5b7d4c6a8e0f1b2d3c4e5f6a7b8c9d0e" },
      { "name": "example-local", "path": "themes/example-local" }
    ]
  },
  "redmine": {
    "pluginSettings": { "redmine_example": { "enabled": "1" } }
  }
}
```

When either list is not empty, `bin/deploy` builds a derived image before the steps below, on the machine where it runs. The base is the image of `image.repository` and `image.digest` (or the tag with the Redmine version, as without the lists). `bin/build-derived-image` puts the plugins in `plugins/` and the themes in `themes/`, adds the plugin gems and the gems in the plugins' Gemfiles to the base image's lock (a version already locked changes only when an added gem needs a newer one), links the plugin gems into `plugins/` as the base image does, and rebuilds the assets (`assets:precompile`). Then the image goes through the image tests ([testing.md](testing.md#image-tests)) with checks for the added plugins and themes, and step 5 pushes it to the account's ECR. Steps 6 to 9 then upload the assets with the themes' to S3, run the added plugins' migrations (`redmine:plugins:migrate`) and give the image to the functions, and `redmine.pluginSettings` sets the added plugins' settings as it does for the others.

The build fetches a Git source with BuildKit at `refs/tags/<ref>` or at the commit, so only public repositories over HTTPS can be fetched; a private plugin is checked out beside `redmine.json` and given as `path`, or published as a gem. Bundler's credential for GitHub Packages is the environment variable `BUNDLE_RUBYGEMS__PKG__GITHUB__COM` (`x-access-token:<token with read:packages>`), or the `gh` login when `gh` is installed; it goes to the build as a BuildKit secret and is stored neither in a layer nor in `redmine.json`. Without the lists, nothing is built and the image is copied as before.

To build and test a derived image without deploying, run the same scripts:

```sh
bin/build-derived-image path/to/redmine.json ghcr.io/redmine-kit/serverless@sha256:<digest> redmine-derived:local
bin/test-image redmine-derived:local path/to/redmine.json
```

When `image.repository` names an image built on top of this project's with tests of its own, `DERIVED_IMAGE_TESTS` names the command that tests the derived image in place of `bin/test-image`; it gets the image and `redmine.json` as its arguments.

Writing your own Dockerfile on top of this project's image and setting it in `image.repository` stays possible, for what the lists cannot express ([architecture.md](architecture.md#derived-images)).

## Deployment commands

`bin/deploy` needs only Docker. It builds a tools image (`deploy/Dockerfile`: the AWS CLI, jq, OpenSSL, crane and check-jsonschema, at pinned versions; the Python packages with hashes) and runs `deploy/deploy.sh` in it. AWS credentials come from the `AWS_*` environment variables or from `~/.aws` (read-only). With `image.plugins` or `image.themes`, it also needs Docker Buildx, jq and curl, for building and testing the derived image.

```sh
bin/deploy path/to/redmine.json --account    # once per account, as an administrator
bin/deploy path/to/redmine.json --dry-run    # only show what will change
bin/deploy path/to/redmine.json              # set up or update
bin/deploy path/to/redmine.json --code-only  # update only the image
```

| Step | What it does |
| --- | --- |
| 1 | Check the configuration file against the JSON Schema, then assume `deployRoleArn` (unless the credentials are already that role's) |
| 2 | Create or update the shared base stacks (`redmine-shared`, and `redmine-shared-edge` in us-east-1). With `mail.receive`, make the shared receipt rule set the active one |
| 3 | Create the secrets in SSM if they do not exist; existing ones are left unchanged ("Secrets" below). This comes before the instance stack, because RDS reads the database password from SSM when it is created |
| 4 | Create or update `<instance>-edge` in us-east-1 (the certificate and the web ACL). Apply `logs.retentionDays` to the log groups that Lambda@Edge has created in each Region ([security.md](security.md#retention-periods)) |
| 5 | Copy the image by digest into the account's ECR with crane (Lambda can use only images in ECR in the same Region), or push the derived image of `image.plugins` and `image.themes`, built and tested before step 1. The repository's tags are immutable, so the tag is made from the digest (`sha256-<hex>`). An image already there is not copied again |
| 6 | Sync the assets from the image to S3 (`/assets/`), with the maintenance page (`deploy/maintenance.html`). Old files stay for pages still open in browsers |
| 7 | The first time, create the instance stack `<instance>` with the image. Later, update the stack keeping the image `redmine-task` runs now, then give `redmine-task` the new image. Then run `db:migrate` and `redmine:plugins:migrate` in `redmine-task` |
| 8 | The first time, load the default data in `redmine-task` (`redmine:load_default_data`; the language is `redmine.settings.default_language`, English if not set) |
| 9 | Give `redmine-web` and `redmine-worker` the new image, through the stack so that the stack holds it |
| 10 | Apply Redmine and plugin settings (according to `redmine.settingsMode`) with `rails runner` in `redmine-task`. The values go in as hex-encoded JSON, so no quoting reaches Ruby |
| 11 | Checks after deployment: `/login` returns 200 with `Strict-Transport-Security`, and `/files/` without a signature returns 403. The requests go to the distribution's own name with the domain's host name, so they do not wait for DNS ([testing.md](testing.md#checks-after-deployment)). With `dns.mode` `external`, show the records to add |

### Options

| Option | What it does |
| --- | --- |
| `--account` | Applies `infra/account.yaml` (the stack `redmine-account`) with the administrator's own credentials, because the role for deploying and the CloudFormation service role do not exist before it. Run it once per account, before the first deployment |
| `--dry-run` | Steps 1–4 and the instance stack make change sets, show them and delete them; a stack that would be created is deleted again. Nothing else changes: no secrets, image, assets or invocations (only a template too large to pass inline is uploaded to the templates bucket). A derived image is still built and tested on the local machine, so a plugin that does not build shows here |
| `--code-only` | Steps 5–7, 9 and 11, without stack changes, with the credentials given (for example, the role for deploying code in GitHub Actions; [iam.md](iam.md#role-for-deploying-code-github-actions)). The functions are updated directly. It needs a deployed instance |

### How the steps behave

Web and worker get the new image only after the migrations, so they never run code newer than the database. When a migration fails, the deployment stops there and web and worker keep their image.

Every stack is applied through change sets with the service role `redmine-cfn-exec`; the role for deploying cannot create resources itself ([iam.md](iam.md#role-for-deploying-infrastructure)). Running the command again with the same configuration changes nothing: a change set without changes is deleted and the stack is left as it is, the image is not copied again, and the migrations do nothing. A derived image is the exception when Docker's build cache is gone (another machine, or a pruned cache): it is built again with a new digest, and the functions get it.

This project's CI publishes the image to the GitHub Packages container registry (`ghcr.io`) ([architecture.md](architecture.md#distribution)). The deployment command copies it by digest, so the image in ECR has the same digest.

To set up many instances, repeat the same command for each one. The adopter decides the order, for example starting with a small instance used for trying things.

### Maintenance page

Writes can be stopped by setting the reserved concurrency of `redmine-web` and `redmine-worker` to 0, for example during an incident ([security.md](security.md)). CloudFront returns the maintenance page from S3 (`/assets/maintenance.html`) for 502, 503 and 504 from the function URL. While the reserved concurrency of `redmine-web` is 0, however, the function URL answers 429, and CloudFront's custom error responses cannot replace a 429, so browsers get that 429 ("To verify" below).

### Secrets

CloudFormation cannot create SecureString parameters, so `bin/deploy` creates them in step 3. A value is never printed and never passed on a command line: it goes to the AWS CLI as JSON on standard input.

| Parameter | Type | Value |
| --- | --- | --- |
| `/<instance>/env/SECRET_KEY_BASE` | SecureString | 64 random bytes in hex |
| `/<instance>/env/REDMINE_DB_PASSWORD` | SecureString | 32 random bytes in hex (no characters that RDS refuses). RDS takes it with a dynamic reference (`{{resolve:ssm-secure:…}}`) |
| `/<instance>/env/REDMINE_CLOUDFRONT_PRIVATE_KEY` | SecureString | The private key (RSA 2048) of the key pair for signed attachment URLs |
| `/<instance>/deploy/CLOUDFRONT_PUBLIC_KEY` | String | Its public key, which the instance stack registers in CloudFront (the key group `<instance>-attachments`). It is not under `env/`, so the functions do not load it |

### Templates

The stacks are written in CloudFormation in `infra/`. `bin/lint` checks them with cfn-lint.

| File | Stack | Contents |
| --- | --- | --- |
| `infra/account.yaml` | `redmine-account` | The permissions boundary `redmine-boundary`, the CloudFormation service role `redmine-cfn-exec`, the roles `redmine-infra-deploy` and `redmine-github-deploy`, and the GitHub OIDC provider if needed ([iam.md](iam.md#account-roles)); the CloudTrail trail and the IAM Access Analyzers unless the account has them ([aws-security.md](aws-security.md)) |
| `infra/shared.yaml` | `redmine-shared` | The ECR repository, the bucket for templates too large to pass inline, the VPC with two private subnets in two AZs, the S3 gateway endpoint, the shared SES receipt rule set, and the route out: the SSM, SQS and SES interface endpoints in one AZ (`network.mode` `endpoints`), or a NAT instance (`nat`: an internet gateway, a public subnet, and an Auto Scaling group of one instance that takes over an Elastic IP and the route at start; [rds.md](rds.md#setup-2-nat-instance)) |
| `infra/shared-edge.yaml` | `redmine-shared-edge` (us-east-1) | The Lambda@Edge function `redmine-body-hash` (Node.js 24, code inline from `edge/body-hash/index.js`) and its version; a new version is made when the code changes |
| `infra/instance-edge.yaml` | `<instance>-edge` (us-east-1) | The ACM certificate of the domain (DNS validation), and the AWS WAF web ACL unless `cloudfront.webAclArn` is set ([security.md](security.md#rules)) |
| `infra/instance.yaml` | `<instance>` | RDS for PostgreSQL; the attachment, assets and mail buckets; the job queue, its dead-letter queue and the queue of failed task invocations; the three functions, their roles and log groups; the worker's SQS event source; CloudFront with OAC, the body-hash function, the attachment behaviors with signed URLs, the CloudFront Function `<instance>-incoming-size` and the maintenance page; DNS records; the SES identity and receipt rule; the EventBridge Scheduler schedules; alarms; GuardDuty Malware Protection for S3 on `tmp/incoming/` and `imports/` ([aws-security.md](aws-security.md#malware-protection-for-s3)) |

- **The image:** The instance stack takes the image in the account's ECR by digest (`ImageUri`).
- **The PostgreSQL version:** `DbMajorVersion` has no default ([rds.md](rds.md#database)).
- **Roles:** Every role the stacks create has the path `/redmine/` and the permissions boundary `redmine-boundary` ([iam.md](iam.md#account-roles)).

## To verify

- Whether CloudFormation can build the layout where the SES receipt rule set is in the shared base and instance stacks add rules to it
- Whether the RDS instance accepts the password through the `ssm-secure` dynamic reference on creation and on updates (it is a property that supports it in the CloudFormation documentation; not tried yet)
- Whether Lambda runs the image that crane copied from `ghcr.io` (the same digest), and how long the first copy takes
- The whole of `bin/deploy` on a real account: it is tested only against a fake AWS CLI and LocalStack ([testing.md](testing.md#deployment-tests))
- What browsers see while the reserved concurrency of `redmine-web` is 0 (the function URL's 429 through CloudFront), and whether another way to show the maintenance page is needed
