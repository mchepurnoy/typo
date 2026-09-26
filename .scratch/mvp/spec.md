# Spec: typo MVP — automatic wrong-layout correction for macOS

Status: ready-for-agent

## Problem Statement

People who type in more than one script (e.g. Russian and English) constantly forget to switch the keyboard layout. They type a whole word — or a whole sentence — before noticing it came out as `ghbdtn` instead of `привет`, or `сщву` instead of `code`. Fixing it means deleting the word, switching the layout by hand, and typing it again. macOS has no built-in fix for this, the once-popular Punto Switcher for Mac is gone, and the remaining tools are closed-source apps that see every keystroke, which is a hard trust ask.

## Solution

typo is a small, native macOS menu-bar utility. It watches the keys being typed, and when a just-finished word is clearly nonsense in the current layout but clearly a real word when the same keys are read under another enabled layout, it replaces the word in place (a **correction**). If the user keeps typing in the other language, it also switches the macOS layout for them (a **layout switch**). A mistaken correction is undone with a single Backspace (a **revert**), and the word is then never touched again (an **exception**). A hotkey forces the conversion of the last word when detection stayed silent (**manual conversion**).

It works in every app, stores nothing the user types, talks to the network only to check for updates, and is free and open source (GPLv3) on GitHub, distributed as a signed, notarized download.

## User Stories

### Correction

1. As a bilingual typist, I want a word I typed in the wrong layout to be replaced automatically when I finish it, so that I don't have to delete and retype it.
2. As a typist on the U.S. layout, I want `ghbdtn` to become `привет` when I press Space, so that forgetting to switch costs me nothing.
3. As a typist on the Russian layout, I want `сщву` to become `code` and `тпштч` to become `nginx`, so that English technical words are fixed too.
4. As a typist, I want a correction to be triggered by Space, Return, Tab and punctuation-only boundaries, so that it happens at the natural end of a word.
5. As a typist, I want the boundary key I pressed (e.g. Space or Return) to still take effect after the correction, so that my flow and the app's behaviour (e.g. sending a message on Return) are preserved in the right order.
6. As a typist, I want keys that are letters in Cyrillic layouts (`, . ; ' [ ] \``) to count as part of the word, so that `,` typed on the U.S. layout can correctly become `б`.
7. As a typist, I want words that are valid in any supported language of my enabled layouts left alone, so that `schon` typed on the U.S. layout while I also have German enabled is not "corrected".
8. As a typist, I want only words that are clearly implausible as typed and clearly plausible when re-read to be corrected, so that false corrections are rare.
9. As a typist, I want a wrong-layout word that also contains a typo (e.g. `ghbdtnn`) to still be converted to the other layout, so that one extra key doesn't defeat the feature.
10. As a typist, I want capitalisation preserved (`Ghbdtn` → `Привет`, Shift-typed keys stay capital), so that the corrected word looks exactly as I intended.
11. As a user with any combination of enabled layouts, I want every enabled layout whose language is supported to take part, so that I'm not limited to one fixed pair.
12. As a user with English, German and Spanish layouts plus Russian, I want corrections to happen only between scripts (Cyrillic ↔ Latin), so that Latin layouts that share almost all keys don't fight each other.
13. As a user with several Latin layouts, I want the Latin target to be the one I used most recently, so that a later layout switch lands where I expect.
14. As a user with a layout whose language is not supported, I want that layout to be ignored rather than guessed at, so that I get no nonsense corrections.

### Short words and skipped words

15. As a Russian typist, I want short words like `d` → `в` and `yt` → `не` corrected when the previous word was corrected in the same direction, so that `ghbdtn d` becomes `привет в`.
16. As a typist, I want a lone one- or two-key word never corrected automatically otherwise, so that `plan b` stays `plan b`.
17. As a developer, I want words containing digits, `@`, `/`, `_`, `://`, mixed scripts, or camelCase skipped, so that code, paths, URLs and emails are never mangled.

### Layout switch

18. As a typist, I want the macOS layout to switch only after two consecutive corrections in the same direction, so that a single foreign term doesn't flip my layout.
19. As a typist, I want a word that needed no correction to reset that count, so that `ghbdtn API` does not lead to a switch.
20. As a user, I want the switch threshold to be adjustable in settings, so that I can make it more or less eager.

### Revert and exceptions

21. As a typist, I want Backspace pressed immediately after a correction to restore my original word and boundary, so that a wrong correction costs one key.
22. As a typist, I want the manual-conversion hotkey pressed immediately after a correction to also revert it, so that the hotkey toggles the last word.
23. As a typist, I want a reverted word to become an exception that is never corrected again, so that typo learns my vocabulary.
24. As a user, I want a revert to also undo any layout switch that correction caused, so that I'm back exactly where I was.
25. As a user, I want to see, remove and manually add exceptions in settings, so that I stay in control of what typo ignores.
26. As a typist, I want Backspace that is not immediately after a correction to behave normally and just shorten the current word, so that ordinary editing is unaffected.

### Learned words

27a. As a typist, I want a word I converted with the hotkey to be learned, so that the next time I type the same keys in the wrong layout typo corrects it automatically.
27b. As a user, I want to see and remove learned words in settings next to exceptions, so that a one-off manual conversion doesn't haunt me.
27c. As a user, I want reverting an automatic correction of a learned word to drop it from learned words and make it an exception, so that the last thing I did wins.

### Manual conversion

27. As a typist, I want a hotkey (default: double-tap Shift) that converts the last word to the other script regardless of detection, so that I can fix what typo missed.
28. As a user, I want to change the hotkey in settings, so that it doesn't collide with my other shortcuts.
29. As a typist, I want manual conversion to work on short words and skipped words too, so that it is a reliable escape hatch.

### Word tracking

30. As a typist, I want mouse clicks, arrow and navigation keys, Escape and ⌘/⌃/⌥ shortcuts to reset the current word, so that typo never rewrites text I moved away from.
31. As a typist, I want switching apps to reset the current word, so that keys from one app are never replayed into another.
32. As a user, I want typo to stay silent in secure (password) fields, so that passwords are never seen or altered.

### Where it works

33. As a user, I want typo to work in every app by default, including Terminal, browsers, Electron apps and IDEs, so that I don't have to configure anything.
34. As a user, I want to add apps to an excluded-apps list, so that typo ignores them entirely.
35. As a user, I want a Pause toggle in the menu bar, so that I can stop all corrections temporarily.

### Feedback and UI

36. As a user, I want the menu-bar icon to briefly animate when a correction happens, so that I notice it without being interrupted.
37. As a user, I want an optional correction sound, off by default, so that I can choose audible feedback.
38. As a user, I want a minimal, native menu-bar menu (Pause, Settings, Quit) and no Dock icon, so that typo stays out of the way.
39. As a user, I want a native settings window with tabs for General (launch at login, hotkey, switch threshold, sound), Exceptions and Excluded apps, and a list of my layouts showing which are supported, so that everything is in one place.
40. As a Russian- or English-speaking user, I want the interface in my language, so that it feels native.

### First run and permissions

41. As a new user, I want an onboarding window explaining why the Accessibility and Input Monitoring permissions are needed, showing the state of each, with buttons that open the exact System Settings panes, so that setup takes seconds.
42. As a new user, I want typo to detect automatically when permission has been granted and start working, so that I don't need to restart it.
43. As a user, I want typo to recover if the permission is revoked or the system disables its key listener, so that it doesn't silently stop working.
44. As a user, I want "Launch at login" on by default and switchable, so that typo is always there.

### Privacy and trust

45. As a privacy-conscious user, I want typed text never written to disk, logs or the network, so that typo cannot leak what I type.
46. As a privacy-conscious user, I want only settings and exceptions persisted, so that I know exactly what is stored.
47. As a sceptical user, I want the full source available under GPLv3, so that I can audit what an app that sees every key does.

### Distribution and updates

48. As a user, I want to download a signed, notarized app from a landing page, so that it installs without Gatekeeper warnings.
49. As a user, I want typo to update itself via Sparkle, so that I always have the latest fixes.
50. As a visitor, I want a small landing page with the icon, a short demo, the privacy promise and a download button, so that I can decide quickly.

### Performance

51. As a typist, I want corrections to happen with no perceptible delay and no lost, duplicated or reordered characters even when I type fast, so that typo never gets in my way.

## Implementation Decisions

### Modules

- **Engine** (pure Swift package, no AppKit/Carbon imports, the single test seam). A state machine that consumes input events and returns, for each event, whether to pass or swallow it plus a list of actions.
  - Input events: `key(keycode, shift)`, `boundary(kind)`, `backspace`, `reset(reason)` (mouse, navigation, chord, app switch), `hotkey`, `appActivated(bundleID)`, together with the current layout and the set of enabled layouts.
  - Actions: `erase(count)`, `type(text)`, `replayBoundary`, `selectLayout(id)`, `recordException(word)`, `signalCorrection`.
  - Owns: the current **word** (as keys, never as characters), the last correction (for revert), the layout-switch streak, and the rules for correction, short words, skipped words, revert, exceptions, learned words, manual conversion, excluded apps and pause.
  - Actions also include `recordLearnedWord(keys)`; settings seed the Engine with exceptions and learned words at start.
- **Layouts** (inside Engine, behind a small protocol). Reads a word's keys under any layout. Production implementation wraps `UCKeyTranslate` over each enabled input source's Unicode key layout data; tests use fixed key tables captured from U.S., Russian – PC, German and Spanish. Each layout knows its script and its language (if supported).
- **Detector** (inside Engine). Given a word and the enabled layouts, decides whether it is plausible as typed and which re-reading, if any, is clearly plausible. Scores with per-language **language models**: a word-frequency lexicon plus character n-gram log-probabilities, so unknown words (`nginx`) are still judged by how they look. Tolerant to one-key typos by construction (n-grams, not exact lookup). Decisions use a margin threshold between the best implausible-as-typed score and the best re-read score, tuned against the accuracy corpus.
- **Language model data**: one data file per supported language (English, Russian, German, Spanish) holding character trigram log-probabilities and a frequency lexicon, built offline by a script from the **Leipzig Corpora Collection** downloadable corpora (CC BY; attribution in the app's About and the repo) and bundled with the app. Adding a language is adding a data file. When scoring, `ё` is folded to `е`; output always keeps the character the key produced.
- **System spell check** (`NSSpellChecker`) is a cross-check for "is this a real word", behind a protocol the Engine receives, so the Engine stays AppKit-free and tests use the bundled lexicon only. It is never called inside the tap callback; it is warmed up at launch. It is not the sole criterion (it accepts many random 2-letter strings and trailing punctuation, and rejects lowercased German nouns).
- **macOS adapter** (app target, thin, manually tested). Installs a session-level `CGEventTap` (default tap, key-down + mouse-down), translates events into Engine events, performs Engine actions with `CGEvent` posting and `TISSelectInputSource`, re-enables the tap on `tapDisabledByTimeout`/`tapDisabledByUserInput`, observes app activation and input source changes.
- **App shell** (SwiftUI, `MenuBarExtra`, `Settings` scene, `LSUIElement`). Menu, settings tabs, onboarding window with Accessibility polling (`AXIsProcessTrustedWithOptions`), launch at login via `SMAppService`, Sparkle 2 updater, String Catalog localisation (EN, RU).
- **Settings store**: `UserDefaults` for preferences and the exception list. Nothing else is persisted (ADR 0003).

### Decisions validated by the prototype (branch `prototype/event-tap`)

- Keys are captured as physical keycodes + Shift and re-read with `UCKeyTranslate` against each enabled layout's data; this correctly reads `,.;` on U.S. as `бюж` on Russian – PC. Never hardcode a key map.
- Correction sequence on a boundary: swallow the boundary key-down, post `erase(original length)` as Backspaces, post the replacement so it does not depend on the active layout, then re-post the boundary. Revert is the inverse. Revert is only offered when the boundary was Space or Tab (a replayed Return cannot be un-sent).
- Our own synthetic events are marked via the `eventSourceUserData` field with a fixed tag and ignored by the tap; synthetic events use a private-state event source with cleared modifier flags.
- A `decide()` call on the trivial detector took ~0.005 ms; the per-word budget for the real detector is ≤ 1 ms p99, far below the perceptibility threshold.
- The replay-keycodes-after-switching-layout approach was built but not validated; retyping independently of the active layout is the chosen one (research §4 agrees: never depend on a layout switch having landed).

### Decisions from `docs/research/macos-layout-autofix-apis.md`

These refine the prototype, which posted everything synchronously inside the tap callback and was not stress-tested:

- **Fix pipeline with a fence.** While a fix is in flight the adapter is busy: real keystrokes are swallowed into a deferred queue; the fix events are posted, followed by a tagged "fence" event carrying a sequence number; when the fence comes back through the tap, the deferred keystrokes are re-posted as freshly created events (not copies). An 800 ms timeout flushes the queue if the fence never arrives. This keeps the tap callback O(µs) and allows pacing (a small delay between synthetic keystrokes) if some apps turn out to drop fast input.
- **Retyping.** One character per key-down/up pair, using the target layout's keycode and modifier flags plus an explicit Unicode string, so apps that read keycodes and apps that read strings both get the right character.
- **Layout switch** happens after the retype, for future typing only; all TIS calls run on the main thread; the switch is verified asynchronously via the selected-input-source-changed notification.
- **Secure input.** While `IsSecureEventInputEnabled()` is true the engine receives a reset and nothing is buffered or corrected.
- **Tap health.** Re-enable the tap on `tapDisabledByUserInput` and `tapDisabledByTimeout`, but back off (e.g. 60 s) after repeated timeouts within a minute instead of re-enabling in a loop. No disk I/O, spell-checker cold lookups or AX IPC inside the callback; language models are loaded into memory at launch.
- **Permissions.** Accessibility (event posting / active filtering) **and** Input Monitoring (listening) — separate grants on macOS 14, possibly merged on macOS 26. Onboarding checks each with `AXIsProcessTrustedWithOptions`, `CGPreflightListenEventAccess` and `CGPreflightPostEventAccess`, requests with `CGRequestListenEventAccess` / `CGRequestPostEventAccess`, and shows the state of each.
- **Distribution.** Non-sandboxed, hardened runtime, Developer ID, notarized (consistent with ADR 0001).
- **Detector shape**, following xneur and translit: a cheap first pass over impossible character bigrams/trigrams per language, then n-gram log-probability scoring, with a real-word lexicon check that outranks n-gram scores; preceding-word language ("stickiness") feeds the short-word rule. Detection runs off the tap callback's critical section; `NSSpellChecker` only as a warmed-up cross-check (see Language model data).

### Other decisions

- Minimum macOS 14. Swift 6 language mode in the Engine package.
- Bundle ID is a placeholder until the name and domain are final; the name "Typo" is a working name.
- Distribution: Developer ID signed + notarized DMG, Sparkle appcast hosted with the landing page (ADR 0001). Development uses a free Personal Team certificate so the Accessibility grant survives rebuilds.
- Landing page: static site in the same repo, hosted on GitHub Pages. App icon drawn as SVG and exported to an asset catalog.
- License: GPLv3 (ADR 0002).

## Testing Decisions

- A good test drives the Engine only through its public event→actions interface and asserts on the returned pass/swallow decision and actions, never on internal state. Tests read like scenarios: "on U.S. with Russian – PC enabled, typing `ghbdtn` then Space swallows Space and yields erase(6), type("привет"), replayBoundary".
- The Engine is the only unit-tested module. Behaviour tests cover every glossary rule: correction, skipped word, short word, layout switch streak and reset, revert by Backspace and by hotkey, exception recording and honouring, manual conversion, excluded app, pause, reset events, capitalisation, cross-script-only, multiple Latin layouts, unsupported layout.
- An accuracy test runs a corpus of (layout, keys, expected output or "no change") cases through the Engine with the real language model data and asserts on a minimum hit rate for wrong-layout words and a near-zero false-positive rate on normal EN/RU/DE/ES text and technical terms. The corpus includes the cases found during the prototype (`тпштч` → `nginx`, `сщву` → `code`) and, as a first-class category, Russian words containing letters that sit on U.S. punctuation keys (`б ю ж э х ъ ё`, ~30% of frequent Russian words), which the research benchmark left untested. Research baseline to beat: ~98–99% recall at ~0% false positives on 6+ letter EN↔RU words.
- A performance test asserts the per-word decision budget.
- The macOS adapter and app shell are verified manually with a checklist in TextEdit, Safari, Chrome, Terminal and an Electron app (e.g. VS Code or Slack): correction, revert, layout switch, fast typing without artifacts, password fields, permission revoke/regrant.
- No prior art exists in the repo; the Engine test suite establishes the convention (Swift Testing, `swift test`).

## Out of Scope

- Spelling fixes (`teh` → `the`) — planned right after the MVP as a separate, separately toggled feature.
- Retroactive correction: holding an ambiguous word and correcting it once the next word confirms the language (`yt ghbdtn` → `не привет`) — the first feature after the MVP.
- Learning from a word the user deletes and retypes by hand in the other layout (only hotkey conversions are learned in the MVP).
- Local AI for detection — after the MVP; the Detector stays swappable. Research: Foundation Models does not support Russian and costs tens–hundreds of ms per call; `NLLanguageRecognizer` cannot tell layouts apart across scripts; a tiny CPU Core ML model (~53 µs) is the viable later option.
- Corrections between layouts of the same script (EN ↔ DE ↔ ES, y/z swap, umlauts).
- Converting selected text.
- Fixing accidental Caps Lock.
- Statistics, text snippets/auto-replacements.
- One-time payment and licensing.
- Mac App Store distribution.
- Languages beyond English, Russian, German, Spanish.

## Further Notes

- Glossary: `CONTEXT.md`. Decisions: `docs/adr/0001` (outside App Store), `0002` (GPLv3), `0003` (never store typed text).
- Research: `docs/research/macos-layout-autofix-apis.md` (macOS APIs, permissions, fix pipeline, survey of open-source switchers). Useful references pinned there: arolus/translit (MIT, n-grams + Bloom filters), rshagiev/punto-switcher (fence-based fix pipeline), xneur (impossible n-gram tables).
- Research on data and on-device AI: `docs/research/0001-language-data-and-local-ai.md`. Punto's `ps.dat` and keyboop's data are not reusable. Open from it: which CC BY version Leipzig means (check before first release); NSSpellChecker cold-start cost inside the real app.
- macOS's "Automatically switch to a document's input source" setting can undo our layout switch; onboarding or settings should mention it.
- Open unverified points to check by hand: event-tap timeout length, whether Backspace count equals composed characters when dead keys or system autocorrect are involved, and the effect of the 0.25 s local-events suppression interval.
- Prototype: branch `prototype/event-tap`, `prototype/event-tap-spike/` — a single-file spike runnable with `run.sh`.
