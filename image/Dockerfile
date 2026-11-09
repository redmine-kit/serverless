# syntax=docker/dockerfile:1
# The image that the three functions use (docs/lambda.md#image). Built from
# the repository root: docker build -f image/Dockerfile .

FROM public.ecr.aws/lambda/ruby:4.0@sha256:9aea5f69767d2078ad1874471cf0c3064cf7fe46d95afc6c96bfeb62f51fdc02 AS base

# The plugins at pinned commits. bin/lib/plugin.sh can replace a stage with a
# local checkout (--build-context plugin=<dir>, plugin-ssm=<dir>).
FROM base AS git
RUN dnf install -y git-core && dnf clean all
# fetch <repository> <commit> <dir>
RUN printf '%s\n' '#!/bin/sh' 'set -e' 'git init -q "$3"' \
    'git -C "$3" fetch -q --depth 1 "https://github.com/redmine-kit/$1.git" "$2"' \
    'git -C "$3" checkout -q FETCH_HEAD' 'test "$(git -C "$3" rev-parse HEAD)" = "$2"' 'rm -rf "$3/.git"' \
    > /usr/local/bin/fetch && chmod +x /usr/local/bin/fetch
FROM git AS plugin-git
ARG REDMINE_SERVERLESS_COMMIT=849873adc180e3eaaeb9c04208644d7336039575
RUN fetch redmine_serverless "$REDMINE_SERVERLESS_COMMIT" /plugin
FROM git AS plugin-ssm-git
ARG REDMINE_SERVERLESS_SSM_COMMIT=9a78fcc1b6035a6ea7fb2d6c91831dd13e3c251d
RUN fetch redmine_serverless_ssm "$REDMINE_SERVERLESS_SSM_COMMIT" /plugin-ssm
FROM scratch AS plugin
COPY --from=plugin-git /plugin /
FROM scratch AS plugin-ssm
COPY --from=plugin-ssm-git /plugin-ssm /

FROM base AS source
RUN dnf install -y gcc gcc-c++ make libpq-devel libyaml-devel tar gzip && dnf clean all
ARG REDMINE_VERSION=7.0.3
ARG REDMINE_SHA256=0b6b24c033341a9d7ad52cfcfa7b1bc913c191c7a604f740d863f16249dd3c15
# A branch of Redmine (master, before the next release) instead of the
# release, for the CI matrix (docs/testing.md#order-in-ci). It is not pinned,
# its gems are resolved without image/Gemfile.lock, and its image is never
# deployed.
ARG REDMINE_BRANCH=
RUN if [ -n "$REDMINE_BRANCH" ]; then \
    curl -fsSLo /tmp/redmine.tar.gz "https://github.com/redmine/redmine/archive/refs/heads/${REDMINE_BRANCH}.tar.gz" \
    && mkdir /var/task/redmine && tar -xzf /tmp/redmine.tar.gz -C /var/task/redmine --strip-components 1; \
  else \
    curl -fsSLo /tmp/redmine.tar.gz "https://www.redmine.org/releases/redmine-${REDMINE_VERSION}.tar.gz" \
    && echo "${REDMINE_SHA256}  /tmp/redmine.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/redmine.tar.gz -C /var/task \
    && mv "/var/task/redmine-${REDMINE_VERSION}" /var/task/redmine; \
  fi \
  && rm /tmp/redmine.tar.gz
WORKDIR /var/task/redmine
COPY image/config/database.yml image/config/additional_environment.rb image/config/configuration.yml \
  image/config/aws_active_job_sqs.yml config/
COPY image/Gemfile.local ./
COPY --from=plugin / plugins/redmine_serverless/
COPY --from=plugin-ssm / plugins/redmine_serverless_ssm/
RUN bundle config set --local path vendor/bundle \
  && bundle config set --local without development:test

# bin/update-gems writes Gemfile.lock from this stage. It starts from the
# current lock, so only new gems are resolved unless UPDATE is set, and the
# lock keeps its only platform, arm64 Linux (glibc), which Lambda runs. An
# update takes only versions published at least 7 days ago, as Dependabot does
# for the other dependencies.
FROM source AS lock
COPY image/Gemfile.lock ./
ARG UPDATE=
RUN bundle lock ${UPDATE:+--update --cooldown=7}
FROM scratch AS lockfile
COPY --from=lock /var/task/redmine/Gemfile.lock /

# Redmine's own tests (bin/test-core): Redmine with this image's
# configuration and gems, plus the test group.
FROM source AS core-test
RUN dnf install -y ImageMagick ghostscript urw-base35-fonts && dnf clean all
COPY image/Gemfile.lock ./
COPY test/core/database.yml config/database.yml
# A branch resolves its gems afresh (see the source stage).
ARG REDMINE_BRANCH=
RUN bundle config set --local without development \
  && if [ -n "$REDMINE_BRANCH" ]; then rm Gemfile.lock; else bundle config set --local deployment true; fi \
  && bundle install --jobs 4
ENV RAILS_ENV=test
ENTRYPOINT []

FROM source AS build
COPY image/Gemfile.lock ./
ARG REDMINE_BRANCH=
RUN if [ -n "$REDMINE_BRANCH" ]; then rm Gemfile.lock; else bundle config set --local deployment true; fi \
  && bundle install --jobs 4 \
  && rm -rf vendor/bundle/ruby/*/cache
RUN SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails assets:precompile
# Only /tmp is writable on Lambda. tmp is linked after the assets are built,
# because building may use it (docs/lambda.md#read-only-file-system).
RUN rm -rf tmp log/*.log && ln -s /tmp/redmine tmp
# The CA bundle of RDS, for sslmode verify-full (docs/rds.md).
ARG RDS_CA_SHA256=90a6f1a7978a1b1b096dca6c57511ca48d3b8cf052f8e704baf358f34ea2f21b
RUN curl -fsSLo /tmp/rds-global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem \
  && echo "${RDS_CA_SHA256}  /tmp/rds-global-bundle.pem" | sha256sum -c -
ARG PANDOC_VERSION=3.13
ARG PANDOC_SHA256=21e1d4ba09bd0b334590d204580fd4f6629b21be4ab6a32b26cc98982e9e0c68
RUN curl -fsSLo /tmp/pandoc.tar.gz "https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/pandoc-${PANDOC_VERSION}-linux-arm64.tar.gz" \
  && echo "${PANDOC_SHA256}  /tmp/pandoc.tar.gz" | sha256sum -c - \
  && tar -xzf /tmp/pandoc.tar.gz -C /tmp \
  && install -m 0755 "/tmp/pandoc-${PANDOC_VERSION}/bin/pandoc" /usr/local/bin/pandoc

FROM base
RUN dnf install -y ImageMagick ghostscript urw-base35-fonts libpq ipa-gothic-fonts && dnf clean all
COPY --from=build /usr/local/bin/pandoc /usr/local/bin/pandoc
COPY --from=build /var/task/redmine /var/task/redmine
COPY --from=build /tmp/rds-global-bundle.pem /var/task/rds-global-bundle.pem
COPY image/handler.rb /var/task/handler.rb
COPY image/bin/start /var/task/bin/start
COPY --from=public.ecr.aws/awsguru/aws-lambda-adapter:1.1.0@sha256:17cfd08eff1dfea3f6a9a1e9c65fdac80aa4919b6085e746615530f43f57d2f1 /lambda-adapter /opt/lambda-web-adapter/lambda-adapter
COPY image/extensions/lambda-adapter /opt/extensions/lambda-adapter
# Lambda runs as a low-privilege user, which must read everything.
RUN chmod -R a+rX /var/task /opt
ENV RAILS_ENV=production \
  RAILS_LOG_TO_STDOUT=1 \
  RUBY_YJIT_ENABLE=1 \
  HOME=/tmp \
  AWS_LWA_PORT=3000 \
  AWS_LWA_READINESS_CHECK_PROTOCOL=tcp \
  AWS_LWA_ASYNC_INIT=true \
  AWS_LWA_ENABLE_COMPRESSION=true
ENTRYPOINT ["/var/task/bin/start"]
