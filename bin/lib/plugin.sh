# shellcheck shell=bash
# Sourced by the scripts that build the image. The image takes the plugin
# redmine_serverless at the commit pinned in image/Dockerfile. With
# REDMINE_SERVERLESS_DIR set to a checkout of the plugin, it takes that
# working tree instead (the files git tracks or would track), for working on
# both repositories at once:
#   REDMINE_SERVERLESS_DIR=../redmine_serverless bin/test-core
# Used by the scripts that source this file.
# shellcheck disable=SC2034
plugin_context=()
if [[ -n "${REDMINE_SERVERLESS_DIR:-}" ]]; then
  plugin_export="${TMPDIR:-/tmp}/redmine-kit-serverless-plugin"
  rm -rf "$plugin_export"
  mkdir -p "$plugin_export"
  git -C "$REDMINE_SERVERLESS_DIR" ls-files -z --cached --others --exclude-standard |
    tar -C "$REDMINE_SERVERLESS_DIR" --null -T - -cf - | tar -C "$plugin_export" -xf -
  # shellcheck disable=SC2034
  plugin_context=(--build-context "plugin=$plugin_export")
fi
