# Cost estimate

Monthly cost estimate in ap-northeast-1. Unit prices come from the ap-northeast-1 files of the AWS price list (Price List API). Usage figures are assumptions for about 10 people working during business hours and have not been measured yet. The database is RDS for PostgreSQL in a VPC ([rds.md](rds.md)).

## Monthly estimate

| Item | Unit price | Assumed usage | Monthly |
| --- | --- | --- | --- |
| RDS for PostgreSQL (db.t4g.micro, Single-AZ, gp3 20 GB) | $0.025 per hour, $0.138 per GB-month | Running all month | $21.01 |
| SQS | $0.40 per million requests (standard queue) | 100,000 requests | about $0.04 |
| Lambda (arm, `redmine-web`) | $0.0000133334 per GB-second, $0.20 per million requests | 50,000 requests × 0.3 s × 2 GB, 3,200 warm-up invocations | about $0.5 |
| S3 (Standard, attachments and assets) | $0.025 per GB-month | 10 GB (including old versions) | $0.25 |
| S3 requests | $0.0047 per 1,000 PUT and similar, $0.0037 per 10,000 GET and similar | 10,000 PUT and similar, 100,000 GET and similar | about $0.1 |
| ECR | $0.10 per GB-month | 3 GB (three images) | $0.30 |
| CloudWatch Logs | $0.76 per GB ingested, $0.033 per GB-month stored | 0.5 GB | about $0.4 |
| CloudFront | Expected to fit the flat-rate Free plan or the always-free tier | — | $0 |
| Lambda@Edge (`redmine-body-hash`) | $0.60 per million requests, $0.00005001 per GB-second. No free tier | 50,000 requests × 10 ms × 128 MB | about $0.04 |
| SES sending | $0.0001 per recipient | 1,000 messages | $0.10 |
| SES receiving | $0.0001 per message, $0.00009 per chunk | 1,000 messages | about $0.19 |
| Route 53 | $0.50 per hosted zone per month. Queries to alias records pointing at CloudFront are free; others are $0.40 per million | Only when the Redmine subdomain is delegated. $0 if it is not delegated | about $0.5 |
| GuardDuty Malware Protection for S3 (uploads and imports; [aws-security.md](aws-security.md#malware-protection-for-s3)) | $0.1185 per GB scanned (the first 1 GB per month free), $0.000282 per object (the first 1,000 per month free) | 3,000 files, 6 GB | about $1.2 |
| Subtotal | | | about $24.6 |

The route from the VPC to AWS services is added to the subtotal ([rds.md](rds.md#routes-out-of-the-vpc)).

| Setup | Route | Monthly total |
| --- | --- | --- |
| Setup 2: NAT instance | One t4g.nano, a public IPv4 address and a disk, about $8.4 | about $33.0 |
| Setup 1: VPC endpoints | Interface endpoints for SES, SSM and SQS (1 AZ), about $30.7 | about $55.3 |

Most of the total is fixed: RDS and the route out of the VPC are charged by the hour whether Redmine is used or not. The other items are charged by use.

CloudFront costs nothing with the flat-rate Free plan, up to 1 million requests and 100 GB per month. Without the plan, the usage is still expected to fit the always-free tier (1 TB of transfer and 10 million requests per month); what that tier includes will be checked when building.

Some small items are left out: CloudWatch alarms (dead-letter queue, sending failures, receiving failures and so on; about $0.10 each per month), the run time of `redmine-worker` and `redmine-task`, SSM Parameter Store requests, and the KMS requests that decrypt SecureString parameters. The unit price of the NAT instance's disk has not been checked in the price list ([rds.md](rds.md#cost)). All of these are expected to be small.

Two assumptions are not checked in the price list yet. Placing the functions in a VPC is assumed to add no charge of its own. The event source mapping of `redmine-worker` polls the queue continuously (long polling) and so makes requests, but SQS includes 1 million free requests each month, so at this scale the total is not expected to change.

## What adds cost

| Item | Monthly | When to add |
| --- | --- | --- |
| Provisioned Concurrency (one 2 GB environment) | about $23 | To remove the wait for start-up |
| CloudFront flat-rate Pro plan | $15 (log storage and search are charged separately) | To keep CloudFront and WAF logs ([security.md](security.md#plan-and-cost)) |
| AWS security services the adopter turns on (GuardDuty threat detection, Security Hub, Config, unused access analysis) | from under $1 each; see the page | Per account ([aws-security.md](aws-security.md)) |
| Costs on the administration pages (`costExplorer.enabled`) | about $0.9 to $1.2 (Cost Explorer API: $0.01 per request; the daily refresh, the plugin's only fetch, makes 3 requests a day, 4 with the tag breakdown) | To see the account's costs in Redmine, with an image that adds the plugin `redmine_serverless_costexplorer` (a derived image) ([deploy-config.md](deploy-config.md#fields-of-redminejson)) |
| A shared cache (ElastiCache Serverless for Valkey) | about $7.4 (one `cache.t4g.micro` node: $14.60) | To share formatted text and search results across environments ([cache.md](cache.md#when-a-shared-cache-is-worth-it)) |

What to add to the database and the route (Multi-AZ, a NAT Gateway, RDS Proxy and so on) is in [rds.md](rds.md#cost).

## Sources of the prices

| Price list | Publication date |
| --- | --- |
| AmazonRDS | 2026-10-29 |
| AWSLambda | 2026-10-30 |
| AmazonS3 | 2026-11-04 |
| AmazonCloudWatch | 2026-11-04 |
| AmazonECR | 2026-09-11 |
| AmazonVPC | 2026-11-05 |
| AmazonSES | 2026-11-04 |
| AWSQueueService (SQS) | 2026-09-11 |
| AmazonRoute53 | 2026-11-04 |
| AmazonGuardDuty | 2026-10-30 |
| AWSCostExplorer (global) | 2026-09-11 |

The URL format is `https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/<service>/current/ap-northeast-1/index.json` (retrieved on 2026-11-08). AmazonRDS and AmazonVPC are also used for the cost in [rds.md](rds.md#cost).
