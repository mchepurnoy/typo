#!/bin/bash
# Builds build/Typo.app from the Swift package.
# A build for this Mac is "Typo Dev" (app.typo.Typo.dev): its permissions, settings and login item
# are its own, so building never touches an installed release, and it does not check for updates.
# Usage: scripts/build-app.sh                                  ad-hoc signed, this Mac's architecture
#        CODESIGN_ID="Apple Development: …" scripts/build-app.sh   stable identity, Accessibility grant survives rebuilds
#                                                               (signed with hardened runtime, ready to notarize)
#        UNIVERSAL=1 scripts/build-app.sh                       Apple silicon + Intel
#        DISTRIBUTION=1 scripts/build-app.sh                    Typo itself (app.typo.Typo), as the packaging scripts build it
set -euo pipefail
cd "$(dirname "$0")/.."

APP=build/Typo.app
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" Support/Info.plist)
if [ -z "${DISTRIBUTION:-}" ]; then BUNDLE_ID=$BUNDLE_ID.dev; fi
if [ -n "${DISTRIBUTION:-}" ] && [ -z "${CODESIGN_ID:-}" ]; then
  # An ad-hoc Typo would also reset the installed Typo's permissions
  echo "DISTRIBUTION=1 needs CODESIGN_ID" >&2
  exit 1
fi

ARCH_FLAGS=()
if [ -n "${UNIVERSAL:-}" ]; then ARCH_FLAGS=(--arch arm64 --arch x86_64); fi
swift build -c release --product Typo ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN_DIR=$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)

# Only the previous build: a Typo installed elsewhere keeps running
pkill -f "^$PWD/$APP/Contents/MacOS/Typo" 2>/dev/null || true
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Typo" "$APP/Contents/MacOS/Typo"
# Sparkle installs updates; ditto keeps the framework's symlinks. Its XPC services are only for
# sandboxed apps, which typo is not.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
ditto "$BIN_DIR/Sparkle.framework" "$SPARKLE"
rm -rf "$SPARKLE/Versions/B/XPCServices" "$SPARKLE/XPCServices"
if ! otool -l "$APP/Contents/MacOS/Typo" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath @executable_path/../Frameworks "$APP/Contents/MacOS/Typo"
fi
cp LanguageModels/*.lm LanguageModels/*.accents Support/AppIcon.icns "$APP/Contents/Resources/"
# The MIT licence of the ё word list must travel with it
cp LanguageModels/LICENSE-eyo-kernel.txt "$APP/Contents/Resources/"
# Interface strings: en.lproj and ru.lproj from the String Catalog
xcrun xcstringstool compile Sources/Typo/Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -z "${DISTRIBUTION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Set :CFBundleName Typo Dev" "$APP/Contents/Info.plist"
fi
# Inside out, without --deep: Sparkle's helpers, the framework, then the app
SIGNED=("$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE" "$APP")
if [ -n "${CODESIGN_ID:-}" ]; then
  # Hardened runtime and a secure timestamp: notarization requires both
  for item in "${SIGNED[@]}"; do codesign --force --options runtime --timestamp --sign "$CODESIGN_ID" "$item"; done
else
  for item in "${SIGNED[@]}"; do codesign --force --sign - "$item"; done
  # An ad-hoc signature changes every build, so a stale grant would look enabled but not work.
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
  tccutil reset ListenEvent "$BUNDLE_ID" >/dev/null 2>&1 || true
  echo "Ad-hoc signed: Accessibility and Input Monitoring were reset for $BUNDLE_ID; grant them again on first launch."
fi
echo "Built $APP — run: open $APP"
