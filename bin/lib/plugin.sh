# shellcheck shell=bash
# Sourced by the scripts that build the image. The image takes the plugins at
# the commits pinned in image/Dockerfile. With REDMINE_SERVERLESS_DIR or
# REDMINE_SERVERLESS_SSM_DIR set to a checkout of the plugin, it takes that
# working tree instead (the files git tracks or would track), for working on
# several repositories at once:
#   REDMINE_SERVERLESS_SSM_DIR=../redmine_serverless_ssm bin/test-image
# Used by the scripts that source this file.
# shellcheck disable=SC2034
plugin_context=()
# export_plugin <stage> <checkout>
export_plugin() {
  local out="${TMPDIR:-/tmp}/redmine-kit-serverless-$1"
  rm -rf "$out"
  mkdir -p "$out"
  git -C "$2" ls-files -z --cached --others --exclude-standard |
    tar -C "$2" --null -T - -cf - | tar -C "$out" -xf -
  plugin_context+=(--build-context "$1=$out")
}
[[ -z "${REDMINE_SERVERLESS_DIR:-}" ]] || export_plugin plugin "$REDMINE_SERVERLESS_DIR"
[[ -z "${REDMINE_SERVERLESS_SSM_DIR:-}" ]] || export_plugin plugin-ssm "$REDMINE_SERVERLESS_SSM_DIR"
