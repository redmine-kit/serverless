# shellcheck shell=bash
# Sourced by the scripts that build the image.
#
# The plugin gems come from their public Git repositories (image/Gemfile.local),
# so a build needs no credential. A credential for a private repository, when
# one is needed (a derived image's), comes from BUNDLE_GITHUB__COM
# (x-access-token:<token>) and goes to the build as a secret, never into a
# layer.
# Used by the scripts that source this file.
# shellcheck disable=SC2034
build_secrets=()
if [[ -n "${BUNDLE_GITHUB__COM:-}" ]]; then
  export BUNDLE_GITHUB__COM
  build_secrets=(--secret "id=bundle_github,env=BUNDLE_GITHUB__COM")
fi

# A local checkout of a plugin replaces its gem, for working on several
# repositories at once: its working tree (the files git tracks or would track)
# goes to image/plugin-overrides/<gem>, inside the build context, so that
# Apple container and Docker build it alike. REDMINE_KIT_AWS_DIR,
# REDMINE_KIT_AWS_LAMBDA_DIR, REDMINE_KIT_AWS_SSM_DIR, REDMINE_KIT_AWS_SQS_DIR,
# REDMINE_KIT_AWS_SES_DIR and REDMINE_KIT_AWS_S3_DIR name one checkout;
# PLUGIN_CHECKOUTS names a directory that holds them all as
# redmine_kit_aws[_<part>]:
#   REDMINE_KIT_AWS_S3_DIR=../redmine_kit_aws_s3 bin/test-image
#   PLUGIN_CHECKOUTS=.. bin/build-image
plugin_gems=(redmine_kit_aws redmine_kit_aws_lambda redmine_kit_aws_ssm redmine_kit_aws_sqs
  redmine_kit_aws_ses redmine_kit_aws_s3)
overrides=image/plugin-overrides
find "$overrides" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
# export_plugin <gem> <checkout>
# shellcheck disable=SC2016 # the script of sh -c is in single quotes
export_plugin() {
  mkdir -p "$overrides/$1"
  git -C "$2" ls-files -z --cached --others --exclude-standard |
    (cd "$2" && xargs -0 sh -c 'for f; do if [ -e "$f" ]; then printf "%s\0" "$f"; fi; done' sh) |
    tar -C "$2" --null -T - -cf - | tar -C "$overrides/$1" -xf -
}
for gem in "${plugin_gems[@]}"; do
  variable=$(tr '[:lower:]' '[:upper:]' <<<"${gem}_dir")
  dir=${!variable:-}
  if [[ -z "$dir" && -n "${PLUGIN_CHECKOUTS:-}" && -d "$PLUGIN_CHECKOUTS/$gem" ]]; then
    dir=$PLUGIN_CHECKOUTS/$gem
  fi
  [[ -z "$dir" ]] || export_plugin "$gem" "$dir"
done
