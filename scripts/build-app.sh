#!/bin/bash
# Builds build/Typo.app from the Swift package.
# Usage: scripts/build-app.sh                                  ad-hoc signed, this Mac's architecture
#        CODESIGN_ID="Apple Development: …" scripts/build-app.sh   stable identity, Accessibility grant survives rebuilds
#        UNIVERSAL=1 scripts/build-app.sh                       Apple silicon + Intel
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Typo.app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Support/Info.plist)

ARCH_FLAGS=()
if [ -n "${UNIVERSAL:-}" ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
swift build -c release --product Typo ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR=$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)

pkill -x Typo 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Typo" "$APP/Contents/MacOS/Typo"
cp LanguageModels/*.lm LanguageModels/*.accents Support/AppIcon.icns "$APP/Contents/Resources/"
# The MIT licence of the ё word list must travel with it
cp LanguageModels/LICENSE-eyo-kernel.txt "$APP/Contents/Resources/"
# Interface strings: en.lproj and ru.lproj from the String Catalog
xcrun xcstringstool compile Sources/Typo/Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
cp Support/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign "${CODESIGN_ID:--}" "$APP"

if [ -z "${CODESIGN_ID:-}" ]; then
  # An ad-hoc signature changes every build, so a stale grant would look enabled but not work.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "Ad-hoc signed: Accessibility and Input Monitoring were reset for $BUNDLE_ID; grant them again on first launch."
fi
echo "Built $APP — run: open $APP"
