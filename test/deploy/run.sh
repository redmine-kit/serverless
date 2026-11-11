#!/usr/bin/env bash
# Tests of bin/deploy without AWS (docs/testing.md#deployment-tests). Runs in
# the tools image (deploy/Dockerfile) with the repository at /work:
#   - the JSON Schema against valid and invalid configurations
#   - the stack parameters of deploy/params.jq against the templates
#   - the cache behaviors of the distribution (behaviors.py)
#   - deploy.sh against fake aws, crane and curl (test/deploy/fake), which
#     record every call: the order of the steps, --dry-run, --code-only,
#     failures, and that no secret reaches a command line or the output
# Strings with $ and backquotes are in single quotes on purpose.
# shellcheck disable=SC2016
set -uo pipefail
cd /work || exit 1
failures=0
pass() { printf 'ok: %s\n' "$1"; }
flunk() { printf 'FAILED: %s\n' "$1"; failures=$((failures + 1)); }
check() { # <description> <command...>
  local description="$1"
  shift
  if "$@"; then pass "$description"; else flunk "$description"; fi
}
schema() { check-jsonschema --schemafile schema/redmine.schema.json "$1" >/dev/null 2>&1; }

echo "== Schema"
check "the example in docs/deploy-config.md is valid" schema <(
  sed -n '/^### Example/,/^##/p' docs/deploy-config.md | sed -n '/^```json$/,/^```$/p' | sed '1d;$d')
for file in test/deploy/valid/*.json; do
  check "valid: $(basename "$file")" schema "$file"
done
check "valid: test/derived/redmine.json (plugins and themes)" schema test/derived/redmine.json
check "the plugins and themes example in docs/deploy-config.md is valid" schema <(
  sed -n '/^### Adding plugins and themes/,/^## /p' docs/deploy-config.md | sed -n '1,/^```$/p' |
    sed -n '/^```json$/,/^```$/p' | sed '1d;$d' | jq -s '.[0] * .[1]' test/deploy/valid/minimal.json -)
for file in test/deploy/invalid/*.json; do
  check "invalid: $(basename "$file" .json)" bash -c "! check-jsonschema --schemafile schema/redmine.schema.json '$file' >/dev/null 2>&1"
done

echo "== Stack parameters"
params() { jq -c -L deploy "include \"params\"; $1" "${@:2}"; }
# The parameters of a template: "name default|required" per line.
template_params() {
  awk '/^Parameters:/ { on = 1; next } on && /^[A-Za-z]/ { on = 0 }
    on && /^  [A-Za-z0-9]+:$/ { if (name) print name, kind; name = substr($1, 1, length($1) - 1); kind = "required" }
    on && /^    Default:/ { kind = "default" }
    END { if (name) print name, kind }' "$1"
}
# Every key is a parameter of the template, and every parameter without a
# default is given.
matches_template() { # <parameters JSON> <template>
  local keys missing unknown
  keys=$(jq -r '.[].ParameterKey' <<<"$1" | sort)
  unknown=$(comm -23 <(echo "$keys") <(template_params "$2" | cut -d' ' -f1 | sort))
  missing=$(comm -13 <(echo "$keys") <(template_params "$2" | awk '$2 == "required" { print $1 }' | sort))
  [[ -z "$unknown$missing" ]] || { echo "  unknown: ${unknown:-none}; missing: ${missing:-none}"; return 1; }
}
arn=arn:aws:acm:us-east-1:111122223333:certificate/x
for file in test/deploy/valid/*.json; do
  name=$(basename "$file")
  check "$name: account.yaml" matches_template "$(params 'account_params("true"; "true")' "$file")" infra/account.yaml
  check "$name: shared.yaml" matches_template "$(params shared_params "$file")" infra/shared.yaml
  check "$name: shared-edge.yaml" matches_template "$(params 'shared_edge_params("0")' -n)" infra/shared-edge.yaml
  check "$name: instance-edge.yaml" matches_template "$(params instance_edge_params "$file")" infra/instance-edge.yaml
  check "$name: instance.yaml" matches_template \
    "$(params 'instance_params("i"; "c"; "a"; "h"; "k")' "$file")" infra/instance.yaml
done
value() { jq -r --arg k "$2" '.[] | select(.ParameterKey == $k) | .ParameterValue' <<<"$1"; }
minimal=$(params 'instance_params("img"; "'$arn'"; "acl"; "hash"; "key")' test/deploy/valid/minimal.json)
full=$(params 'instance_params("img"; "'$arn'"; "acl"; "hash"; "key")' test/deploy/valid/full.json)
check "defaults: instance redmine, 100 MB uploads, malware scan, mail on, reminders off" test \
  "$(value "$minimal" InstanceName) $(value "$minimal" MaxUploadBytes) $(value "$minimal" MalwareScan) $(value "$minimal" ReceiveMail) $(value "$minimal" SendReminders)" \
  == "redmine 104857600 true true false"
check "values: the hosted zone only with route53" test \
  "$(value "$minimal" HostedZoneId)|$(value "$full" HostedZoneId)" == "Z0123456789ABCDEFGHIJ|"
check "values: full.json" test \
  "$(value "$full" InstanceName) $(value "$full" MalwareScan) $(value "$full" DbInstanceClass) $(value "$full" ReceiveMail) $(value "$full" ScheduleTimezone) $(value "$full" LogRetentionDays)" \
  == "team-a false db.t4g.small false Asia/Tokyo 365"
check "values: the records' retention, 90 days by default" test \
  "$(value "$minimal" RecordsDays) $(value "$full" RecordsDays)" == "90 60"
check "values: Cost Explorer off by default, on in full.json" test \
  "$(value "$minimal" CostExplorerEnabled)|$(value "$minimal" CostExplorerTagKey)|$(value "$full" CostExplorerEnabled)|$(value "$full" CostExplorerTagKey)" == \
  "false||true|redmine:instance"
check "values: the values from other stacks" test \
  "$(value "$full" ImageUri) $(value "$full" CertificateArn) $(value "$full" CloudFrontPublicKey)" == "img $arn key"
edge=$(params instance_edge_params test/deploy/valid/full.json)
check "values: the web ACL settings" test \
  "$(value "$edge" CommonRuleSetAction) $(value "$edge" LoginRateLimit) $(value "$edge" CommonRuleSetCountOnly)" \
  == "block 30 SizeRestrictions_BODY"
check "tags: redmine:instance first, then the configuration's" test \
  "$(params stack_tags test/deploy/valid/full.json)" == \
  '[{"Key":"redmine:instance","Value":"team-a"},{"Key":"team","Value":"a"},{"Key":"cost-center","Value":"1234"}]'

echo "== CloudFront behaviors"
behaviors_problems=$(python3.13 test/deploy/behaviors.py infra/instance.yaml 2>&1)
check "the behaviors fit the Free plan and /favicons/* is cached without cookies" test -z "$behaviors_problems"
[[ -z "$behaviors_problems" ]] || echo "$behaviors_problems"

echo "== Settings code"
# shellcheck source=deploy/lib.sh
source deploy/lib.sh
settings='{"mode":"initial","settings":{"app_title":"It'"'"'s \"quoted\" `x` $(y)"},"plugins":{}}'
hex=$(settings_code "$settings" | sed -n "s/.*\['\([0-9a-f]*\)'\].*/\1/p")
check "the settings go through as hex, byte for byte" test \
  "$(python3.13 -c 'import sys; print(bytes.fromhex(sys.argv[1]).decode(), end="")' "$hex")" == "$settings"

echo "== deploy.sh with fake AWS"
export PATH="/work/test/deploy/fake:$PATH" DEPLOY_ROOT=/work
run_deploy() { # <state dir> <args...>; output in <state dir>/output
  local dir="$1"
  shift
  FAKE="$dir" deploy/deploy.sh "$@" >"$dir/output" 2>&1
}
# The calls match the patterns in this order, each after the one before.
in_order() { # <state dir> <pattern...>
  local dir="$1" previous=0 line
  shift
  for pattern in "$@"; do
    line=$(tail -n +"$((previous + 1))" "$dir/calls" | grep -n -m1 -E -- "$pattern" | cut -d: -f1)
    if [[ -z "$line" ]]; then
      echo "  not in order: $pattern"
      return 1
    fi
    previous=$((previous + line))
  done
}
none() { ! grep -q -E -- "$2" "$1/calls"; }
config=test/deploy/valid/minimal.json
state=$(mktemp -d)

# instance.yaml goes by URL (the other templates are smaller).
TEMPLATE_BODY_LIMIT=$(($(wc -c <infra/instance.yaml) - 1))
export TEMPLATE_BODY_LIMIT
check "first deployment succeeds" run_deploy "$state" "$config"
check "first deployment: the steps in order" in_order "$state" \
  "crane digest ghcr.io/redmine-kit/serverless:$(sed -n 's/^ARG REDMINE_VERSION=//p' image/Dockerfile)$" \
  "create-change-set .*--stack-name redmine-shared " \
  "create-change-set .*--stack-name redmine-shared-edge " \
  "ssm put-parameter" \
  "create-change-set .*--stack-name redmine-edge " \
  "crane copy ghcr.io/redmine-kit/serverless@sha256:b+ .*/redmine:sha256-b+" \
  "create-change-set .*--stack-name redmine " \
  "s3 sync .*s3://redmine-assets-" \
  'event .*"db:migrate"' \
  'event .*"redmine:plugins:migrate"' \
  'event .*"redmine:load_default_data".*"REDMINE_LANG":"en"' \
  'event \{"command":"runner"' \
  "curl .*https://redmine.example.com/login" \
  "curl .*https://redmine.example.com/files/"
check "first deployment: a template over the limit goes by URL" bash -c "
  grep -q 's3 cp /work/infra/instance.yaml s3://redmine-templates-111122223333-ap-northeast-1/redmine/' '$state/calls' &&
  grep -q 'create-change-set .*--stack-name redmine .*--template-url https://redmine-templates-111122223333-ap-northeast-1.s3.ap-northeast-1.amazonaws.com/redmine/' '$state/calls' &&
  grep -q 'create-change-set .*--stack-name redmine-shared .*--template-body file:///work/infra/shared.yaml' '$state/calls'"
check "first deployment: the stacks are created" test \
  "$(cat "$state"/params/{redmine-shared,redmine-shared-edge,redmine-edge,redmine}.type | tr '\n' ' ')" == "CREATE CREATE CREATE CREATE "
check "first deployment: the receipt rule set is activated" grep -q "ses set-active-receipt-rule-set --rule-set-name redmine-shared" "$state/calls"
check "first deployment: assumes deployRoleArn" grep -q "sts assume-role --role-arn arn:aws:iam::111122223333:role/redmine-infra-deploy" "$state/calls"
check "first deployment: CloudFormation uses its service role" bash -c \
  "! grep 'create-change-set' '$state/calls' | grep -qv -- '--role-arn arn:aws:iam::111122223333:role/redmine-cfn-exec'"
check "first deployment: the Lambda@Edge log groups get the retention period" bash -c "
  grep -q 'logs put-retention-policy --region us-east-1 .*--retention-in-days 90' '$state/calls' &&
  grep -q 'logs put-retention-policy --region ap-northeast-1 ' '$state/calls' &&
  ! grep -q 'logs put-retention-policy --region eu-west-1' '$state/calls'"
check "first deployment: the checks go through the distribution" grep -q -- "--connect-to redmine.example.com:443:d111111abcdef8.cloudfront.net:443" "$state/calls"
check "secrets: SECRET_KEY_BASE is 128 hex digits" grep -qxE '[0-9a-f]{128}' "$state/ssm/_redmine_env_SECRET_KEY_BASE"
check "secrets: the database password is 64 hex digits" grep -qxE '[0-9a-f]{64}' "$state/ssm/_redmine_env_REDMINE_DB_PASSWORD"
check "secrets: SecureString" test "$(cat "$state"/ssm/_redmine_env_*.type | sort -u)" == SecureString
check "secrets: the private key is an RSA key" openssl pkey -in "$state/ssm/_redmine_env_REDMINE_CLOUDFRONT_PRIVATE_KEY" -noout
check "secrets: the public key in the stack is the private key's" test \
  "$(value "$(cat "$state/params/redmine.json")" CloudFrontPublicKey)" == \
  "$(openssl pkey -in "$state/ssm/_redmine_env_REDMINE_CLOUDFRONT_PRIVATE_KEY" -pubout)"
no_secret_leaks() {
  local file
  for file in "$state"/ssm/_redmine_env_SECRET_KEY_BASE "$state"/ssm/_redmine_env_REDMINE_DB_PASSWORD; do
    ! grep -q -F -f "$file" "$state/calls" "$state/output" || return 1
  done
  ! grep -q -F "$(sed -n 2p "$state/ssm/_redmine_env_REDMINE_CLOUDFRONT_PRIVATE_KEY")" "$state/calls" "$state/output"
}
check "secrets: on no command line and not in the output" no_secret_leaks
check "secrets: no file of them is left" test -z "$(find /tmp -name parameter.json 2>/dev/null)"
check "the image in the stack is the account's ECR by digest" test \
  "$(value "$(cat "$state/params/redmine.json")" ImageUri)" == \
  "111122223333.dkr.ecr.ap-northeast-1.amazonaws.com/redmine@sha256:$(printf 'b%.0s' {1..64})"
settings_of() { # <state dir>: the JSON that the settings step sends
  local hex
  hex=$(grep '^event {"command":"runner"' "$1/calls" | tail -1 | grep -oE "\['[0-9a-f]+'\]" | tr -dc '0-9a-f')
  python3.13 -c 'import sys; print(bytes.fromhex(sys.argv[1]).decode())' "$hex"
}
check "settings: Redmine's attachment limit follows uploads.maxBytes" test \
  "$(settings_of "$state" | jq -c '[.mode, .settings.attachment_max_size]')" == '["initial","102400"]'
check "a note asks to pin image.digest" grep -q "pin it in redmine.json" "$state/output"

cp -r "$state/ssm" "$state/ssm.first"
: >"$state/calls"
check "second deployment succeeds" run_deploy "$state" "$config"
check "second deployment: the task migrates before web and worker get the image" in_order "$state" \
  "create-change-set .*--stack-name redmine " \
  "lambda update-function-code --function-name redmine-task" \
  'event .*"db:migrate"' \
  "create-change-set .*--stack-name redmine "
check "second deployment: the first update keeps the running image" test \
  "$(grep -c "create-change-set .*--stack-name redmine " "$state/calls")" == 2
check "second deployment: no default data" none "$state" "load_default_data"
same_files() { [[ "$(cd "$1" && grep -r . | sort)" == "$(cd "$2" && grep -r . | sort)" ]]; }
check "second deployment: the secrets are kept" same_files "$state/ssm.first" "$state/ssm"
check "second deployment: the stacks are updated" test "$(cat "$state/params/redmine.type")" == UPDATE

: >"$state/calls"
check "--dry-run succeeds" run_deploy "$state" "$config" --dry-run
check "--dry-run: change sets are made and deleted" in_order "$state" \
  "create-change-set .*--stack-name redmine " "delete-change-set .*--stack-name redmine "
check "--dry-run: nothing is executed, written or invoked" none "$state" \
  "execute-change-set|put-parameter|crane copy|lambda (invoke|update)|s3 sync|s3 cp /work/deploy|set-active"

: >"$state/calls"
check "--code-only succeeds" run_deploy "$state" "$config" --code-only
check "--code-only: with the credentials it is given" none "$state" "sts assume-role"
check "--code-only: no stack changes and no settings" none "$state" 'change-set|put-parameter|put-retention|"runner"'
check "--code-only: task, then web and worker" in_order "$state" \
  "update-function-code --function-name redmine-task" 'event .*"db:migrate"' \
  "update-function-code --function-name redmine-web" "update-function-code --function-name redmine-worker"

: >"$state/calls"
FAKE_NO_CHANGES=redmine-shared check "a stack without changes is not a failure" run_deploy "$state" "$config"
check "a stack without changes: its change set is deleted" grep -q "delete-change-set .*--stack-name redmine-shared " "$state/calls"

: >"$state/calls"
FAKE_TASK_FAIL=db:migrate check "a failed migration stops the deployment" bash -c "! FAKE='$state' deploy/deploy.sh $config >'$state/output' 2>&1"
check "a failed migration: web and worker keep their image" bash -c \
  "[[ \$(grep -c 'create-change-set .*--stack-name redmine ' '$state/calls') -le 2 ]] && grep -q 'task failed' '$state/output'"
FAKE_HSTS=0 check "a missing Strict-Transport-Security fails the checks" bash -c "! FAKE='$state' deploy/deploy.sh $config >/dev/null 2>&1"

account=$(mktemp -d)
check "--account succeeds" run_deploy "$account" test/deploy/valid/full.json --account
check "--account: only the account stack, with the caller's credentials" bash -c "
  [[ \$(grep -c create-change-set '$account/calls') == 1 ]] && grep -q 'stack-name redmine-account .*CAPABILITY_NAMED_IAM' '$account/calls' &&
  ! grep -q -e assume-role -e --role-arn '$account/calls'"
check "--account: the GitHub settings" test "$(value "$(cat "$account/params/redmine-account.json")" GitHubRepository) $(value "$(cat "$account/params/redmine-account.json")" GitHubCodeEnvironment)" == "example/redmine-deploy redmine"
check "--account: a trail when the account has none, no second access analyzer" test \
  "$(value "$(cat "$account/params/redmine-account.json")" CreateTrail) $(value "$(cat "$account/params/redmine-account.json")" CreateAccessAnalyzer)" == "true false"
account2=$(mktemp -d)
FAKE_HAS_TRAIL=1 check "--account with a trail in the account" run_deploy "$account2" test/deploy/valid/minimal.json --account
check "--account: no second trail" test "$(value "$(cat "$account2/params/redmine-account.json")" CreateTrail)" == false
account3=$(mktemp -d)
cfg3="$account3/redmine.json"
jq '.account = {cloudTrail: false, accessAnalyzer: true}' test/deploy/valid/minimal.json >"$cfg3"
check "--account with account.cloudTrail false and accessAnalyzer true" run_deploy "$account3" "$cfg3" --account
check "--account: as configured" test \
  "$(value "$(cat "$account3/params/redmine-account.json")" CreateTrail) $(value "$(cat "$account3/params/redmine-account.json")" CreateAccessAnalyzer)" == "false true"
check "--account with --code-only is refused" bash -c "! FAKE='$account' deploy/deploy.sh $config --account --code-only >/dev/null 2>&1"

fresh=$(mktemp -d)
check "--code-only before the first deployment fails" bash -c "! FAKE='$fresh' deploy/deploy.sh $config --code-only >/dev/null 2>&1"
fresh=$(mktemp -d)
check "an invalid configuration stops before AWS" bash -c \
  "! FAKE='$fresh' deploy/deploy.sh test/deploy/invalid/route53-without-zone.json >/dev/null 2>&1 && [[ ! -s '$fresh/calls' ]]"
full_state=$(mktemp -d)
check "full.json: first deployment succeeds" run_deploy "$full_state" test/deploy/valid/full.json
check "full.json: its own image and names, Japanese default data, no receipt rule set" bash -c "
  grep -q 'crane copy ghcr.io/example/redmine@sha256:0*1 ' '$full_state/calls' &&
  grep -q 'stack-name team-a-edge' '$full_state/calls' && grep -q 'function-name team-a-task' '$full_state/calls' &&
  grep -q 'REDMINE_LANG\":\"ja' '$full_state/calls' && ! grep -q set-active-receipt-rule-set '$full_state/calls' &&
  ! grep -q 'crane digest' '$full_state/calls'"
check "full.json: the settings and the attachment limit" test \
  "$(settings_of "$full_state" | jq -c '[.mode, .settings.attachment_max_size, .settings.app_title, .plugins.redmine_aws_s3.download_url_expiry]')" == \
  '["enforce","51200","Team A","600"]'
check "full.json: dns.mode external shows the records to add" grep -q "point redmine.example.org to d111111abcdef8.cloudfront.net" "$full_state/output"

echo "== deploy.sh with a derived image"
# bin/deploy builds the derived image of image.plugins and image.themes and
# passes it as a tarball; the fake crane gives it the digest d…d.
derived_config=test/derived/redmine.json
derived_state=$(mktemp -d)
check "image.plugins without the derived image stops before AWS" bash -c \
  "! FAKE='$derived_state' deploy/deploy.sh $derived_config >'$derived_state/output' 2>&1 && [[ ! -s '$derived_state/calls' ]] &&
  grep -q 'need the derived image' '$derived_state/output'"
tarball="$derived_state/image.tar"
: >"$tarball"
DERIVED_IMAGE="$tarball" check "a derived image without image.plugins and image.themes is refused" bash -c \
  "! FAKE='$derived_state' deploy/deploy.sh $config >/dev/null 2>&1"
DERIVED_IMAGE="$tarball" check "derived image: first deployment succeeds" run_deploy "$derived_state" "$derived_config"
check "derived image: pushed from the tarball by its digest, then the steps as usual" in_order "$derived_state" \
  "crane digest --tarball $tarball$" \
  "create-change-set .*--stack-name redmine-shared " \
  "crane push $tarball .*/redmine:sha256-d+$" \
  "create-change-set .*--stack-name redmine " \
  "crane export .*/redmine@sha256:d+ " \
  "s3 sync .*s3://redmine-assets-" \
  'event .*"redmine:plugins:migrate"'
check "derived image: no copy from the registry and no tag resolved" none "$derived_state" "crane (copy|digest ghcr)"
check "derived image: the stack gets it by digest" test \
  "$(value "$(cat "$derived_state/params/redmine.json")" ImageUri)" == \
  "111122223333.dkr.ecr.ap-northeast-1.amazonaws.com/redmine@sha256:$(printf 'd%.0s' {1..64})"
check "--account needs no derived image" run_deploy "$(mktemp -d)" "$derived_config" --account
check "derived image: the added plugin's settings" test \
  "$(settings_of "$derived_state" | jq -c '.plugins.redmine_derived_sample')" == '{"greeting":"hello"}'

echo
if ((failures)); then
  echo "$failures failed"
  exit 1
fi
echo "all deployment tests passed"
