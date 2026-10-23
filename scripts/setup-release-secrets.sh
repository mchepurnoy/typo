#!/bin/bash
# Puts the signing and notarization secrets into the release environment on GitHub, for
# .github/workflows/release.yml. Run it in Terminal yourself: it asks for the values, which go
# straight to GitHub and are never printed. Run again when the certificate or password changes.
# Needs gh, logged in as the repository admin. SPARKLE_PRIVATE_KEY and NOTARY_TEAM_ID are set apart
# (README.md, Publish a release → One-time setup).
# Usage: scripts/setup-release-secrets.sh
set -euo pipefail

REPO=mchepurnoy/typo
set_secret() { gh secret set "$1" --env release --repo "$REPO"; }

cat <<'TEXT'
1. Developer ID certificate
   Keychain Access → login → My Certificates → right-click
   "Developer ID Application: …" → Export… → format .p12, with a password.
TEXT
read -r -p "Path to the .p12 file: " P12
P12=${P12/#\~/$HOME}
[ -f "$P12" ] || { echo "No file at $P12" >&2; exit 1; }
read -r -s -p "Its password: " P12_PASSWORD; echo
base64 -i "$P12" | set_secret DEVELOPER_ID_P12
printf '%s' "$P12_PASSWORD" | set_secret DEVELOPER_ID_P12_PASSWORD
unset P12_PASSWORD

cat <<'TEXT'

2. Notarization: the Apple ID of a team member and an app-specific password for it
   (account.apple.com → Sign-In and Security → App-Specific Passwords), the same ones as
   the typo-notary keychain profile.
TEXT
read -r -p "Apple ID: " APPLE_ID
read -r -s -p "App-specific password: " NOTARY_PASSWORD; echo
printf '%s' "$APPLE_ID" | set_secret NOTARY_APPLE_ID
printf '%s' "$NOTARY_PASSWORD" | set_secret NOTARY_PASSWORD
unset NOTARY_PASSWORD

echo
gh secret list --env release --repo "$REPO"
read -r -p "Delete $P12 now (it holds the certificate's private key)? [Y/n] " DELETE
if [ "${DELETE:-Y}" != n ] && [ "${DELETE:-Y}" != N ]; then rm -P "$P12" && echo "Deleted."; fi
