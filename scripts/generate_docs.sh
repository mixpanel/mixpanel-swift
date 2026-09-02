#!/bin/sh
set -e

DERIVED_DATA="$PWD/build"

echo "==> Building full scheme to compile SPM dependencies..."
xcodebuild build \
  -scheme Mixpanel \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# jazzy (<= 0.15.4) assigns a Pathname to Mustache.template_path. mustache
# 1.1.3 (2026-08-20) turned template_path into a search path, so its setter
# now calls .map on the value and only accepts a String or an Array:
#   NoMethodError: undefined method 'map' for an instance of Pathname
# This shim wraps a Pathname in an Array before handing it over. It is inert on
# mustache <= 1.1.2 and once jazzy fixes lib/jazzy/config.rb:546 upstream, so
# it is safe to leave in place until then.
SHIM_DIR=$(mktemp -d)
trap 'rm -rf "$SHIM_DIR"' EXIT INT TERM

cat > "$SHIM_DIR/mustache_pathname_shim.rb" <<'RUBY'
require 'pathname'
require 'mustache'

if Mustache.singleton_class.method_defined?(:setup_path) ||
   Mustache.singleton_class.private_method_defined?(:setup_path)
  class << Mustache
    alias_method :setup_path_without_pathname, :setup_path

    def setup_path(path)
      # Wrap in an Array rather than calling to_s, so that mustache does not
      # split the path on File::PATH_SEPARATOR.
      path = [path.to_s] if path.is_a?(Pathname)
      setup_path_without_pathname(path)
    end
  end
end
RUBY

echo "==> Generating docs..."
RUBYOPT="-r$SHIM_DIR/mustache_pathname_shim.rb" jazzy \
  --clean \
  -a Mixpanel \
  -u http://mixpanel.com \
  --github_url https://github.com/mixpanel/mixpanel-swift \
  --module-version 6.5.1 \
  --framework-root . \
  --module Mixpanel \
  --xcodebuild-arguments "-scheme,Mixpanel,-destination,generic/platform=iOS,-derivedDataPath,$DERIVED_DATA"