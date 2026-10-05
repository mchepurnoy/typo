# 14: App icon and menu-bar icon

**What to build:** A minimal, native-looking app icon drawn as SVG and exported to the asset catalog in all sizes, plus a template menu-bar icon (and its correction-animation frames) that adapts to light/dark menu bars.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [x] SVG source committed; asset catalog generated from it by a script
- [ ] Icon looks right in Finder, Dock-less About panel, and both menu-bar appearances

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-10-01 — App icon: `Support/AppIcon.svg`, a keycap labelled like a bilingual keyboard (Latin Z, Cyrillic Я, which share a key) on an indigo macOS-grid squircle. `scripts/build-icon.sh` renders all ten iconset sizes with the system SVG renderer (`scripts/render-svg.swift`, no extra tools) and builds `Support/AppIcon.icns` with `iconutil`. `build-app.sh` bundles it (`CFBundleIconFile`). Deviation: an `.icns` rather than an asset catalog, since the app is built with SwiftPM, not an Xcode project. Menu-bar icon (2026-10-05): a template keycap with "Я" drawn in code (`MenuBarImage`), filled with the letter cut out for the correction flash, dimmed while paused or not running. Added an About Typo menu item that shows the icon, the license and the Leipzig CC BY attribution. Left for a human: checking the icon in Finder, the About panel, and both menu-bar appearances.
