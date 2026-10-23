#!/bin/bash
# Packs a test build to send to someone: build/Typo-<version>-test.zip with Typo.app (Apple silicon
# + Intel), Developer ID-signed and notarized, and README.txt.
# Needs the Developer ID Application certificate in the keychain and notarytool credentials saved as
# the keychain profile typo-notary (see README.md).
# Usage: scripts/package-for-testing.sh
#        CODESIGN_ID="Developer ID Application: …" NOTARY_PROFILE=… scripts/package-for-testing.sh
set -euo pipefail
cd "$(dirname "$0")/.."

# codesign takes any unique part of the certificate name
CODESIGN_ID="${CODESIGN_ID:-Developer ID Application}" UNIVERSAL=1 DISTRIBUTION=1 scripts/build-app.sh
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Support/Info.plist)
STAGE=build/package/Typo
ZIP=build/Typo-$VERSION-test.zip

scripts/notarize-app.sh build/Typo.app

rm -rf build/package "$ZIP"
mkdir -p "$STAGE"
cp -R build/Typo.app "$STAGE/"
cp docs/testing-build.txt "$STAGE/README.txt"
# Without local extended attributes, which would otherwise ride along as ._ files
ditto -c -k --norsrc --noextattr --noqtn --keepParent "$STAGE" "$ZIP"
echo "Packed $ZIP ($(du -h "$ZIP" | cut -f1)) — $(lipo -archs build/Typo.app/Contents/MacOS/Typo)"
