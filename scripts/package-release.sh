#!/bin/bash
# Builds a release for GitHub Releases in build/release/: Typo-<version>.zip (Typo.app for Apple
# silicon + Intel, Developer ID-signed and notarized), its notes from CHANGELOG.md and appcast.xml,
# the EdDSA-signed Sparkle feed that tells installed copies about it. .github/workflows/release.yml
# runs this on a version tag; it also runs locally, to check a release before tagging it.
# Needs what scripts/package-for-testing.sh needs, and the Sparkle private key: in the keychain
# (generate_keys) or in the file SPARKLE_KEY_FILE.
# Usage: scripts/package-release.sh
#        SPARKLE_KEY_FILE=… CODESIGN_ID="Developer ID Application: …" NOTARY_PROFILE=… scripts/package-release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

REPO=https://github.com/mchepurnoy/typo
PLIST=Support/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")
MIN_SYSTEM=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$PLIST")
PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$PLIST")
OUT=build/release
ZIP_NAME=Typo-$VERSION.zip

if [ "$PUBLIC_KEY" = SPARKLE_PUBLIC_KEY_NOT_SET ]; then
  echo "SUPublicEDKey in $PLIST is not set: see README.md, Publish a release" >&2
  exit 1
fi

# The notes are the CHANGELOG.md section headed "## <version>", up to the next "## "
rm -rf "$OUT"
mkdir -p "$OUT"
awk -v heading="## $VERSION" '
  $0 == heading { found = 1; next }
  found && /^## / { exit }
  found { print }
' CHANGELOG.md | sed -e '/./,$!d' > "$OUT/notes.md"
if ! grep -q '[^[:space:]]' "$OUT/notes.md"; then
  echo "CHANGELOG.md has no notes under \"## $VERSION\"" >&2
  exit 1
fi

# The SwiftPM build of Sparkle brings its command-line tools along
swift package resolve
SIGN_UPDATE=.build/artifacts/sparkle/Sparkle/bin/sign_update
KEY_ARGS=()
if [ -n "${SPARKLE_KEY_FILE:-}" ]; then KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE"); fi

# codesign takes any unique part of the certificate name
CODESIGN_ID="${CODESIGN_ID:-Developer ID Application}" UNIVERSAL=1 scripts/build-app.sh
scripts/notarize-app.sh build/Typo.app
# Without local extended attributes, which would otherwise ride along as ._ files
ditto -c -k --norsrc --noextattr --noqtn --keepParent build/Typo.app "$OUT/$ZIP_NAME"

SIGNATURE=$("$SIGN_UPDATE" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} -p "$OUT/$ZIP_NAME")
swift scripts/verify-ed-signature.swift "$PUBLIC_KEY" "$SIGNATURE" "$OUT/$ZIP_NAME"
LENGTH=$(stat -f %z "$OUT/$ZIP_NAME")

# One item is enough: Sparkle only ever offers the newest version
python3 - "$OUT/appcast.xml" <<PYTHON
import email.utils, sys
from xml.sax.saxutils import escape, quoteattr
notes = open("$OUT/notes.md", encoding="utf-8").read().strip().replace("]]>", "]]]]><![CDATA[>")
url = "$REPO/releases/download/v$VERSION/$ZIP_NAME"
open(sys.argv[1], "w", encoding="utf-8").write(f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Typo</title>
    <link>$REPO</link>
    <item>
      <title>Typo $VERSION</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape("$BUILD")}</sparkle:version>
      <sparkle:shortVersionString>{escape("$VERSION")}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape("$MIN_SYSTEM")}</sparkle:minimumSystemVersion>
      <description sparkle:format="markdown"><![CDATA[{notes}]]></description>
      <enclosure url={quoteattr(url)} length="$LENGTH" type="application/octet-stream" sparkle:edSignature={quoteattr("$SIGNATURE")}/>
    </item>
  </channel>
</rss>
""")
PYTHON
# The app requires a signed feed (SURequireSignedFeed): the signature goes into the file itself
"$SIGN_UPDATE" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} "$OUT/appcast.xml"
"$SIGN_UPDATE" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} --verify "$OUT/appcast.xml"
echo "Packed $OUT: $ZIP_NAME ($(du -h "$OUT/$ZIP_NAME" | cut -f1)), appcast.xml, notes.md — Typo $VERSION ($BUILD)"
