# typo

A macOS menu-bar utility that notices when a word was typed in the wrong keyboard layout and re-types it in the right one.

## Language

**Layout**:
A keyboard input source the user has enabled in macOS (e.g. U.S., Russian – PC). Any enabled layout can take part, not a fixed pair.
_Avoid_: keyboard, language (a layout is not a language)

**Supported language**:
A language typo ships a language model for (initially English, Russian, German, Spanish). Layouts whose language is unsupported never take part in corrections.

**Language model**:
Per-language data that judges how plausible a word is in that language; added as data, not code.
_Avoid_: dictionary (it is more than a word list), AI

**Word**:
The physical keys pressed since the last word boundary, kept as keys rather than characters so it can be re-read under any layout.
_Avoid_: token, buffer

**Script**:
The alphabet a layout produces (Latin, Cyrillic). Corrections only ever cross scripts; layouts sharing a script are interchangeable for correction.

**Correction**:
Automatic replacement of a just-finished word with the same keys re-read under another layout, triggered at the word boundary, only when the original word is implausible in every supported language and the re-read one is clearly plausible.
_Avoid_: fix, switch, conversion

**Spelling fix**:
Replacing a misspelled word with the intended word in the same layout (e.g. `teh` → `the`). A separate feature from correction, planned after the MVP; correction itself must still recognise wrong-layout words that also contain a typo.
_Avoid_: typo correction, autocorrect

**Short word**:
A word of at most two keys; corrected automatically only when the previous word was corrected in the same direction.

**Skipped word**:
A word never considered for correction because it looks technical: contains a digit, `@`, `/`, `_`, mixes scripts, or is camelCase.

**Manual conversion**:
A correction the user forces with a hotkey on the last word, regardless of what detection decided.
_Avoid_: force switch

**Revert**:
Undoing a correction by pressing Backspace or the manual-conversion hotkey immediately after it; restores the original word and records an exception.
_Avoid_: undo, rollback

**Exception**:
A word that is never corrected again, recorded by a revert or added by hand; the user can review and remove them.
_Avoid_: whitelist entry, ignore rule

**Layout switch**:
Changing the active macOS layout, done only after several consecutive corrections in the same direction (default two), so a single foreign term does not flip the layout.
_Avoid_: auto-switch

**Excluded app**:
An app the user has told typo to ignore entirely; the list starts empty.
_Avoid_: blacklist

**Pause**:
A global off switch in the menu bar that stops all corrections until resumed.
