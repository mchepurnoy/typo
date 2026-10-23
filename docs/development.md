# Developing typo

Building, testing and releasing typo. What the app does and how to install it is in the [README](../README.md).

## Requirements

- macOS 14 or later
- Xcode 16 or later (Swift 6 toolchain); the command-line tools are enough to build

## Build and run

```sh
scripts/build-app.sh      # builds build/Typo.app
open build/Typo.app
```

typo lives in the menu bar (keyboard icon) and has no Dock icon. On first launch macOS asks for **Accessibility** access: allow it in System Settings → Privacy & Security → Accessibility. typo starts working as soon as access is granted; no relaunch needed.

This build is **Typo Dev** (`app.typo.Typo.dev`): its permissions, settings and login item are separate from an installed Typo, it never checks for updates and is not opened at login. Quit an installed Typo while testing it, or both correct every word.

The default build is ad-hoc signed, whose signature changes on every build, so the script resets Typo Dev's Accessibility grant each time and you grant it again. To keep the grant across rebuilds, sign with a stable identity (a free Personal Team certificate works):

```sh
CODESIGN_ID="Apple Development: you@example.com (TEAMID)" scripts/build-app.sh
```

## Send a test build to someone

```sh
scripts/package-for-testing.sh   # build/Typo-<version>-test.zip: Apple silicon + Intel, with README.txt
```

The build is signed with a Developer ID and notarized, so it opens on another Mac without Gatekeeper warnings, and a newer build keeps the Accessibility and Input Monitoring grants. `README.txt` in the zip explains installing, in Russian and English. The script needs, once per Mac:

- the **Developer ID Application** certificate with its private key in the keychain: `security find-identity -v -p codesigning` lists it;
- notarization credentials saved as the keychain profile `typo-notary`, from an app-specific password of an Apple ID in the team:

  ```sh
  xcrun notarytool store-credentials typo-notary --apple-id you@example.com --team-id TEAMID --password xxxx-xxxx-xxxx-xxxx
  ```

`CODESIGN_ID` and `NOTARY_PROFILE` override the certificate and the profile.

## Publish a release

Releases go to [GitHub Releases](https://github.com/mchepurnoy/typo/releases), and installed copies update themselves from there with [Sparkle](https://sparkle-project.org) ([ADR 0005](adr/0005-updates-from-github-releases.md)). For each release:

1. In `Support/Info.plist` raise `CFBundleShortVersionString` **and** `CFBundleVersion` (Sparkle compares `CFBundleVersion`, a whole number that only grows).
2. Add a `## <version>` section to [`CHANGELOG.md`](../CHANGELOG.md): it becomes the notes on the release page and in the update window.
3. Commit to `main`, then tag and push:

   ```sh
   git tag v0.4.0 && git push origin main v0.4.0
   ```

4. The [Release workflow](../.github/workflows/release.yml) tests the tagged commit, then waits for approval in the `release` environment (Actions → the run → Review deployments). After approval it builds, signs, notarizes and publishes `Typo-<version>.zip` and `appcast.xml`.

To check a release before tagging it, `scripts/package-release.sh` builds the same files into `build/release/` on this Mac. It needs what `package-for-testing.sh` needs and the Sparkle private key in the keychain (or the file `SPARKLE_KEY_FILE`).

### One-time setup

Sparkle's tools come with the package: `swift package resolve`, then they are in `.build/artifacts/sparkle/Sparkle/bin/`.

1. `generate_keys` creates the update signing key in the login keychain and prints the public key: put it in `SUPublicEDKey` in `Support/Info.plist`. `generate_keys -x sparkle.key` exports the private key. Keep a copy offline (a password manager): without it, installed copies can never be updated again.
2. Create the `release` environment (Settings → Environments) and put the secrets into it, never into repository secrets:

   ```sh
   gh secret set SPARKLE_PRIVATE_KEY --env release < sparkle.key && rm -P sparkle.key
   gh secret set NOTARY_TEAM_ID --env release --body TEAMID
   scripts/setup-release-secrets.sh   # exports the Developer ID certificate, asks for the notarization login
   ```

   | Secret | Value |
   | --- | --- |
   | `SPARKLE_PRIVATE_KEY` | the contents of `sparkle.key` |
   | `NOTARY_TEAM_ID` | the team ID, in brackets in the certificate name |
   | `DEVELOPER_ID_P12`, `DEVELOPER_ID_P12_PASSWORD` | the Developer ID certificate with its key as a `.p12` (base64), and its random password |
   | `NOTARY_APPLE_ID`, `NOTARY_PASSWORD` | what `notarytool store-credentials` takes: Apple ID, app-specific password |

### Release security

Whoever can run the release job can ship code to every installed copy, so:

- **Secrets live only in the `release` environment**, not in repository secrets. The environment has a required reviewer (the owner), admins cannot bypass it, and only `v*` tags may deploy to it.
- **A tag ruleset on `refs/tags/v*`**: only the repository admin may create, move or delete version tags.
- **A branch ruleset on `main`**: no force pushes and no deletion. The workflow refuses a tag whose commit is not on `main`, and a tag that does not match `CFBundleShortVersionString`.
- **The workflow runs only on tag pushes**, never on pull requests, so forks never see the secrets. Tests run in a job without secrets; the signing job gets `contents: write`, everything else is read-only.
- **Actions**: only GitHub's own actions are allowed (Settings → Actions → General), `actions/checkout` is pinned to a commit, Sparkle to an exact version (`Package.resolved`). The default `GITHUB_TOKEN` is read-only, and workflows from outside contributors need approval.
- **Releases are immutable** once published (Settings → General → Releases), so a published zip or feed cannot be swapped.
- **The app trusts only signed updates**: the zip and `appcast.xml` are EdDSA-signed (`SURequireSignedFeed`, `SUVerifyUpdateBeforeExtraction`), `package-release.sh` refuses a key that does not match `SUPublicEDKey`, and Sparkle also requires the new app to carry the same Developer ID.

## App icon

`Support/AppIcon.svg` is the source; `scripts/build-icon.sh` renders `Support/AppIcon.icns` from it with the system SVG renderer. Re-run it after editing the SVG.

## Interface languages

The interface is in English and Russian and follows the system language. Translations live in `scripts/localizations.py`, which writes the String Catalog `Sources/Typo/Resources/Localizable.xcstrings`; `build-app.sh` compiles it into the app. After adding or changing an interface string, add its translation there and run the script. `LocalizationTests` fails on any interface string without a Russian translation, and on unused keys.

## Test

```sh
swift test                 # all tests
swift test -c release      # also runs the timing tests, which are skipped in debug builds
```

The `Engine` module (pure Swift, no AppKit/Carbon) holds all correction logic and is covered by scenario tests. The macOS adapter and app shell (`Sources/Typo`) are checked by hand with [`docs/qa-checklist.md`](qa-checklist.md).

## Language models

Detection uses one language model per supported language (English, Russian, German, Spanish) in `LanguageModels/`, built from the Leipzig Corpora Collection (CC BY). To rebuild them (downloads ≈1 GB once):

```sh
scripts/build-language-models.py
```

Next to them, `<code>.accents` tables list words whose ё, umlauts or accents typo restores when they are left out ("еще" → "ещё", "konnen" → "können"); rebuild with `scripts/build-accent-tables.py`. Sources, licences, attribution and the file formats are in [`LanguageModels/SOURCES.md`](../LanguageModels/SOURCES.md). The accuracy test runs held-out news text through the Engine (`Tests/EngineTests/Accuracy/`, regenerate with `scripts/build-accuracy-corpus.py`).

## Demo GIF

`docs/demo.gif` in the README is a real recording: `scripts/record-demo.sh` opens a new Terminal window, types the demo there with real key presses, lets the running Typo fix it, logs every byte that reaches the terminal and renders that log as a GIF. Re-record it when corrections or their wording change:

```sh
scripts/record-demo.sh    # don't touch the keyboard or mouse until it finishes
```

It needs Typo running, the U.S. and Russian – PC layouts, and Accessibility for the app that runs the script. It stops as soon as Terminal is no longer in front, so it never types into another app.
