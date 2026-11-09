# Comparison with ordinary servers

This page compares this design (Lambda and managed services) with running Redmine on ordinary servers, on price, security and operations.

Unit prices on this page come from the Tokyo files of the AWS price list (Price List API) (published on 2026-11-07 for EC2, 2026-10-19 for ECS, 2026-11-05 for ELB and 2026-09-15 for Lightsail). Monthly amounts are calculated for 730 hours. Usage is assumed to be about 10 people. Sources are in [sources.md](sources.md).

## Setups compared

| Setup | Contents |
| --- | --- |
| This design | Lambda in a VPC, RDS for PostgreSQL (db.t4g.micro), VPC endpoints or a NAT instance, S3, SQS, SES ([architecture.md](architecture.md)) |
| One EC2 instance | One t4g.small (2 GB) running Redmine and PostgreSQL on the same server. Attachments on the server's disk |
| EC2 and RDS | Redmine on one t4g.small, and RDS for PostgreSQL (db.t4g.micro) |
| One Lightsail instance | One 2 GB Lightsail instance running Redmine and PostgreSQL |
| ECS Fargate | Redmine on Fargate (0.5 vCPU, 1 GB, Arm), an ALB, RDS for PostgreSQL (db.t4g.micro) |

## Prices (monthly estimates)

| Setup | Breakdown | Monthly |
| --- | --- | --- |
| This design | RDS about $21.0, the route out of the VPC (NAT instance about $8.4, or three endpoints about $30.7), others (Lambda, S3, ECR, logs, Route 53 and so on) about $2.4 ([cost.md](cost.md)) | about $31.8–54.1 |
| One EC2 instance | t4g.small $15.8 ($0.0216 per hour), gp3 30 GB $2.9 ($0.096 per GB-month), public IPv4 $3.7 | about $22.3 |
| EC2 and RDS | One EC2 instance (about $22.3) and RDS about $21.0 | about $43.3 |
| One Lightsail instance | 2 GB instance $11.8 ($0.01612 per hour, including public IPv4) | about $11.8 |
| ECS Fargate | Fargate $18.0 ($0.04045 per vCPU-hour, $0.00442 per GB-hour of memory), ALB $17.7 ($0.0243 per hour) plus LCUs, two public IPv4 addresses for the ALB $7.3, RDS about $21.0, an outbound route for the tasks (public IPv4 or NAT) | about $69 or more |

- **Not included:** Backups (EBS snapshots, Lightsail snapshots), CloudFront and SES sending charges. They are small for every setup.
- **Lightsail allowances:** The Lightsail instance price includes allowances for disk and data transfer. Their size will be checked on the Lightsail pricing page.
- **How to read this:** Lambda is pay-per-use, but the database and the route out of the VPC are fixed costs. This design costs more than putting everything on one server (Lightsail, one EC2 instance). With the NAT instance, it costs less than EC2 and RDS; with the endpoints, about the same or more ([cost.md](cost.md)).

## Security

| Item | This design (Lambda) | One EC2 instance, one Lightsail instance | EC2 and RDS | ECS Fargate |
| --- | --- | --- | --- | --- |
| OS updates | AWS updates the Lambda execution environment. The OS inside the image (Amazon Linux 2023) and the gems are updated by rebuilding the image | You update the server's OS yourself | Same as left (RDS updates the database) | AWS manages the Fargate platform. The image is updated by rebuilding |
| Entry points from outside | Only CloudFront (the function URL cannot be called without a CloudFront OAC signature). RDS has no public access. No open ports and no server to log in to | The web port (443). Either open SSH or use Systems Manager | Same as left | Only the ALB |
| After an intrusion | The execution environment is read-only and is replaced after a short time, so an attacker cannot persist by modifying files | Changes remain on disk, so an attacker may persist | Same as left | Tasks are replaced, but writable locations depend on the configuration |
| Separation of permissions | A separate execution role per function (web, worker, task) ([iam.md](iam.md)) | All permissions gather in the server's single role | Same as left | Roles can be separated per task |
| Database | RDS in the private subnets of a VPC. Connects with a password kept in SSM Parameter Store, over TLS that checks the server certificate ([rds.md](rds.md#settings)) | On the same server. If the server is compromised, the database can be read too | RDS inside a VPC. Connects with a password | RDS inside a VPC. Connects with a password |
| Attachments | S3. Versioning allows restoring deleted files. Downloads use 5-minute presigned URLs | The server's disk. You take backups yourself | Same as left | Needs shared storage (EFS or S3) |
| Secrets | SSM Parameter Store. Not even in Lambda environment variables | The server's configuration file | Same as left | SSM or Secrets Manager from the task definition |
| Availability | Lambda runs across multiple AZs. RDS is Single-AZ; if it stops, it is restored from a backup ([rds.md](rds.md#settings)) | If the one server stops, everything stops | One Redmine server | Tasks can be placed in multiple AZs |

- **Entry point:** The function URL uses IAM authentication and accepts only requests signed by CloudFront OAC. Direct requests are rejected before the function is invoked ([lambda.md](lambda.md#cloudfront-and-function-urls)).
- **Image updates:** AWS does not update Lambda container images automatically. Each time the base image, Redmine or a gem is updated, the image is rebuilt and deployed.

## Operations

| Item | This design (Lambda) | Ordinary servers |
| --- | --- | --- |
| Server maintenance | No servers for Redmine. RDS applies database updates in its maintenance window. In the NAT instance setup, one NAT instance is updated with Systems Manager ([rds.md](rds.md#managing-it-with-systems-manager)) | You look after the OS, middleware, disks and backups |
| Waiting for start-up | The first page after an idle period waits for start-up ([lambda.md](lambda.md#waiting-for-start-up)) | None |
| When load increases | Lambda adds environments. RDS is resized by changing the instance class | Resize the server |
| Redmine updates | Rebuild the image and run migrations in the task function ([tasks.md](tasks.md)) | Replace Redmine on the server and run migrations |
| Own code | Keep the project's own plugins (running on Lambda, S3 attachments, mail through SES) in step with Redmine updates ([upgrade.md](upgrade.md)) | Not needed (standard Redmine runs as is) |

## Which to choose

| Priority | Suitable setup |
| --- | --- |
| Run Redmine's code unchanged and keep the monthly cost fixed. Accept that the single server can stop and that you update it yourself | One Lightsail instance |
| Remove server maintenance for Redmine and make intrusion harder, at a lower fixed cost | This design with the NAT instance |
| In addition to the above, remove outbound traffic | This design with the VPC endpoints |
| Run Redmine unchanged, with only the database managed | EC2 and RDS |

## To verify

- The disk and transfer allowances of the 2 GB Lightsail instance
- Actual ALB LCU usage at this scale
