# typo

A native macOS menu-bar app that fixes words typed in the wrong keyboard layout: type `ghbdtn` on the U.S. layout, press Space, get `привет`.

Early development.

## Requirements

- macOS 14 or later
- Xcode 16 or later (Swift 6 toolchain); the command-line tools are enough to build

## Build and run

```sh
scripts/build-app.sh      # builds build/Typo.app
open build/Typo.app
```

typo lives in the menu bar (keyboard icon) and has no Dock icon. On first launch macOS asks for **Accessibility** access: allow it in System Settings → Privacy & Security → Accessibility. typo starts working as soon as access is granted; no relaunch needed.

The default build is ad-hoc signed, whose signature changes on every build, so the script resets typo's Accessibility grant each time and you grant it again. To keep the grant across rebuilds, sign with a stable identity (a free Personal Team certificate works):

```sh
CODESIGN_ID="Apple Development: you@example.com (TEAMID)" scripts/build-app.sh
```

## Send a test build to someone

```sh
scripts/package-for-testing.sh   # build/Typo-<version>-test.zip: Apple silicon + Intel, with README.txt
```

The build is ad-hoc signed and not notarized (that needs a paid Developer ID, ticket 15), so on the other Mac it has to be allowed once in System Settings → Privacy & Security → "Open Anyway"; `README.txt` in the zip explains it, in Russian and English.

## App icon

`Support/AppIcon.svg` is the source; `scripts/build-icon.sh` renders `Support/AppIcon.icns` from it with the system SVG renderer. Re-run it after editing the SVG.

## Interface languages

The interface is in English and Russian and follows the system language. Translations live in `scripts/localizations.py`, which writes the String Catalog `Sources/Typo/Resources/Localizable.xcstrings`; `build-app.sh` compiles it into the app. After adding or changing an interface string, add its translation there and run the script. `LocalizationTests` fails on any interface string without a Russian translation, and on unused keys.

## Test

```sh
swift test                 # all tests
swift test -c release      # also runs the timing tests, which are skipped in debug builds
```

The `Engine` module (pure Swift, no AppKit/Carbon) holds all correction logic and is covered by scenario tests. The macOS adapter and app shell (`Sources/Typo`) are checked by hand with [`docs/qa-checklist.md`](docs/qa-checklist.md).

## Language models

Detection uses one language model per supported language (English, Russian, German, Spanish) in `LanguageModels/`, built from the Leipzig Corpora Collection (CC BY). To rebuild them (downloads ≈1 GB once):

```sh
scripts/build-language-models.py
```

Next to them, `<code>.accents` tables list words whose ё, umlauts or accents typo restores when they are left out ("еще" → "ещё", "konnen" → "können"); rebuild with `scripts/build-accent-tables.py`. Sources, licences, attribution and the file formats are in [`LanguageModels/SOURCES.md`](LanguageModels/SOURCES.md). The accuracy test runs held-out news text through the Engine (`Tests/EngineTests/Accuracy/`, regenerate with `scripts/build-accuracy-corpus.py`).

## Password fields

Typo never touches what you type into a password field. Most of them turn on macOS secure input, which hides every key from typo. For those that do not, typo asks Accessibility whether the focused field is a password field (right after Tab, Return, a click or an app switch, and four times a second) and stays silent there: no corrections, no conversions, no learning, nothing remembered.

One case it cannot see: a password prompt in a terminal (`sudo`, `ssh`), which is plain text to macOS. Spelling fixes are already off in terminals, but a password typed in the wrong layout could be converted on Return. Turn on **Terminal → Secure Keyboard Entry** (iTerm2: **iTerm2 → Secure Keyboard Entry**), or add the terminal to Settings → Excluded Apps.

## Privacy

typo sees every key you press. What you type is kept in memory only for the current word and is never written to disk, logs or the network ([ADR 0003](docs/adr/0003-never-store-typed-text.md)). Settings → Statistics keeps only per-day counts of the rewrites typo made, for 8 weeks; turning it off deletes them ([ADR 0004](docs/adr/0004-daily-correction-counts.md)).

## License

typo is free software, licensed under the GNU General Public License version 3 only (SPDX: `GPL-3.0-only`). See [`LICENSE`](LICENSE) and [ADR 0002](docs/adr/0002-gplv3-license.md).
