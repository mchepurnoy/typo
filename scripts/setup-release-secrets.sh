#!/bin/bash
# Puts the signing and notarization secrets into the release environment on GitHub, for
# .github/workflows/release.yml. Run it in Terminal yourself: it exports the certificate from the
# keychain and asks for the notarization login; the values go straight to GitHub and are never
# printed or left on disk. Run again when the certificate or password changes.
# Needs gh, logged in as the repository admin. SPARKLE_PRIVATE_KEY and NOTARY_TEAM_ID are set apart
# (README.md, Publish a release → One-time setup).
# Usage: scripts/setup-release-secrets.sh
set -euo pipefail

REPO=mchepurnoy/typo
set_secret() { gh secret set "$1" --env release --repo "$REPO"; }

# 1. The Developer ID certificate with its private key, as a .p12 with a random password that only
# GitHub keeps. macOS asks once for permission to export the key.
cd "$(dirname "$0")/.."
SHA1=$(security find-identity -v -p codesigning | awk '/"Developer ID Application/ { print $2; exit }')
[ -n "$SHA1" ] || { echo "No Developer ID Application certificate in the keychain" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -P "$WORK"/* 2>/dev/null; rm -rf "$WORK"' EXIT
P12_PASSWORD=$(openssl rand -base64 24)
echo "1. Exporting $(security find-identity -v -p codesigning | grep "$SHA1" | cut -d'"' -f2): allow it in the dialog"
P12_PASSWORD=$P12_PASSWORD swift scripts/export-identity.swift "$SHA1" "$WORK/developer-id.p12"
base64 -i "$WORK/developer-id.p12" | set_secret DEVELOPER_ID_P12
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
