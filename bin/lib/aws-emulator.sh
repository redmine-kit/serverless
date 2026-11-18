# shellcheck shell=bash
# shellcheck disable=SC2154 # $cli comes from bin/lib/container.sh, sourced first
# Sourced by bin/test-services, bin/test-image and bin/test-core after
# bin/lib/container.sh: the services of the tests, PostgreSQL 16 and AWS
# Emulator. In Docker, test/compose.yml (Compose project serverless-test),
# with the networks serverless-test_default and serverless-test_internal. In
# Apple container, which has no Compose, the same containers on the networks
# serverless-test and serverless-test-internal (an internal network: no way out
# to AWS); containers find each other there by address, not by name.
compose=(docker compose -f test/compose.yml -p serverless-test)
# The certificate that the emulator writes at each start, inside its container.
emulator_ca=/home/emulator/.aws/emulator/9297/ca.pem
if [[ "$cli" == docker ]]; then
  default_network=serverless-test_default
  internal_network=serverless-test_internal
else
  default_network=serverless-test
  internal_network=serverless-test-internal
fi

# The images of test/compose.yml, for Apple container.
compose_image() { sed -n "s/^    image: //p" test/compose.yml | grep "^$1" | head -1; }

# services_up: starts PostgreSQL and AWS Emulator and waits until they answer.
services_up() {
  if [[ "$cli" == docker ]]; then
    if ! "${compose[@]}" up -d --build --wait; then
      "${compose[@]}" ps -a
      "${compose[@]}" logs --tail 80
      return 1
    fi
    return
  fi
  local image
  image=serverless-test-aws-emulator:$(shasum test/aws-emulator/Dockerfile | cut -c1-12)
  container image inspect "$image" >/dev/null 2>&1 ||
    image_build -- -t "$image" -f test/aws-emulator/Dockerfile test/aws-emulator
  container network inspect "$default_network" >/dev/null 2>&1 || container network create "$default_network" >/dev/null
  container network inspect "$internal_network" >/dev/null 2>&1 ||
    container network create --internal "$internal_network" >/dev/null
  if ! container_running serverless-test-postgres; then
    container rm -f serverless-test-postgres >/dev/null 2>&1 || true
    container run -d --name serverless-test-postgres --network "$default_network" --network "$internal_network" \
      -m 1G --progress none -e POSTGRES_HOST_AUTH_METHOD=trust "$(compose_image postgres)" >/dev/null
  fi
  if ! container_running serverless-test-aws-emulator || ! container inspect serverless-test-aws-emulator | grep -q "$image"; then
    container rm -f serverless-test-aws-emulator >/dev/null 2>&1 || true
    container run -d --name serverless-test-aws-emulator --network "$internal_network" -m 2G --progress none \
      "$image" --auth off >/dev/null
  fi
  local _
  for _ in $(seq 60); do
    container exec serverless-test-postgres pg_isready -q -U postgres &&
      container exec serverless-test-aws-emulator curl -fsk https://127.0.0.1:9297/__admin/health >/dev/null 2>&1 &&
      return 0
    sleep 2
  done
  echo "the services did not start: container logs serverless-test-postgres (or serverless-test-aws-emulator)" >&2
  return 1
}

# services_down: stops them.
services_down() {
  if [[ "$cli" == docker ]]; then
    "${compose[@]}" down -v
    return
  fi
  container rm -f serverless-test-postgres serverless-test-aws-emulator >/dev/null 2>&1 || true
  container network rm "$default_network" "$internal_network" >/dev/null 2>&1 || true
}

# The emulator's and PostgreSQL's containers.
emulator() { if [[ "$cli" == docker ]]; then "${compose[@]}" ps -q aws-emulator; else echo serverless-test-aws-emulator; fi; }
postgres() { if [[ "$cli" == docker ]]; then "${compose[@]}" ps -q postgres; else echo serverless-test-postgres; fi; }
# psql in the PostgreSQL container.
psql() { "$cli" exec "$(postgres)" psql "$@"; }
# The host names of PostgreSQL and the emulator: on the internal network, or
# on the default one (postgres_host default).
postgres_host() {
  if [[ "$cli" == docker ]]; then echo postgres; else container_address serverless-test-postgres "${1:-$internal_network}"; fi
}
emulator_host() {
  if [[ "$cli" == docker ]]; then echo aws-emulator; else container_address serverless-test-aws-emulator "$internal_network"; fi
}

# An SQS request in its JSON protocol (the emulator has no Query protocol),
# sent from inside the emulator's container: sqs <Action> <JSON>. The emulator
# takes the service from the credential scope of the Authorization header;
# with authentication off, the signature is not checked.
sqs() {
  "$cli" exec "$(emulator)" curl -fsS --cacert "$emulator_ca" -X POST https://127.0.0.1:9297/ \
    -H 'Content-Type: application/x-amz-json-1.0' -H "X-Amz-Target: AmazonSQS.$1" \
    -H 'Authorization: AWS4-HMAC-SHA256 Credential=test/20260101/us-east-1/sqs/aws4_request, SignedHeaders=host, Signature=0' \
    -d "$2"
}

# Fails if a container can open a connection to AWS (any answer counts, also
# one with a certificate error).
aws_unreachable() { # <container>
  local host
  for host in sts.amazonaws.com ssm.us-east-1.amazonaws.com sqs.us-east-1.amazonaws.com; do
    if "$cli" exec "$1" curl -ks -o /dev/null --connect-timeout 5 "https://$host/"; then
      echo "$host is reachable from $1" >&2
      return 1
    fi
  done
}
