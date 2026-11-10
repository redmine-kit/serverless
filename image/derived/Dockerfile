# syntax=docker/dockerfile:1
# check=skip=InvalidDefaultArgInFrom
# A derived image: a base image (this project's, by digest) with the plugins
# and themes of image.plugins and image.themes in redmine.json
# (docs/architecture.md#derived-images). bin/build-derived-image prepares the
# build context and builds it; bin/deploy builds it before deploying:
#   <context>/plugins/<name>/  plugins from Git or a directory
#   <context>/themes/<name>/   themes from Git or a directory
#   <context>/Gemfile.plugins  the plugin gems, appended to Gemfile.local
#   <context>/gems             their names, one per line
# The build context "derived" is image/derived, for lock.rb.
ARG BASE_IMAGE

FROM ${BASE_IMAGE} AS build
# Gems with native extensions are compiled here; the image gets only the
# result.
RUN dnf install -y gcc gcc-c++ make && dnf clean all
WORKDIR /var/task/redmine
COPY . /tmp/derived/
# Bundler runs only when a gem or a plugin's Gemfile is added. The lock is the
# base image's lock with the added gems, and the base image's gems keep their
# versions (lock.rb): if an added plugin needs another version of one, the
# build fails. Without a token for GitHub Packages, the added gems are
# installed from a Gemfile of their own and locked from the installed gems,
# so gems from RubyGems need none. Bundler's credential for GitHub Packages
# is a build secret, never in a layer. The plugin gems are linked
# into plugins/ as the base image links its own. tmp links to /tmp/redmine,
# which building the assets uses.
RUN --mount=type=secret,id=bundle_github,env=BUNDLE_RUBYGEMS__PKG__GITHUB__COM \
  --mount=type=bind,from=derived,source=lock.rb,target=/tmp/lock.rb <<'EOF'
set -eu
cd /var/task/redmine
ruby /tmp/lock.rb base /tmp/base-gems
cd /tmp/derived
for kind in plugins themes; do
  for dir in "$kind"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    if [ -e "/var/task/redmine/$kind/$name" ]; then
      echo "$kind/$name is already in the base image" >&2
      exit 1
    fi
    cp -R "$dir" "/var/task/redmine/$kind/$name"
  done
done
cd /var/task/redmine
gemfiles=false
for file in plugins/*/Gemfile plugins/*/PluginGemfile; do
  if [ -e "$file" ]; then gemfiles=true; fi
done
if [ -s /tmp/derived/Gemfile.plugins ] || $gemfiles; then
  fail() {
    echo "$1: the added plugins may need other versions of gems in the base image, which a derived image keeps," >&2
    echo "or a gem that cannot be fetched (from GitHub Packages, a token with read:packages is needed)" >&2
    exit 1
  }
  cat /tmp/derived/Gemfile.plugins >>Gemfile.local
  BUNDLE_DEPLOYMENT=false BUNDLE_FROZEN=false ruby /tmp/lock.rb pins /tmp/base-gems >/tmp/pins
  cat /tmp/pins >>Gemfile.local
  if [ -n "${BUNDLE_RUBYGEMS__PKG__GITHUB__COM:-}" ]; then
    BUNDLE_DEPLOYMENT=false BUNDLE_FROZEN=false bundle lock || fail "bundle lock failed"
    ruby /tmp/lock.rb check /tmp/base-gems
    bundle install --jobs 4
  else
    mkdir -p /tmp/added
    ruby /tmp/lock.rb gemfile /tmp/base-gems /tmp/added/Gemfile
    (cd /tmp/added && BUNDLE_APP_CONFIG=/tmp/added/.bundle BUNDLE_PATH=/var/task/redmine/vendor/bundle \
      BUNDLE_WITHOUT=development:test bundle install --jobs 4) || fail "installing the added gems failed"
    BUNDLE_DEPLOYMENT=false BUNDLE_FROZEN=false bundle lock --local || fail "bundle lock failed"
    ruby /tmp/lock.rb checksums /tmp/added/Gemfile.lock
    ruby /tmp/lock.rb check /tmp/base-gems
    bundle install --local
  fi
  rm -rf vendor/bundle/ruby/*/cache /tmp/added /tmp/pins
fi
while read -r gem; do
  [ -n "$gem" ] || continue
  if [ -e "plugins/$gem" ]; then
    echo "plugins/$gem is already in the base image" >&2
    exit 1
  fi
  ln -s "$(bundle info --path "$gem")" "plugins/$gem"
done </tmp/derived/gems
mkdir -p /tmp/redmine
SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile
rm -rf /tmp/redmine /tmp/derived /tmp/base-gems
# Lambda runs as a low-privilege user, which must read everything.
chmod -R a+rX /var/task/redmine
EOF

FROM ${BASE_IMAGE}
COPY --from=build /var/task/redmine /var/task/redmine
