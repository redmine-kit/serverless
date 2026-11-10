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
ARG BASE_IMAGE

FROM ${BASE_IMAGE} AS build
# Gems with native extensions are compiled here; the image gets only the
# result.
RUN dnf install -y gcc gcc-c++ make && dnf clean all
WORKDIR /var/task/redmine
COPY . /tmp/derived/
# Bundler runs only when a gem or a plugin's Gemfile is added. The lock is the
# base image's lock with the new gems added: bundle lock keeps the versions
# already locked unless a new gem needs a newer one. Bundler's credential for
# GitHub Packages is a build secret, never in a layer. The plugin gems are
# linked into plugins/ as the base image links its own. tmp links to
# /tmp/redmine, which building the assets uses.
RUN --mount=type=secret,id=bundle_github,env=BUNDLE_RUBYGEMS__PKG__GITHUB__COM <<'EOF'
set -eu
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
if [ -s /tmp/derived/Gemfile.plugins ] || ls plugins/*/Gemfile plugins/*/PluginGemfile >/dev/null 2>&1; then
  cat /tmp/derived/Gemfile.plugins >>Gemfile.local
  BUNDLE_DEPLOYMENT=false BUNDLE_FROZEN=false bundle lock
  bundle install --jobs 4
  rm -rf vendor/bundle/ruby/*/cache
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
rm -rf /tmp/redmine /tmp/derived
# Lambda runs as a low-privilege user, which must read everything.
chmod -R a+rX /var/task/redmine
EOF

FROM ${BASE_IMAGE}
COPY --from=build /var/task/redmine /var/task/redmine
