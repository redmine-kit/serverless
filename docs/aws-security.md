# AWS security settings

This page lists the security settings on the AWS side: what each protects, whether this project's templates create it or the adopter turns it on once per account, what it costs, and whether it is on by default. The threats and the protections inside Redmine are in [security.md](security.md); the roles and permissions are in [iam.md](iam.md).

Prices are for the Tokyo Region (ap-northeast-1), from the AWS price list (the date of each list is given). Estimates that depend on the account's activity are marked "estimate"; items not checked in the price list are marked "unchecked".

## Overview

| Setting | What it protects | Who sets it up | On by default | Monthly cost |
| --- | --- | --- | --- | --- |
| [GuardDuty threat detection](#guardduty) | Finds suspicious API calls, network activity and credentials in use | The adopter, once per account and Region | Recommended (not created by the templates) | Estimate: under USD 1 for a small account |
| [GuardDuty Malware Protection for S3](#malware-protection-for-s3) | Files that users upload or import are scanned before Redmine reads them | The instance stack | On (`uploads.malwareScan`) | About USD 1.2 for 3,000 files and 6 GB |
| [CloudTrail](#cloudtrail) | A record of the account's API calls, kept for investigations | The account stack (`bin/deploy --account`), unless the account has a trail | On when the account has no trail | The first copy of management events is free; S3 storage |
| [IAM Access Analyzer](#iam-access-analyzer) | Finds resources shared outside the account, and unused access | The account stack, unless the Region has an analyzer | External access: on. Unused access: off | External access: free. Unused access: USD 0.20 per role or user |
| [AWS Security Hub](#aws-security-hub) | Checks the account against AWS Foundational Security Best Practices | The adopter (optional) | Off | USD 0.001 per check (first 100,000) |
| [AWS Config](#aws-config) | A history of resource configurations; needed by Security Hub's checks | The adopter (optional) | Off | USD 0.003 per configuration item recorded |
| [S3 Block Public Access (account)](#s3-block-public-access) | No bucket of the account can be made public | The adopter, once per account | Recommended | Free |
| [EBS default encryption](#ebs-default-encryption) | Volumes are encrypted (only the NAT instance has one) | The template encrypts the NAT instance's volume; the account default is the adopter's | The NAT volume: on | Free |
| [The root user](#the-root-user) | The account's strongest credential | The adopter | — | Free |
| [People's access](#peoples-access) | Sign-in of administrators and operators | The adopter (IAM Identity Center) | — | Free |
| [Budgets](#budgets) | Notices when spending goes over a limit | The adopter | Recommended | Free for budgets without actions |

## GuardDuty

GuardDuty analyzes CloudTrail management events, VPC flow logs and DNS logs, and reports findings such as credentials used from unusual places, calls to known malicious hosts, and crypto mining.

- **Who:** The adopter turns it on once per account and Region. A detector is one per account and Region, and an organization often turns it on for every account, so the templates do not create it.
- **Steps:** Turn it on in each Region used (the instance's Region, and us-east-1 for CloudFront's stacks):

  ```sh
  aws guardduty create-detector --enable --region <Region>
  ```

  Send its findings to the alarm topic with an EventBridge rule if needed.
- **Cost:** CloudTrail events analyzed, USD 4.72 per million; VPC flow log and DNS log data analyzed, by volume (AWS price list for GuardDuty of 2026-10-30). The first 30 days are free. For a small instance, an estimate is under USD 1 per month; the 30-day trial shows the real figure on the GuardDuty usage page.
- **Optional protection plans:** S3 protection (data events of all buckets), Lambda protection (network activity of the functions) and RDS protection cost extra and are not needed for this design. Malware Protection for S3 below is separate and does not need a detector.

## Malware Protection for S3

The instance stack creates an Amazon GuardDuty Malware Protection plan for the attachment bucket. Redmine waits for the result before using a file; how it waits and what users see is in the S3 plugin's documentation ([attachments.md](https://redmine-kit.github.io/redmine_serverless_s3/attachments.html#malware-scan)).

The plan scans new objects under `incoming/` (uploads through CloudFront and through Lambda) and `imports/` (CSV import files). `files/` holds only copies of objects that were found clean, so it is not scanned again; scanning it would double the cost. Received mail is not scanned by GuardDuty either: SES scans it and gives its virus verdict, and only mail with `PASS` is imported ([mail.md](mail.md)).

The plan tags each scanned object with `GuardDutyMalwareScanStatus` (`NO_THREATS_FOUND`, `THREATS_FOUND`, `UNSUPPORTED`, `ACCESS_DENIED` or `FAILED`). The bucket policy uses this tag to control access: on `incoming/*` and `imports/*`, it denies `s3:GetObject` and `s3:GetObjectVersion` unless the tag is `NO_THREATS_FOUND`, for every principal except the plan's role (`<instance>-malware-scan`). It also denies writing or deleting tags there to everyone but that role. That also stops `PutObject` with tags, so a tag cannot be forged before the scan. The condition uses `aws:PrincipalArn` rather than `NotPrincipal`, as the IAM documentation recommends.

The functions get `s3:GetObjectTagging` on `incoming/*` and `imports/*` to read the result, and `REDMINE_S3_MALWARE_SCAN=true` turns the waiting on in the plugin. The plan's role `<instance>-malware-scan` is trusted by `malware-protection-plan.guardduty.amazonaws.com` and has the permissions the GuardDuty documentation gives for one bucket: the EventBridge rule GuardDuty manages (`DO-NOT-DELETE-AmazonGuardDutyMalwareProtectionS3*`), the bucket's notifications, reading and tagging objects, and the validation object. The bucket sends its events to EventBridge; this is set in the template, so stack updates keep it.

The cost is USD 0.1185 per GB scanned (the first 1 GB per month free) and USD 0.000282 per object (the first 1,000 per month free), from the AWS price list for GuardDuty of 2026-10-30. For example, 3,000 files and 6 GB in a month cost (6 − 1) × 0.1185 + (3,000 − 1,000) × 0.000282 ≈ USD 1.2 ([cost.md](cost.md)).

To turn the scan off, set `"uploads": {"malwareScan": false}` in `redmine.json` ([deploy-config.md](deploy-config.md#fields-of-redminejson)). The plan, its role and the bucket policy statements are then not created, and the functions get `REDMINE_S3_MALWARE_SCAN=false`.

## CloudTrail

A trail keeps the account's API calls (management events) as log files in S3, for investigations after an incident ([security.md](security.md)).

- **Who:** The account stack (`infra/account.yaml`, `bin/deploy --account`) creates the trail `redmine-trail`: all Regions, global service events, log file validation, to the bucket `redmine-trail-<account>-<Region>` (encrypted, Block Public Access, TLS only, only CloudTrail of this trail can write). The log files are deleted after `account.trailDays` (default 365).
- **Not a second one:** `bin/deploy --account` creates it only when the account has no multi-Region trail (an organization trail counts). `account.cloudTrail` (`true` or `false`) overrides that; once created, it is kept.
- **Cost:** The first copy of management events is free; a second trail of the same events costs USD 2.00 per 100,000 events (USD 0.00002 per event; AWS price list for CloudTrail of 2026-11-02), which is why a second trail is not created. The S3 storage of the log files is a few cents per month for a small account (estimate).

## IAM Access Analyzer

- **External access:** An analyzer of the account (`redmine-external-access`) reports resources in the Region that can be reached from outside the account, such as a bucket policy or a role trust that allows another account. It is free. The account stack creates it unless the Region already has an account or organization analyzer (`account.accessAnalyzer` overrides). Analyzers are per Region; for other Regions, the adopter adds them.
- **Unused access:** An analyzer of unused access (`redmine-unused-access`) reports roles, keys and permissions not used for 90 days. It costs USD 0.20 per role or user analyzed per month (AWS price list for IAM Access Analyzer of 2026-11-08), so it is off by default (`account.unusedAccessAnalyzer`).

## AWS Security Hub

Security Hub (CSPM) checks the account against the AWS Foundational Security Best Practices standard and collects the findings of GuardDuty and IAM Access Analyzer in one place.

- **Who:** The adopter, optionally. An organization often manages it centrally.
- **Steps:** Turn it on in each Region used:

  ```sh
  aws securityhub enable-security-hub --enable-default-standards --region <Region>
  ```

  Its checks need AWS Config recording (below).
- **Cost:** USD 0.001 per security check for the first 100,000 per account and Region per month (AWS price list for Security Hub of 2026-11-08), free for 30 days. The number of checks depends on the resources; the trial shows it (unchecked for this design).

## AWS Config

Config records the configuration of the resources and their changes.

- **Who:** The adopter, optionally (Security Hub's checks need it).
- **Cost:** USD 0.003 per configuration item recorded, and USD 0.001 per rule evaluation for the first 100,000 (AWS price list for Config of 2026-11-08). Every deployment changes the functions, so each deployment records a few items; periodic recording, or recording only some resource types, keeps it small (estimate for this design unchecked).

## S3 Block Public Access

The templates turn on Block Public Access for every bucket they create. At the account level it also covers buckets made by hand.

- **Steps:** Once per account:

  ```sh
  aws s3control put-public-access-block --account-id <account> \
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
  ```

- **Cost:** Free.

## EBS default encryption

Only the NAT instance (`network.mode` `nat`) has an EBS volume. The launch template encrypts it whatever the account's setting is.

- **Account default (optional):** Turn it on per Region:

  ```sh
  aws ec2 enable-ebs-encryption-by-default --region <Region>
  ```

  It uses the AWS managed key `aws/ebs`.
- **Cost:** Free.

## The root user

- **Steps:** Turn on MFA for the root user, delete its access keys if any, and do not use it for daily work. In an organization, centralized root access can remove the root credentials of member accounts.
- **Cost:** Free.

## People's access

Administrators and operators sign in with IAM Identity Center; no IAM users or access keys are created. The permission sets and what each may do are in [iam.md](iam.md#permissions-of-people).

## Budgets

- **Steps:** A monthly cost budget with notices to the administrators, for example at 80% and 100% of the expected cost ([cost.md](cost.md)): `aws budgets create-budget` with `--notifications-with-subscribers`, or in the Billing console.
- **Cost:** Budgets without actions are free; budgets with actions are free for the first 62 budget-days, then USD 0.10 per budget-day (AWS price list for Budgets of 2026-09-11).

## To verify

- Whether the bucket policy's conditions with `aws:PrincipalArn` (instead of `NotPrincipal` as in the GuardDuty documentation) let the plan's role read and tag, and deny everyone else
- Whether CloudFront's `PutObject` to `incoming/` (origin access control) is not affected by the tag statements
- Whether the plan validates the bucket when the stack creates the plan and the bucket policy in the same update
- The real monthly cost of GuardDuty threat detection, Security Hub and Config for one instance
