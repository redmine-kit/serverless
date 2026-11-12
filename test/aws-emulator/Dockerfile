# AWS Emulator (https://github.com/aws/aws-emulator, CC0-1.0) for the tests
# (test/compose.yml). AWS publishes no image: this installs AWS's RPM from
# downloads.aws.com, as its Docker guide does, pinned by version and SHA-256.
#
# To update the version: take the newest from
# https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/versions.json
# (the file name drops its last ".1": 1.0.322.1 is aws-emulator-1.0.322-1-*.rpm),
# check each package's signature with AWS's key (fingerprint
# 98BC F336 A3BE 53B7 34E9 67C5 2E5B F49B D940 F624; see "To verify the package
# before you install it" in the user guide's Getting started on Linux), and
# put the version and both SHA-256 sums below. Dependabot updates the base
# image's digest.
FROM public.ecr.aws/amazonlinux/amazonlinux:2023-minimal@sha256:61cf86a8168c2e0b8fc6b6badaac64968044c947718508d88fac06e61a596e6d
ARG TARGETARCH
# 1.0.322, both packages' signatures checked on 2026-11-12.
ARG VERSION=1.0.322
ARG SHA256_X86_64=edbc25a9ebcf7f5acaa15a8d6409bdb4c7de25f3860a69ccfc65f9b01dfec8a0
ARG SHA256_AARCH64=32ff11c5fe88527e6f647cb99c1011ff594f73d75dad7e7e576ea99bf09e1e55
RUN case "$TARGETARCH" in \
      amd64) arch=x86_64 sha256=$SHA256_X86_64 ;; \
      arm64) arch=aarch64 sha256=$SHA256_AARCH64 ;; \
      *) echo "no AWS Emulator package for $TARGETARCH" >&2; exit 1 ;; \
    esac \
  && curl -fsSLo /tmp/aws-emulator.rpm \
    "https://downloads.aws.com/aws-emulator/packages/aws-emulator/LTS/aws-emulator-${VERSION}-1-${arch}.rpm" \
  && echo "$sha256  /tmp/aws-emulator.rpm" | sha256sum -c - \
  && rpm -i /tmp/aws-emulator.rpm && rm /tmp/aws-emulator.rpm \
  && mkdir -p /home/emulator/.aws/emulator && chown -R 1000 /home/emulator
USER 1000
# Telemetry is on by default; off here, and again on the command line.
ENV HOME=/home/emulator EMULATOR_TELEMETRY=off
EXPOSE 9297
# 0.0.0.0 inside the container, on a network without published ports.
ENTRYPOINT ["aws-emulator", "--bind", "0.0.0.0", "--telemetry", "off"]
