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

# The networks of the tests in Apple container, shared by every Redmine Kit
# repository: one NAT network and one internal network (no way out, for the
# AWS tests), each with an anchor container that runs all the time. Apple
# container on macOS before 27.3 can give two NAT networks the same host
# bridge and deletes it when the last container of one of them stops, which
# leaves the other without its gateway: no DNS, no way out
# (apple/container#2051). Few networks whose bridges are never deleted avoid
# it. Container names stay per repository; the scripts never remove these
# networks or their anchors. Docker keeps a network per repository (Compose).
# shellcheck disable=SC2034 # used by the scripts that source this file
kit_test_network=redmine-kit-test
# shellcheck disable=SC2034
kit_test_internal_network=redmine-kit-test-internal

# ensure_shared_network <network> [--internal]: creates the network and starts
# its anchor (anchor-<network>) unless they exist and run, starts the anchor of
# the default network (image builds, the other scripts) too, and checks the network
# (check_network). Safe when several runs call it at once.
ensure_shared_network() {
  local network=$1
  shift
  container network inspect "$network" >/dev/null 2>&1 ||
    container network create "$@" "$network" >/dev/null 2>&1 ||
    container network inspect "$network" >/dev/null 2>&1 || # created by another run meanwhile
    { echo "Could not create the network $network: container network create $* $network" >&2; return 1; }
  ensure_network_anchor default && ensure_network_anchor "$network" && check_network "$network"
}

# ensure_network_anchor <network>: starts the anchor of the network unless it
# runs. Never removes it: another run may have just started it.
ensure_network_anchor() {
  local anchor=anchor-$1
  container inspect "$anchor" 2>/dev/null | grep -q '"state" : "running"' && return 0
  if container inspect "$anchor" >/dev/null 2>&1; then
    container start "$anchor" >/dev/null 2>&1 || true
  else
    container run -d --name "$anchor" --network "$1" -m 128M --cpus 1 --progress none \
      docker.io/library/alpine:3.22 sleep infinity >/dev/null 2>&1 || true
  fi
  container inspect "$anchor" 2>/dev/null | grep -q '"state" : "running"' ||
    { echo "The anchor of the network $1 did not start: container logs $anchor" >&2; return 1; }
}

# check_network <network>: fails with a message when the network's gateway is
# on no interface of the host, which is how apple/container#2051 shows.
check_network() {
  local gateway
  gateway=$(container network inspect "$1" 2>/dev/null | sed -n 's/.*"ipv4Gateway" : "\([0-9.]*\)".*/\1/p' | head -1)
  [[ -n "$gateway" ]] || return 0
  for _ in 1 2 3 4 5; do
    ifconfig | grep -q "inet $gateway " && return 0
    sleep 1
  done
  echo "The container network $1 is broken: its gateway $gateway is on no host interface (apple/container#2051)." >&2
  echo "Restart Apple container, then run this again: container system stop && container system start" >&2
  return 1
}
