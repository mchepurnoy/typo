#!/bin/bash
# Builds build/Typo.app from the Swift package.
# Usage: scripts/build-app.sh                                  ad-hoc signed
#        CODESIGN_ID="Apple Development: …" scripts/build-app.sh   stable identity, Accessibility grant survives rebuilds
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Typo.app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Support/Info.plist)

swift build -c release --product Typo
BIN_DIR=$(swift build -c release --show-bin-path)

pkill -x Typo 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Typo" "$APP/Contents/MacOS/Typo"
cp LanguageModels/*.lm "$APP/Contents/Resources/"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${CODESIGN_ID:--}" "$APP"

if [ -z "${CODESIGN_ID:-}" ]; then
  # An ad-hoc signature changes every build, so a stale grant would look enabled but not work.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "Ad-hoc signed: Accessibility was reset for $BUNDLE_ID; grant it again on first launch."
fi
echo "Built $APP — run: open $APP"
