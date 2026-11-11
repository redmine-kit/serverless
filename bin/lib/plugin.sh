# shellcheck shell=bash
# Sourced by the scripts that build the image.
#
# Bundler's credential for GitHub Packages, where the plugin gems are
# (image/Gemfile.local): a token with read:packages, passed to the build as a
# secret and never stored in a layer. CI sets BUNDLE_RUBYGEMS__PKG__GITHUB__COM
# from its GITHUB_TOKEN; locally it comes from the gh login.
if [[ -z "${BUNDLE_RUBYGEMS__PKG__GITHUB__COM:-}" ]]; then
  BUNDLE_RUBYGEMS__PKG__GITHUB__COM="x-access-token:$(gh auth token)"
fi
export BUNDLE_RUBYGEMS__PKG__GITHUB__COM
# Used by the scripts that source this file.
# shellcheck disable=SC2034
plugin_context=(--secret "id=bundle_github,env=BUNDLE_RUBYGEMS__PKG__GITHUB__COM")

# With REDMINE_AWS_DIR, REDMINE_AWS_LAMBDA_DIR, REDMINE_AWS_SSM_DIR,
# REDMINE_AWS_SQS_DIR, REDMINE_AWS_SES_DIR or REDMINE_AWS_S3_DIR set to a
# checkout of the plugin, its working tree (the files git tracks or would
# track) replaces the installed gem, for working on several repositories at
# once:
#   REDMINE_AWS_S3_DIR=../redmine_aws_s3 bin/test-image
overrides="${TMPDIR:-/tmp}/redmine-kit-serverless-plugin-overrides"
rm -rf "$overrides"
mkdir -p "$overrides"
# export_plugin <gem> <checkout>
export_plugin() {
  mkdir -p "$overrides/$1"
  git -C "$2" ls-files -z --cached --others --exclude-standard |
    tar -C "$2" --null -T - -cf - | tar -C "$overrides/$1" -xf -
}
[[ -z "${REDMINE_AWS_DIR:-}" ]] || export_plugin redmine_aws "$REDMINE_AWS_DIR"
[[ -z "${REDMINE_AWS_LAMBDA_DIR:-}" ]] || export_plugin redmine_aws_lambda "$REDMINE_AWS_LAMBDA_DIR"
[[ -z "${REDMINE_AWS_SSM_DIR:-}" ]] || export_plugin redmine_aws_ssm "$REDMINE_AWS_SSM_DIR"
[[ -z "${REDMINE_AWS_SQS_DIR:-}" ]] || export_plugin redmine_aws_sqs "$REDMINE_AWS_SQS_DIR"
[[ -z "${REDMINE_AWS_SES_DIR:-}" ]] || export_plugin redmine_aws_ses "$REDMINE_AWS_SES_DIR"
[[ -z "${REDMINE_AWS_S3_DIR:-}" ]] || export_plugin redmine_aws_s3 "$REDMINE_AWS_S3_DIR"
plugin_context+=(--build-context "plugin-overrides=$overrides")
