# Parameters of the stacks from redmine.json (docs/deploy-config.md), as the
# list that CloudFormation's create-change-set takes. Defaults are those of
# schema/redmine.schema.json. Values that come from other stacks or from
# SSM are passed with --arg / --argjson.

def instance: .instance // "redmine";
def p($key; $value): {ParameterKey: $key, ParameterValue: ($value | tostring)};

def shared_params:
  [ p("NetworkMode"; .network.mode // "endpoints") ];

def shared_edge_params($code_sha256):
  [ p("CodeSha256"; $code_sha256) ];

def instance_edge_params:
  [ p("InstanceName"; instance),
    p("Domain"; .domain),
    p("HostedZoneId"; (if (.dns.mode // "route53") == "route53" then .dns.hostedZoneId else "" end)),
    p("WebAclArn"; .cloudfront.webAclArn // ""),
    p("LoginRateLimit"; .waf.loginRateLimit // 20),
    p("RateLimit"; .waf.rateLimit // 1000),
    p("CommonRuleSetAction"; .waf.commonRuleSet // "count"),
    p("CommonRuleSetCountOnly"; (.waf.commonRuleSetCountOnly // ["SizeRestrictions_BODY"]) | join(",")) ];

def instance_params($image_uri; $certificate; $web_acl; $body_hash; $public_key):
  [ p("InstanceName"; instance),
    p("ImageUri"; $image_uri),
    p("Domain"; .domain),
    p("HostedZoneId"; (if (.dns.mode // "route53") == "route53" then .dns.hostedZoneId else "" end)),
    p("CertificateArn"; $certificate),
    p("WebAclArn"; $web_acl),
    p("BodyHashFunctionArn"; $body_hash),
    p("CloudFrontPublicKey"; $public_key),
    p("MaxUploadBytes"; .uploads.maxBytes // 104857600),
    p("DbMajorVersion"; .database.majorVersion),
    p("DbInstanceClass"; .database.instanceClass // "db.t4g.micro"),
    p("DbStorageGb"; .database.storageGb // 20),
    p("BackupDays"; .retention.backupDays // 7),
    p("WebMemoryMb"; .lambda.webMemoryMb // 2048),
    p("WebReservedConcurrency"; .lambda.webReservedConcurrency // 10),
    p("WorkerReservedConcurrency"; .lambda.workerReservedConcurrency // 3),
    p("LogRetentionDays"; .logs.retentionDays // 90),
    p("MailDays"; .retention.mailDays // 30),
    p("NoncurrentVersionDays"; .retention.noncurrentVersionDays // 30),
    p("ReceiveMail"; if .mail.receive == false then "false" else "true" end),
    p("SendReminders"; if .schedule.sendReminders == true then "true" else "false" end),
    p("ScheduleTimezone"; .schedule.timezone // "UTC"),
    p("AlarmTopicArn"; .alarms.snsTopicArn // "") ];

# Tags of every stack: redmine:instance and the tags of redmine.json.
def stack_tags:
  [{Key: "redmine:instance", Value: instance}] + ((.tags // {}) | to_entries | map({Key: .key, Value: .value}));
