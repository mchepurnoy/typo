#!/bin/bash
# Packs a test build to send to someone: build/Typo-<version>-test.zip with Typo.app (Apple silicon
# + Intel) and README.txt explaining how to open an app that is not notarized.
# Usage: scripts/package-for-testing.sh
set -euo pipefail
cd "$(dirname "$0")/.."

UNIVERSAL=1 scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
STAGE=build/package/Typo
ZIP=build/Typo-$VERSION-test.zip

rm -rf build/package "$ZIP"
mkdir -p "$STAGE"
cp -R build/Typo.app "$STAGE/"
cp docs/testing-build.txt "$STAGE/README.txt"
# ditto keeps the bundle's signature and extended attributes intact
ditto -c -k --keepParent "$STAGE" "$ZIP"
echo "Packed $ZIP ($(du -h "$ZIP" | cut -f1)) — $(lipo -archs build/Typo.app/Contents/MacOS/Typo)"
