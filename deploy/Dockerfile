# syntax=docker/dockerfile:1
# The tools of bin/deploy: the AWS CLI, jq, OpenSSL, crane (copies images
# by digest) and check-jsonschema, at pinned versions. requirements.txt
# pins check-jsonschema and its dependencies with hashes (made from
# requirements.in with pip-compile --generate-hashes).
FROM amazon/aws-cli:2.38.5@sha256:c8156a0e74e13929a42d7e60f0d4e14e7d28d980cd21822505d4bff80e5460c1
RUN dnf install -y jq openssl tar gzip findutils python3.13 python3.13-pip && dnf clean all
ARG CRANE_VERSION=v0.22.1
ARG CRANE_SHA256_ARM64=898c0cff975f898a33e8c4580bdafb0e7c02c7faa33374e946762f97c4ab7110
ARG CRANE_SHA256_X86_64=0ab7a1d6932a213aed964ce97666c3077fe691c8606413674a8b3e0b9ec4cda0
RUN arch=$(uname -m) \
  && case "$arch" in aarch64) file=Linux_arm64; sum=$CRANE_SHA256_ARM64 ;; x86_64) file=Linux_x86_64; sum=$CRANE_SHA256_X86_64 ;; esac \
  && curl -fsSLo /tmp/crane.tar.gz "https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/go-containerregistry_${file}.tar.gz" \
  && echo "${sum}  /tmp/crane.tar.gz" | sha256sum -c - \
  && tar -xzf /tmp/crane.tar.gz -C /usr/local/bin crane \
  && rm /tmp/crane.tar.gz
COPY requirements.txt /tmp/requirements.txt
RUN python3.13 -m pip install --no-cache-dir --require-hashes -r /tmp/requirements.txt && rm /tmp/requirements.txt
WORKDIR /work
ENTRYPOINT ["/work/deploy/deploy.sh"]
