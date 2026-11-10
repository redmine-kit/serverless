# Security

This is the security design of Serverless. It covers what to protect, what can happen, the protections at each layer, the remaining risks, and the steps for an incident. Detailed settings for permissions, networking and the database are in their own pages, which this page links to. The security settings on the AWS side (GuardDuty and the malware scan of uploads, CloudTrail, IAM Access Analyzer and others) are in [aws-security.md](aws-security.md).

The specifications in this page were checked against official information and the Redmine 7.0.3 source as of 2026-11-09. Sources are in [sources.md](sources.md).

## Approach

- **Few ways out of Redmine:** Only CloudFront is reachable from outside. Function URLs cannot be called without an OAC signature, and the database is in private subnets of a VPC with no public access.
- **Small, separate permissions:** Permissions are split per function and per instance, so that one breach does not spread.
- **Fewer secrets:** No AWS access keys are created. The secrets that remain (the database password and `SECRET_KEY_BASE`) are stored as SecureString in SSM Parameter Store.
- **Redmine's built-in protections:** Two-factor authentication, password rules, and permissions and roles use Redmine's standard features. The plugin does not rebuild them.
- **Safe defaults:** The initial values in the configuration file and in Redmine's settings are on the safe side ("Redmine settings" below). To loosen them, the people who use this project decide on a reason and change them.

## What to protect

| What to protect | Where it is | Impact of a leak or damage |
| --- | --- | --- |
| Redmine data (issues, wiki, users, password hashes, API keys) | RDS for PostgreSQL | Business information and user accounts leak |
| Attachments | S3 attachments bucket | Business documents leak |
| Received email | S3 mail bucket (`inbound/`, `processed/`) | Full email contents leak |
| Secrets (`SECRET_KEY_BASE`, the database password) | SSM Parameter Store | Session cookies can be forged. The database can be read and written from inside the VPC |
| AWS permissions | Execution roles, deployment roles, administrators' SSO | AWS resources can be read and written. Cost can be run up |
| Administrator accounts | Redmine and SSO | All data and settings can be changed |

## Threats and protections

| Threat | Main protections | Page |
| --- | --- | --- |
| A vulnerability in Redmine is exploited | Upgrade Redmine early, WAF, read-only file system | [upgrade.md](upgrade.md), "AWS WAF" below |
| Password brute force, reused passwords | Two-factor authentication (required for administrators), password rules, WAF rate limit on login | "Redmine settings" and "AWS WAF" below |
| Function URLs are called directly | Function URLs use IAM authentication; the function is not invoked without an OAC signature | [lambda.md](lambda.md#cloudfront-and-function-urls) |
| Someone connects to the database from outside | RDS in private subnets without public access. The security group allows only the functions. The password is only in SSM and RDS | [rds.md](rds.md#security) |
| Attachments are read by people without permission | Redmine checks permissions before issuing a 5-minute CloudFront signed URL. The bucket is not public and allows only CloudFront through OAC | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#download) |
| A signed URL leaks | It expires in 5 minutes. It is not written to logs ("Logs" below) | "Logs" below |
| Malicious code runs through an attachment (HTML, SVG) | Attachments are served from Redmine's origin, as in standard Redmine, through the CloudFront behaviors `/files/*` and `/tmp/*` (thumbnails and zips), with the same `Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'; sandbox` that Redmine sets and `X-Content-Type-Options: nosniff`. A sandboxed document gets an opaque origin and runs no scripts, so it cannot read Redmine's cookies or call Redmine. Everything except PDF is returned as a download (`Content-Disposition: attachment`, the same as standard Redmine). A check after deployment confirms the header ([testing.md](testing.md#checks-after-deployment)) | [attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#download) |
| Email with a forged sender creates issues | Drop email that fails DMARC, spam, and email with viruses. Do not accept email from unregistered addresses | [mail.md](mail.md#spoofing-and-spam) |
| A webhook is used to send requests to internal addresses (SSRF) | `webhook_blocklist` rejects private, loopback and link-local addresses | [lambda.md](lambda.md#rails-and-redmine-settings) |
| Malicious code gets into a dependent gem or image | Pin with digests and SHA256, scan dependencies for vulnerabilities, pin GitHub Actions by SHA | "Supply chain" below |
| AWS permissions are escalated | A role per function, permissions boundaries, approval required for infrastructure changes | [iam.md](iam.md) |
| Cost is run up (a flood of requests) | Reserved concurrency, WAF rate limits, CloudFront flat-rate plan (requests blocked by WAF do not count toward usage) | "AWS WAF" below |
| Data mixes between instances | Names and roles are separate per instance, and targets are narrowed by ARN | [deploy-config.md](deploy-config.md) |

## Entry point (CloudFront)

| Item | Decision |
| --- | --- |
| HTTPS | Viewers are allowed HTTPS only; HTTP is redirected to HTTPS. The minimum TLS version is the CloudFront security policy `TLSv1.2_2021` |
| Response headers | On every behavior, attach the CloudFront AWS-managed response headers policy `SecurityHeadersPolicy` (ID `67f7725c-6f97-4210-82d7-5512b31e9d03`). It adds `Strict-Transport-Security: max-age=31536000`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin` and `X-XSS-Protection: 1; mode=block`. Redmine does not enable `force_ssl` (`config/environments/production.rb`), so HSTS is added by CloudFront |
| Attachments | The behaviors `/files/*` (attachments, GET) and `/tmp/*` (thumbnails and zips with GET, uploads to `/tmp/incoming/` with PUT) go to the attachments bucket through OAC and require CloudFront signed URLs. `SecurityHeadersPolicy` gives them `nosniff`, and a CloudFront Function on their viewer response (`<instance>-attachment-headers`) adds the sandbox CSP and the file name and type from the signed URL ([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#download)) |
| Function URLs | Requests without an OAC signature are rejected before the function is invoked ([lambda.md](lambda.md#cloudfront-and-function-urls)) |
| Request body | Up to 1 MB on Redmine's behaviors. Above that, Lambda@Edge returns 413. Uploads to `/tmp/incoming/` go to S3, not to Lambda; a CloudFront Function rejects a body over the upload limit ([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#upload)) |

On every plan, the distribution uses only AWS-managed policies (cache, origin request and response headers) and adds the attachments' headers with a CloudFront Function ([lambda.md](lambda.md#flat-rate-free-plan-and-waf)). The Free and Pro plans allow managed policies only; policies you define yourself, such as a Content Security Policy of your own, come with the Business plan, and this design does not use them.

## AWS WAF

An AWS WAF web ACL is attached to CloudFront to stop common attacks and excessive requests before they reach Redmine.

### Plan and cost

The templates create the same configuration on every plan: the 5 rules below, AWS-managed CloudFront policies, and no CloudFront or WAF logs. It is made to fit the flat-rate Free plan; the plan changes only the price and the usage included.

| Plan | WAF cost | When it is used |
| --- | --- | --- |
| CloudFront flat-rate plan Free (default) | USD 0 (included in the plan) | The plan this design is made for. It allows 5 WAF rules, and the design uses all 5 |
| Flat-rate plan Pro | USD 15 per month (includes CloudFront and WAF) | When usage is expected to go beyond Free's 1 million requests and 100 GB per month. The configuration stays the same |
| Pay-per-use | USD 5 per month per web ACL, USD 1 per month per rule or managed rule group, USD 0.60 per million requests. About USD 10 per month for the 5 rules below | When the account has no Free plan left (up to 3 per account, below). The configuration stays the same |

A flat-rate plan comes with some rules. The web ACL cannot be removed (to remove it, go back to pay-per-use), and custom rule groups cannot be used, so rules are placed one by one. An account can have up to 3 Free plans, and this limit cannot be raised. A web ACL or CloudFront Function used by another distribution cannot be attached to a distribution on a plan, so a web ACL you prepare (`cloudfront.webAclArn`) must be used by this distribution only. Free allows up to 5 cache behaviors; this design uses 4.

Free does not offer CAPTCHA, JavaScript challenges, rules that match on headers or on regular expressions, custom responses for blocked requests, or Bot Control. The login rate limit therefore matches the paths with string matches (starts with), not with a regular expression. On Free and Pro, WAF inspects only the first 16 KB of a body.

The CloudFront web ACL is created in us-east-1, in the instance's us-east-1 stack (`<instance>-edge`) ([deploy-config.md](deploy-config.md)).

### Rules

There are 5 rules (the Free limit). They are applied from the top. The default action is "allow".

| Order | Rule | What it does | Default value | Action |
| --- | --- | --- | --- | --- |
| 1 | Login rate limit (rate-based) | Counts `POST` to paths that start with `/login`, `/account/lost_password`, `/account/register` or `/account/twofa`, per IP address | 20 in 5 minutes | Block |
| 2 | Overall rate limit (rate-based) | Counts all requests per IP address | 1,000 in 5 minutes | Block |
| 3 | AWS managed rules: Amazon IP Reputation List | IP addresses with a bad reputation | — | Block |
| 4 | AWS managed rules: Known Bad Inputs | Known bad inputs (Log4j patterns, etc.) | — | Block |
| 5 | AWS managed rules: Common Rule Set | Common attacks (SQL injection, typical XSS, path traversal, etc.) | — | Count only at first. Block after checking (below) |

Redmine has no mechanism to lock an account after a number of failed logins (checked in the Redmine 7.0.3 source). Brute force is therefore prevented by the login rate limit and two-factor authentication; Redmine itself limits two-factor code attempts to 3 per password entry.

A rate limit rule counts over 1, 2, 5 or 10 minutes, with a minimum count of 10. WAF blocks near the configured count but does not guarantee the exact count (WAF documentation). Because requests pass through CloudFront, the counted IP address is the user's. The overall count of 1,000 is a starting value: one Redmine page is a few requests, excluding assets, which also pass through CloudFront and are counted. Measure actual use and decide, and raise the count when requests from inside an organization are combined into one IP address (NAT and so on).

The Common Rule Set only counts at first, because some of its rules block legitimate Redmine requests. `SizeRestrictions_BODY` (bodies over 8 KB) blocks long wiki pages and issue descriptions, and `CrossSiteScripting_BODY` and others can block code examples written in the wiki. For about the first 2 weeks the whole group only counts. Then look at the requests that would have been blocked on the dashboard, keep only the matching rules at count, and set the others to block.

Blocking by country is available on Free too, but it is not used by default, because some people use Redmine from places such as business trips. To use it, replace the overall rate limit so that there are no more than 5 rules. When WAF blocks a request on Free, it returns its default 403.

WAF applies before the request reaches the origin. For a request WAF blocks, neither Lambda@Edge nor Lambda is invoked, and the request does not count toward the flat-rate plan's usage (CloudFront documentation).

### Monitoring

- **Dashboard:** Use the CloudFront security dashboard (available on Free) to see blocked requests and the rules they matched.
- **Alarms:** Put alarms on WAF's CloudWatch metrics (blocked count per rule). If the login rate limit suddenly rises, suspect brute force.
- **Logs:** The design keeps no CloudFront or WAF logs on any plan (Free does not include them). Investigate incidents with the security dashboard, the samples of blocked requests and the Lambda logs.

### Settings

The plan, the rate limits and whether the Common Rule Set blocks are set per instance with `cloudfront.plan` and `waf.*` in the configuration file ([deploy-config.md](deploy-config.md#fields-of-redminejson)).

## Redmine settings

`redmine.settings` in the configuration file (values set when the instance is first deployed; [deploy-config.md](deploy-config.md)) sets the following initial values.

| Setting (name in the Redmine UI) | Value | Reason |
| --- | --- | --- |
| Authentication required (`login_required`) | Enabled | Hide everything from people who are not logged in. `/robots.txt` also disallows everything |
| Self-registration (`self_registration`) | Disabled | Strangers cannot create accounts (Redmine's default is registration with administrator approval) |
| Two-factor authentication (`twofa`) | Required for administrators only (required for everyone if possible) | Administrator accounts cannot be broken with a password alone |
| Minimum password length (`password_min_length`) | 12 (Redmine's default is 8) | Protection against brute force |
| Session inactivity timeout, maximum session lifetime (`session_timeout`, `session_lifetime`) | Set to a chosen time (Redmine's default is disabled) | Do not keep sessions on forgotten devices for long |
| Enable REST web service (`rest_api_enabled`) | Enabled only when used | If not used, do not accept operations with API keys (Redmine's default is also disabled) |
| Enable JSONP support (`jsonp_enabled`) | Disabled | Do not let other origins read API responses |
| Forbidden extensions (`attachment_extensions_denied`) | Executable files (`exe`, `bat`, etc.), decided by adopters | Do not let attachments be used to distribute harmful files |

Right after deploying, change the password of the initial administrator (`admin`, password also `admin`) and set up two-factor authentication. If that account is not used, create another administrator first, then lock it. The settings that cannot work on Lambda, the repository and incoming email web services, are fixed to disabled by the plugin ([admin.md](https://redmine-kit.github.io/redmine_serverless/admin.html#redmine-settings-that-cannot-work-on-lambda)).

## AWS accounts and permissions

- **Permissions:** Details of roles and permissions are in [iam.md](iam.md). The key points are a role per function, permissions boundaries, approval for infrastructure changes, and no access keys.
- **Account protection:** The root user has MFA and is not used day to day. People sign in through IAM Identity Center (SSO) with MFA.
- **S3:** Block Public Access is enabled at both the account and the bucket level. Bucket policies reject requests that do not use TLS ([iam.md](iam.md#resource-based-policies)).
- **Monitoring:** Enable CloudTrail (management events) for the account, and use IAM Access Analyzer to check for resources usable from outside. Enabling GuardDuty for the account is recommended (check the cost when building).

## Protecting data

| Data | Encryption at rest | Encryption in transit | Backup |
| --- | --- | --- | --- |
| RDS for PostgreSQL | Encryption at rest (AWS managed key) | TLS required (`rds.force_ssl`). The functions verify the certificate (`verify-full`) | Automated backups (point-in-time restore). Deletion protection on |
| S3 (attachments, mail, assets) | SSE-S3 | TLS only | Versioning on the attachments bucket. Deleted objects can be restored for a set period |
| SSM Parameter Store | SecureString (`aws/ssm` key) | TLS | `bin/deploy` creates the secrets the first time. The steps to regenerate them are in "Incidents" below |
| CloudWatch Logs | Encrypted by default | TLS | "Retention periods" below |

Practice restoring from backup to a separate DB instance and bucket regularly. Do not rely on a backup that you have not restored.

## Retention periods

How long logs, records, temporary files and backups are kept. All periods are decided here. Periods in other pages follow this table. Items that have a configuration file field can be changed per instance ([deploy-config.md](deploy-config.md#fields-of-redminejson)).

| Target | Period (default) | How it is deleted | Configuration file field |
| --- | --- | --- | --- |
| CloudWatch Logs (`redmine-web`, `redmine-worker`, `redmine-task`) | 90 days | Log group retention setting. Log groups are created in advance by CloudFormation | `logs.retentionDays` |
| CloudWatch Logs (Lambda@Edge `redmine-body-hash`) | 90 days | Lambda@Edge creates a log group automatically in each Region where it runs. CloudFormation cannot create them in advance, so `bin/deploy` applies the retention setting to the log groups in all Regions (and reapplies it on every deployment to log groups created later) | `logs.retentionDays` |
| CloudWatch Logs (Session Manager; only the setup with a NAT instance) | 90 days | Log group retention setting | `logs.retentionDays` |
| CloudTrail (management events) | 1 year (proposal) | Lifecycle of the S3 bucket that holds the trail. If the account has rules, follow them. CloudTrail event history (90 days) is set by AWS | Decided in the account baseline (outside this design) |
| Records of received email (`serverless_received_mails`) | 90 days | Deleted by the daily scheduled rake task ([tasks.md](tasks.md#scheduled-runs)) | `retention.recordsDays` |
| Records of failed jobs (`serverless_job_failures`) | 90 days | Same as above | `retention.recordsDays` |
| Imported email (`processed/`) | 30 days | S3 lifecycle | `retention.mailDays` |
| Email not imported (left in `inbound/`: dropped or failed) | 30 days | S3 lifecycle. Re-import within this period | `retention.mailDays` |
| SQS dead-letter queue | 14 days | SQS message retention (the SQS maximum) | — |
| Old versions of attachments (deleted and overwritten) | 30 days | S3 lifecycle (delete noncurrent versions) | `retention.noncurrentVersionDays` |
| Temporary files (`tmp/`: zip files for bulk download, read/write checks) | 1 day | S3 lifecycle | — |
| Uploads before registration (`tmp/incoming/`) | 1 day | S3 lifecycle | — |
| CSV import files (`imports/`) | 7 days | S3 lifecycle | — |
| Old assets | 90 days | S3 lifecycle (delete noncurrent versions) | — |
| ECR images | The 10 newest | ECR lifecycle. Images used by functions are not deleted ([lambda.md](lambda.md#image)) | — |
| RDS automated backups | 7 days | Backup retention period of the DB instance ([rds.md](rds.md#settings)) | `retention.backupDays` |
| WAF sampled requests | A period set by AWS (the last few hours; check when building) | — | — |

During an incident, make sure nothing is deleted by these periods until the investigation is finished ("Incidents" below). Do not make the periods too short either: keep logs and records longer than the time it takes to notice an incident, and estimate that time before going below 90 days. Logs and records contain users' email addresses and IP addresses; if the adopter's rules limit how long these can be kept, shorten the periods to match.

## Logs

- **Do not log signed URLs:** Rails writes the redirect target URL to the log. If the signed URL for an attachment download is in the log, anyone who can read the log can read the attachment until it expires. Add the paths `/files/`, `/thumbnails/` and `/tmp/bulk/` to the Rails setting `config.filter_redirect` so the log shows `[FILTERED]` ([lambda.md](lambda.md#rails-and-redmine-settings)).
- **Filter parameters:** Redmine filters the `password`, `salt`, `twofa_totp_key` and `key` parameters in logs (`filter_parameters` in `config/application.rb`). Secret parameters on pages the plugin adds are filtered the same way.
- **IP addresses:** Because requests pass through CloudFront, Redmine receives the user's IP address in `X-Forwarded-For`. Whether Rails' `remote_ip` returns the user's IP address rather than CloudFront's (trusted proxy settings) is checked when building.
- **Limit who can read:** Only operators have permission to read logs ([iam.md](iam.md#permissions-of-people)).

## Supply chain

| Target | Protection |
| --- | --- |
| Base image, Lambda Web Adapter | Reference by digest, not by tag ([AGENTS.md](../AGENTS.md)) |
| Redmine, Pandoc | Verify the SHA256 of downloaded files |
| gems | Pin in `Gemfile.lock`. Check for known vulnerabilities in CI (`bundler-audit`) |
| Images | Scan OS packages and gems in the image for known vulnerabilities in CI (Trivy, etc.). Do not deploy if there are serious vulnerabilities |
| GitHub Actions | Pin actions by commit SHA, not by tag |
| Lambda@Edge function | Use no npm package dependencies (only `node:crypto`) |
| Distributed image and plugins | Adopters reference the image by digest. The plugin gems are pinned with their versions and checksums in `image/Gemfile.lock` ([architecture.md](architecture.md#distribution)) |
| Plugins and themes added by the adopter | `image.plugins` and `image.themes` take a gem at an exact version, a Git repository at a tag or a full commit hash (no branch), or a directory, and the derived image's lock keeps the base image's versions unless an added gem needs a newer one. The credential for GitHub Packages is a build secret, never in a layer or in `redmine.json`. The added code runs with the functions' permissions, so the adopter reviews it; a commit hash pins a Git source more firmly than a tag, which can be moved ([architecture.md](architecture.md#derived-images)) |

Updates to Redmine, gems and images go through the checks in [upgrade.md](upgrade.md) first.

## Remaining risks

Risks this design cannot fully prevent, covered by operations.

| Risk | Reason | Mitigation |
| --- | --- | --- |
| Vulnerabilities in Redmine | Vulnerabilities in Redmine and Rails remain until you upgrade | Follow Redmine security announcements and upgrade early. WAF prevents some |
| Login brute force | Redmine has no mechanism to lock an account after a number of failures | WAF rate limits and two-factor authentication |
| Outbound traffic through the NAT instance | With the NAT instance setup, functions can reach the internet | Focus on not being taken over (the protections above). If outbound traffic must be blocked, use the VPC endpoint setup ([rds.md](rds.md#which-to-choose)) |
| The database password | Unlike temporary credentials, a password does not expire by itself | It is kept only in SSM (SecureString) and RDS, and RDS is reachable only from inside the VPC. Change it in an incident (below) |
| Viruses in attachments | Redmine does not scan attachments | GuardDuty Malware Protection for S3 on `tmp/incoming/` and `imports/`, with `REDMINE_S3_MALWARE_SCAN=true`: the plugin uses a file only after it is found clean ([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#malware-scan), with the cost) |
| No CloudFront and WAF logs | The Free flat-rate plan does not include logs | Use Lambda logs and the security dashboard |

## Incidents

1. **Stop:** Set the reserved concurrency of `redmine-web` and `redmine-worker` to 0 to stop operations from outside (CloudFront returns the maintenance page; [deploy-config.md](deploy-config.md#deployment-commands)). To stop receiving email, disable the SES receipt rule.
2. **Preserve:** Keep CloudTrail, CloudWatch Logs, S3 versions and the plugin's records without deleting them. So that nothing is deleted by the "Retention periods" above until the investigation is finished, stop the log group retention settings and S3 lifecycles, and stop the deletion of records by the scheduled rake task.
3. **Rotate:**
   - Regenerate `SECRET_KEY_BASE` (set a new value in the SSM parameter and update the functions). Session cookies become invalid and users log in again.
   - Change the database password (set a new value in RDS and in the SSM parameter, then update the functions).
   - Ask users whose passwords and API keys may have leaked to reset them. Check the administrator accounts.
   - On the AWS side, invalidate the sessions of the roles involved (IAM "Revoke sessions").
4. **Restore:** If data was damaged, restore from the RDS automated backups (to a point in time) and S3 versions ("Protecting data" above).
5. **Notify:** Notify users and other affected people according to the adopter's rules and the law.

## To verify

- Whether `config.filter_redirect` keeps redirects to CloudFront signed URLs out of the logs
- Whether CloudFront accepts the template on the Free flat-rate plan as checked against the plan's feature table ([lambda.md](lambda.md#flat-rate-free-plan-and-waf)), including whether each AWS managed rule group counts as one of the 5 WAF rules and whether a scope-down statement on a managed rule group is allowed
- Which rules in the WAF Common Rule Set block legitimate Redmine requests (body size, XSS patterns, etc.)
- Whether Rails' `remote_ip` is the user's IP address for requests that pass through CloudFront
- The cost of GuardDuty and S3 malware scanning
- Whether `bin/deploy` can apply the retention setting to the Lambda@Edge log groups in every Region with the role for deploying (`logs:PutRetentionPolicy` on that log group, `logs:DescribeLogGroups` and `ec2:DescribeRegions`; [iam.md](iam.md#role-for-deploying-infrastructure))
- How long WAF sampled requests can be viewed
