# shellcheck shell=bash
# Sourced by the scripts in bin/: the container CLI to use in $cli, Apple
# container when it is installed and running, else Docker (other machines,
# CI); CONTAINER_CLI=container|docker chooses. With the helpers the scripts
# share for both tools.
# The status check is tried three times: on a busy machine it can fail once.
cli=${CONTAINER_CLI:-}
if [[ -z "$cli" ]]; then
  cli=docker
  if command -v container >/dev/null; then
    for _ in 1 2 3; do
      if container system status >/dev/null 2>&1; then cli=container && break; fi
      sleep 2
    done
  fi
fi

# image_build [<option for Docker only>...] -- <option>...: builds an image.
# Docker builds with Buildx and loads the image (the options before --, such
# as --provenance=false); Apple container keeps what it builds, and its log is
# shown only when the build fails (`container build -q` doesn't return).
image_build() {
  local docker_only=()
  while (($#)) && [[ "$1" != -- ]]; do docker_only+=("$1"); shift; done
  shift
  if [[ "$cli" == docker ]]; then
    docker buildx build ${docker_only[@]+"${docker_only[@]}"} "$@"
    return
  fi
  local log status=0
  log=$(mktemp)
  container build --progress plain "$@" >"$log" 2>&1 || status=$?
  ((status == 0)) || tail -n 60 "$log" >&2
  rm -f "$log"
  return "$status"
}

# container_address <name> [<network>]: the IPv4 address of a running Apple
# container, on the network given or its first one. Containers on a network
# of their own don't find each other by name there, so the scripts pass
# addresses.
container_address() {
  container inspect "$1" | awk -v net="${2:-}" '
    /"ipv4Address"/ { split($0, a, "\""); ip = a[4]; sub(/\/.*/, "", ip) }
    /"network" :/ { split($0, b, "\""); if (ip != "" && (net == "" || b[4] == net)) { print ip; exit } }'
}

# container_running <name>: whether the Apple container runs.
container_running() {
  container inspect "$1" 2>/dev/null | grep -q '"state" : "running"'
}
