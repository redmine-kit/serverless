# shellcheck shell=bash
# Functions of deploy.sh, also loaded by the tests (test/deploy). They use
# the variables that deploy.sh sets: dry_run, tags, work, instance and
# cfn_role_arn.
# shellcheck disable=SC2154
# Secrets are never printed or passed on a command line: values go to the
# AWS CLI through JSON on standard input.

step() { printf '\n== %s\n' "$*" >&2; }
note() { printf '%s\n' "$*" >&2; }
fail() { printf 'deploy: %s\n' "$*" >&2; exit 1; }

# Creates or updates a stack through a change set. With --dry-run, shows the
# change set and deletes it (and the stack it would create).
#   deploy_stack <name> <region> <template> <parameters JSON>
deploy_stack() {
  local name="$1" region="$2" template="$3" params="$4" type=UPDATE change reason
  change="deploy-$(date +%Y%m%d%H%M%S)"
  if ! aws cloudformation describe-stacks --region "$region" --stack-name "$name" >/dev/null 2>&1; then
    type=CREATE
  fi
  printf '%s' "$params" >"$work/params.json"
  printf '%s' "$tags" >"$work/tags.json"
  local cs=(--region "$region" --stack-name "$name" --change-set-name "$change")
  aws cloudformation create-change-set "${cs[@]}" --change-set-type "$type" \
    --template-body "file://$template" --parameters "file://$work/params.json" \
    --tags "file://$work/tags.json" --capabilities CAPABILITY_NAMED_IAM \
    --role-arn "$cfn_role_arn" >/dev/null
  if ! aws cloudformation wait change-set-create-complete "${cs[@]}" 2>/dev/null; then
    reason=$(aws cloudformation describe-change-set "${cs[@]}" --query StatusReason --output text)
    aws cloudformation delete-change-set "${cs[@]}"
    if [[ "$reason" == *"didn't contain changes"* || "$reason" == *"No updates are to be performed"* ]]; then
      note "$name: no changes"
      return 0
    fi
    fail "$name: $reason"
  fi
  note "$name ($region): $type"
  aws cloudformation describe-change-set "${cs[@]}" --output text \
    --query 'Changes[].ResourceChange.[Action, LogicalResourceId, ResourceType, Replacement]' >&2
  if $dry_run; then
    aws cloudformation delete-change-set "${cs[@]}"
    if [[ "$type" == CREATE ]]; then
      aws cloudformation delete-stack --region "$region" --stack-name "$name"
    fi
    return 0
  fi
  aws cloudformation execute-change-set "${cs[@]}"
  if [[ "$type" == CREATE ]]; then
    aws cloudformation wait stack-create-complete --region "$region" --stack-name "$name"
  else
    aws cloudformation wait stack-update-complete --region "$region" --stack-name "$name"
  fi
  note "$name: done"
}

# An output of a stack.
#   output <stack> <region> <output key>
output() {
  aws cloudformation describe-stacks --region "$2" --stack-name "$1" \
    --query "Stacks[0].Outputs[?OutputKey=='$3'].OutputValue | [0]" --output text
}

# Puts a parameter if it does not exist yet; an existing value is kept. The
# value comes on standard input.
#   put_new_parameter <name> <SecureString | String>
put_new_parameter() {
  local value
  value=$(cat)
  if aws ssm get-parameter --name "$1" >/dev/null 2>&1; then
    note "$1: kept"
    return 0
  fi
  jq -n --arg name "$1" --arg type "$2" --arg value "$value" '{Name: $name, Type: $type, Value: $value}' |
    aws ssm put-parameter --cli-input-json file:///dev/stdin >/dev/null
  note "$1: created"
}

# Creates the secrets of an instance that do not exist yet
# (docs/deploy-config.md#secrets): SECRET_KEY_BASE, the database password and
# the key pair of the CloudFront signed URLs.
create_secrets() {
  openssl rand -hex 64 | put_new_parameter "/$instance/env/SECRET_KEY_BASE" SecureString
  # RDS does not take / @ " or spaces in the password; hex has none of them.
  openssl rand -hex 32 | put_new_parameter "/$instance/env/REDMINE_DB_PASSWORD" SecureString
  if ! aws ssm get-parameter --name "/$instance/deploy/CLOUDFRONT_PUBLIC_KEY" >/dev/null 2>&1; then
    openssl genrsa -out "$work/cloudfront.pem" 2048 2>/dev/null
    openssl rsa -in "$work/cloudfront.pem" -pubout -out "$work/cloudfront.pub" 2>/dev/null
    put_new_parameter "/$instance/env/REDMINE_CLOUDFRONT_PRIVATE_KEY" SecureString <"$work/cloudfront.pem"
    rm -f "$work/cloudfront.pem"
    put_new_parameter "/$instance/deploy/CLOUDFRONT_PUBLIC_KEY" String <"$work/cloudfront.pub"
  fi
}

# Applies the retention period to the log groups of the Lambda@Edge function
# in every Region where it has run: Lambda@Edge creates them itself, so
# CloudFormation cannot (docs/security.md#retention-periods).
#   edge_log_retention <days>
edge_log_retention() {
  local group=/aws/lambda/us-east-1.redmine-body-hash region
  for region in $(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do
    if [[ "$(aws logs describe-log-groups --region "$region" --log-group-name-prefix "$group" \
      --query "logGroups[?logGroupName=='$group'] | length(@)" --output text)" == 1 ]]; then
      aws logs put-retention-policy --region "$region" --log-group-name "$group" --retention-in-days "$1"
      note "$group ($region): $1 days"
    fi
  done
}

# Invokes <instance>-task synchronously and fails when the command does not
# exit with 0 (docs/tasks.md). The command's output goes to standard error.
#   task <JSON event>
task() {
  local response="$work/task.json"
  printf '%s' "$1" >"$work/event.json"
  aws lambda invoke --function-name "$instance-task" --cli-binary-format raw-in-base64-out \
    --cli-read-timeout 960 --payload "fileb://$work/event.json" "$response" >/dev/null
  jq -r '.output // .errorMessage // ""' "$response" >&2
  [[ "$(jq -r '.exit_code // "none"' "$response")" == 0 ]] || fail "task failed: $(jq -c '.args // .command' "$work/event.json")"
}

# The Ruby code for rails runner that applies redmine.settings and
# redmine.pluginSettings. The JSON goes in hex, so no quoting reaches Ruby.
# With settingsMode "initial", only settings that are not stored yet are set.
# A plugin's values are merged into its stored settings, which can hold
# other keys.
#   settings_code <settings JSON>
settings_code() {
  local hex
  hex=$(printf '%s' "$1" | od -An -v -tx1 | tr -d ' \n')
  cat <<RUBY
c = JSON.parse(['$hex'].pack('H*'))
apply = lambda do |name, &value|
  stored = Setting.where(name: name).exists?
  return false if c['mode'] == 'initial' && stored

  Setting[name] = value.call(stored)
  true
end
done = c['settings'].count { |name, value| apply.call(name) { value } }
done += c['plugins'].count do |plugin, values|
  apply.call("plugin_#{plugin}") { |stored| (stored ? Setting["plugin_#{plugin}"].to_h.transform_keys(&:to_s) : {}).merge(values) }
end
puts "settings: #{done} applied (#{c['mode']})"
RUBY
}
