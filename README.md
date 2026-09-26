# typo

A native macOS menu-bar app that fixes words typed in the wrong keyboard layout: type `ghbdtn` on the U.S. layout, press Space, get `привет`.

Early development. Detection currently uses a small built-in word list (see `Sources/Engine/Detector.swift`).

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

## Test

```sh
swift test
```

The `Engine` module (pure Swift, no AppKit/Carbon) holds all correction logic and is covered by scenario tests. The macOS adapter and app shell (`Sources/Typo`) are checked by hand with [`docs/qa-checklist.md`](docs/qa-checklist.md).

## Privacy

typo sees every key you press. What you type is kept in memory only for the current word and is never written to disk, logs or the network ([ADR 0003](docs/adr/0003-never-store-typed-text.md)).

## License

typo is free software, licensed under the GNU General Public License version 3 only (SPDX: `GPL-3.0-only`). See [`LICENSE`](LICENSE) and [ADR 0002](docs/adr/0002-gplv3-license.md).
