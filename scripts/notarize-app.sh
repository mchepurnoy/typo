#!/bin/bash
# Notarizes a Developer ID-signed app and staples its ticket, so Gatekeeper opens it without asking.
# Needs notarytool credentials saved as the keychain profile typo-notary (see README.md).
# Usage: scripts/notarize-app.sh [build/Typo.app]
#        NOTARY_PROFILE=… NOTARY_KEYCHAIN=… scripts/notarize-app.sh   profile saved in another keychain (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${1:-build/Typo.app}
NOTARY_ZIP=build/Typo-notarize.zip
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP" "$NOTARY_ZIP"
KEYCHAIN_ARGS=()
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then KEYCHAIN_ARGS=(--keychain "$NOTARY_KEYCHAIN"); fi
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "${NOTARY_PROFILE:-typo-notary}" \
  ${KEYCHAIN_ARGS[@]+"${KEYCHAIN_ARGS[@]}"} --wait
rm "$NOTARY_ZIP"
xcrun stapler staple "$APP"
spctl --assess --type execute --verbose "$APP"
