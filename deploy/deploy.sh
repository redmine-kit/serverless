#!/usr/bin/env bash
# The steps of bin/deploy (docs/deploy-config.md#deployment-commands). Runs
# in the tools image (deploy/Dockerfile) with the repository at /work.
#   deploy.sh <redmine.json> [--dry-run] [--code-only | --account]
# jq programs are in single quotes on purpose.
# shellcheck disable=SC2016
set -euo pipefail
umask 077
root=${DEPLOY_ROOT:-/work}
# shellcheck source=deploy/lib.sh
source "$root/deploy/lib.sh"

usage() { echo "usage: bin/deploy <redmine.json> [--dry-run] [--code-only | --account]" >&2; exit 64; }
config="" dry_run=false code_only=false account_only=false
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=true ;;
    --code-only) code_only=true ;;
    --account) account_only=true ;;
    -*) usage ;;
    *) [[ -z "$config" ]] || usage; config="$arg" ;;
  esac
done
[[ -n "$config" ]] || usage
! $code_only || ! $account_only || usage
cfg() { jq -r "$1" "$config"; }
params() { jq -c -L "$root/deploy" "include \"params\"; $1" "${@:2}"; }

# 1. The configuration against the JSON Schema.
step "1. Check the configuration"
check-jsonschema --schemafile "$root/schema/redmine.schema.json" "$config" >&2

instance=$(cfg '.instance // "redmine"')
region=$(cfg '.region')
domain=$(cfg '.domain')
dns_mode=$(cfg '.dns.mode // "route53"')
stack="$instance" edge_stack="$instance-edge"
account=$(cut -d: -f5 <<<"$(cfg '.deployRoleArn')")
# CloudFormation creates the resources with its service role
# (docs/iam.md#role-for-deploying-infrastructure).
cfn_role_arn="arn:$(cut -d: -f2 <<<"$(cfg '.deployRoleArn')"):iam::$account:role/redmine-cfn-exec"
tags=$(params stack_tags "$config")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export AWS_DEFAULT_REGION="$region" AWS_PAGER=""

# The account's roles (infra/account.yaml), once per account by an
# administrator with their own credentials, before everything else: the
# role for deploying and the CloudFormation service role do not exist yet.
if $account_only; then
  step "Account roles"
  cfn_role_arn="" deploy_stack redmine-account "$region" "$root/infra/account.yaml" "$(params account_params "$config")"
  note "done; deployRoleArn is $(cfg '.deployRoleArn')"
  exit 0
fi

# The role for deploying infrastructure
# (docs/iam.md#role-for-deploying-infrastructure), unless the credentials
# are already that role's. --code-only runs with the credentials it is given,
# such as the role for deploying code in GitHub Actions.
role_arn=$(cfg '.deployRoleArn')
caller=$(aws sts get-caller-identity --query Arn --output text)
if ! $code_only && [[ "$caller" != *":assumed-role/${role_arn##*/}/"* ]]; then
  step "Assume ${role_arn}"
  creds=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "deploy-$instance" \
    --query Credentials --output json)
  AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId <<<"$creds")
  AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey <<<"$creds")
  AWS_SESSION_TOKEN=$(jq -r .SessionToken <<<"$creds")
  export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
  unset creds AWS_PROFILE
fi

image_repository=$(cfg '.image.repository // "ghcr.io/redmine-kit/serverless"')
image_digest=$(cfg '.image.digest // ""')
if [[ -z "$image_digest" ]]; then
  image_digest=$(crane digest "$image_repository:main")
  note "image.digest is not set: $image_repository:main is $image_digest now; pin it in redmine.json"
fi

first_time=false
aws cloudformation describe-stacks --stack-name "$stack" >/dev/null 2>&1 || first_time=true
if $code_only && $first_time; then
  fail "--code-only needs a deployed instance; run bin/deploy without it first"
fi

# The instance stack with an image; the other values come from the stacks in
# us-east-1 and from SSM.
instance_stack() { # <image URI>
  local public_key
  public_key=$(aws ssm get-parameter --name "/$instance/deploy/CLOUDFRONT_PUBLIC_KEY" \
    --query Parameter.Value --output text)
  deploy_stack "$stack" "$region" "$root/infra/instance.yaml" "$(params \
    'instance_params($image; $cert; $acl; $hash; $key)' --arg image "$1" \
    --arg cert "$(output "$edge_stack" us-east-1 CertificateArn)" \
    --arg acl "$(output "$edge_stack" us-east-1 WebAclArn)" \
    --arg hash "$(output redmine-shared-edge us-east-1 FunctionVersionArn)" \
    --arg key "$public_key" "$config")"
}

if ! $code_only; then
  # 2. The shared base, in the Region and in us-east-1.
  step "2. Shared base"
  deploy_stack redmine-shared "$region" "$root/infra/shared.yaml" "$(params shared_params "$config")"
  code_sha=$(sha256sum "$root/edge/body-hash/index.js" | cut -d' ' -f1)
  deploy_stack redmine-shared-edge us-east-1 "$root/infra/shared-edge.yaml" \
    "$(params 'shared_edge_params($sha)' -n --arg sha "$code_sha")"
  if [[ "$(cfg '.mail.receive != false')" == true ]] && ! $dry_run; then
    # A Region has one active rule set; the instances share it (docs/mail.md).
    aws ses set-active-receipt-rule-set --rule-set-name "$(output redmine-shared "$region" ReceiptRuleSetName)"
  fi

  # 3. Secrets in SSM, before the instance stack (RDS reads the password).
  step "3. Secrets"
  if ! $dry_run; then
    create_secrets
  fi

  # 4. The certificate and the web ACL in us-east-1.
  step "4. Certificate and web ACL"
  if [[ "$dns_mode" == external ]] && ! $dry_run && $first_time; then
    note "dns.mode external: while this step waits, add the certificate's validation record:"
    note "  aws acm list-certificates --region us-east-1 --query \"CertificateSummaryList[?DomainName=='$domain']\""
    note "  aws acm describe-certificate --region us-east-1 --certificate-arn <arn> --query Certificate.DomainValidationOptions"
  fi
  deploy_stack "$edge_stack" us-east-1 "$root/infra/instance-edge.yaml" "$(params instance_edge_params "$config")"
  if ! $dry_run; then
    edge_log_retention "$(cfg '.logs.retentionDays // 90')"
  fi
fi

if $dry_run; then
  if $first_time; then
    note "$stack: created on the first deployment"
  elif $code_only; then
    note "$stack: the functions get $image_digest"
  else
    step "Instance stack"
    instance_stack "$(output redmine-shared "$region" RepositoryUri)@$image_digest"
  fi
  note "dry run: nothing was changed"
  exit 0
fi

# 5. The image, from the registry into this account's ECR, by digest. The
# repository's tags are immutable, so the tag is made from the digest.
step "5. Image $image_repository@$image_digest"
repository_uri=$(output redmine-shared "$region" RepositoryUri)
image_uri="$repository_uri@$image_digest"
if aws ecr describe-images --repository-name "${repository_uri#*/}" --image-ids "imageDigest=$image_digest" >/dev/null 2>&1; then
  note "already in ECR"
else
  aws ecr get-login-password | crane auth login "${repository_uri%%/*}" -u AWS --password-stdin >/dev/null
  crane copy "$image_repository@$image_digest" "$repository_uri:sha256-${image_digest#sha256:}"
fi

# 6. Assets from the image to S3. Old files stay for pages that are still
# open in browsers.
assets() {
  step "6. Assets"
  crane export "$image_uri" - | tar -x -C "$work" var/task/redmine/public/assets
  local bucket
  bucket=$(output "$stack" "$region" AssetsBucketName)
  aws s3 sync "$work/var/task/redmine/public/assets" "s3://$bucket/assets/" --only-show-errors
  aws s3 cp "$root/deploy/maintenance.html" "s3://$bucket/assets/maintenance.html" \
    --content-type 'text/html; charset=utf-8' --cache-control no-store --only-show-errors
}

# 7. Migrations. The first time, the stack is created with the image. Later,
# the task gets the new image first; web and worker follow in step 9, so
# they never run code newer than the database.
if $first_time; then
  step "7. Instance stack"
  instance_stack "$image_uri"
  assets
else
  assets
  step "7. Migrations"
  if ! $code_only; then
    instance_stack "$(aws lambda get-function --function-name "$instance-task" --query Code.ImageUri --output text)"
  fi
  aws lambda update-function-code --function-name "$instance-task" --image-uri "$image_uri" >/dev/null
  aws lambda wait function-updated-v2 --function-name "$instance-task"
fi
task '{"command": "rake", "args": ["db:migrate"]}'
task '{"command": "rake", "args": ["redmine:plugins:migrate"]}'

# 8. The default data (trackers, statuses, roles), the first time.
if $first_time; then
  step "8. Default data"
  task "$(jq -nc --arg lang "$(cfg '.redmine.settings.default_language // "en"')" \
    '{command: "rake", args: ["redmine:load_default_data"], env: {REDMINE_LANG: $lang}}')"
fi

# 9. web and worker on the new image, through the stack so that it holds the
# image (--code-only: directly, as the task above).
step "9. Functions"
if $first_time; then
  note "created with the image in step 7"
elif $code_only; then
  for role in web worker; do
    aws lambda update-function-code --function-name "$instance-$role" --image-uri "$image_uri" >/dev/null
    aws lambda wait function-updated-v2 --function-name "$instance-$role"
  done
else
  instance_stack "$image_uri"
fi

# 10. Redmine's settings and the plugins' settings (redmine.settingsMode).
if ! $code_only; then
  step "10. Settings"
  settings=$(jq -c '{mode: (.redmine.settingsMode // "initial"), settings: (.redmine.settings // {}),
    plugins: (.redmine.pluginSettings // {})}' "$config")
  task "$(jq -nc --arg code "$(settings_code "$settings")" '{command: "runner", args: [$code]}')"
fi

# 11. Checks after deployment (docs/testing.md#checks-after-deployment).
step "11. Checks"
# Through the distribution's own name, so that the checks do not wait for DNS.
distribution=$(output "$stack" "$region" DistributionDomainName)
curl() { command curl -s --connect-to "$domain:443:$distribution:443" "$@"; }
base="https://$domain"
status=$(curl -D "$work/headers" -o /dev/null -w '%{http_code}' "$base/login")
[[ "$status" == 200 ]] || fail "$base/login answered $status"
grep -qi '^strict-transport-security:' "$work/headers" || fail "$base/login has no Strict-Transport-Security"
note "$base/login: 200 with Strict-Transport-Security"
status=$(curl -o /dev/null -w '%{http_code}' "$base/files/deploy-check")
[[ "$status" == 403 ]] || fail "$base/files/ without a signature answered $status, not 403"
note "$base/files/: 403 without a signature"
if [[ "$dns_mode" == external ]]; then
  note "dns.mode external: point $domain to $distribution (CNAME),"
  note "and add the DKIM and MX records: aws sesv2 get-email-identity --email-identity $domain"
fi
note "done"
