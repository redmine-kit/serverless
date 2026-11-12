# shellcheck shell=bash
# Sourced by bin/test-services and bin/test-image: AWS Emulator of
# test/compose.yml (Compose project serverless-test).
compose=(docker compose -f test/compose.yml -p serverless-test)
# The certificate that the emulator writes at each start, inside its container.
emulator_ca=/home/emulator/.aws/emulator/9297/ca.pem

# The emulator's container.
emulator() { "${compose[@]}" ps -q aws-emulator; }

# An SQS request in its JSON protocol (the emulator has no Query protocol),
# sent from inside the emulator's container: sqs <Action> <JSON>. The emulator
# takes the service from the credential scope of the Authorization header;
# with authentication off, the signature is not checked.
sqs() {
  docker exec "$(emulator)" curl -fsS --cacert "$emulator_ca" -X POST https://127.0.0.1:9297/ \
    -H 'Content-Type: application/x-amz-json-1.0' -H "X-Amz-Target: AmazonSQS.$1" \
    -H 'Authorization: AWS4-HMAC-SHA256 Credential=test/20260101/us-east-1/sqs/aws4_request, SignedHeaders=host, Signature=0' \
    -d "$2"
}

# Fails if a container can open a connection to AWS (any answer counts, also
# one with a certificate error).
aws_unreachable() { # <container>
  local host
  for host in sts.amazonaws.com ssm.us-east-1.amazonaws.com sqs.us-east-1.amazonaws.com; do
    if docker exec "$1" curl -ks -o /dev/null --connect-timeout 5 "https://$host/"; then
      echo "$host is reachable from $1" >&2
      return 1
    fi
  done
}
