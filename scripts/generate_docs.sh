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

echo "==> Generating docs..."
jazzy \
  --clean \
  -a Mixpanel \
  -u http://mixpanel.com \
  --github_url https://github.com/mixpanel/mixpanel-swift \
  --module-version 5.2.0 \
  --framework-root . \
  --module Mixpanel \
  --xcodebuild-arguments \
    -scheme,Mixpanel,\
    -destination,'generic/platform=iOS',\
    -derivedDataPath,"$DERIVED_DATA"	