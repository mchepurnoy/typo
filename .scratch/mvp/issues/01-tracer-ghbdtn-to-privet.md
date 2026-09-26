# 01: Tracer bullet: `ghbdtn` → `привет` end to end

**What to build:** A menu-bar app (icon + Quit, no Dock icon) that, once granted Accessibility, corrects a word typed on U.S. that is a Russian word on Russian – PC (and vice versa) when Space/Return/Tab is pressed, in TextEdit. Detection uses a small built-in word list for now. Establishes the Engine package (pure Swift, event→actions interface from the spec) with scenario tests, the thin macOS adapter (event tap, synthetic events tagged and ignored, layout reading via UCKeyTranslate — as in the prototype on branch `prototype/event-tap`), the GPL-3.0-only LICENSE, and a manual QA checklist that later tickets extend.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [x] `swift test` runs Engine scenario tests: `ghbdtn`+Space on U.S. yields swallow + erase(6) + type("привет") + replayBoundary; a known English word yields pass
- [x] Engine never imports AppKit/Carbon; layouts come through a protocol with fixture tables for U.S. and Russian – PC in tests
- [x] App builds from the command line and launches as a menu-bar-only app
- [ ] Accessibility is requested on first launch; the tap starts once granted
- [ ] Typing `ghbdtn rfr ` in TextEdit on U.S. produces `привет как `
- [x] LICENSE is GPL-3.0-only; README says how to build and run
- [x] Manual QA checklist exists in the repo

Spec: `.scratch/mvp/spec.md`. Glossary: `CONTEXT.md`.

## Comments

2026-09-26 — Implemented: `Engine` package (`Sources/Engine`, scenario tests in `Tests/EngineTests` with U.S. and Russian – PC fixture tables captured via `UCKeyTranslate`), macOS adapter + menu-bar shell (`Sources/Typo`), `scripts/build-app.sh`, `LICENSE`, `README.md`, `docs/qa-checklist.md`. Verified: `swift test` green; app builds and launches as a `UIElement` (no Dock icon). Not verified by the agent (needs a human to grant Accessibility): the permission flow and `ghbdtn rfr ` → `привет как ` in TextEdit — run the Permissions and Correction sections of `docs/qa-checklist.md`.

Code review follow-ups left to later tickets: synthetic events can interleave with keys typed during a correction, and the retype posts keycode 0 with a Unicode string (both ticket 09); Caps Lock is not read, so `GHBDTN` with Caps Lock becomes `привет` (ticket 05); the erase count assumes no dead-key composition (open point in the spec). The tracer already leaves words of ≤ 2 keys alone; ticket 06 adds the same-direction exception.
