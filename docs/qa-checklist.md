# Manual QA checklist

The macOS adapter and app shell have no unit tests; run this checklist before merging changes to `Sources/Typo` and before each release. Tickets that add adapter or app behaviour add their checks here.

Setup: turn off System Settings → Keyboard → Input Sources → "Automatically switch to a document's input source" (it can undo typo's layout switch). Build with `scripts/build-app.sh`, enable the **U.S.** and **Russian – PC** layouts, start on U.S. unless a check says otherwise. `␣` is Space, `⏎` is Return, `⇥` is Tab.

## App shell

- [ ] `scripts/build-app.sh` succeeds from a clean checkout
- [ ] `open build/Typo.app` shows a keyboard icon in the menu bar and no Dock icon
- [ ] The menu has **Pause Typo**, **Settings…** (⌘,), **About Typo**, **Check for Updates…** and **Quit Typo** (⌘Q); Quit quits the app
- [ ] Console.app filtered on process `Typo` shows no "language model … not loaded" errors

## Permissions and onboarding

- [ ] Fresh install (`tccutil reset Accessibility app.typo.Typo; tccutil reset ListenEvent app.typo.Typo; defaults delete app.typo.Typo`): the "Set Up Typo" window opens and shows both permissions as missing
- [ ] Each "Open System Settings…" button opens the right pane (Accessibility, Input Monitoring)
- [ ] Granting Accessibility turns its row green within a second and corrections start without relaunching
- [ ] Revoking Accessibility while Typo runs: the menu says "Accessibility permission was turned off." and nothing is corrected; granting it back resumes corrections
- [ ] Settings → General → "Launch at login" is on after the first launch; turning it off and rebooting does not start Typo; turning it on and rebooting does

## Pause, excluded apps and feedback

- [ ] **Pause Typo** shows a pause icon and `ghbdtn␣` stays; unpausing corrects again; the pause survives a relaunch
- [ ] Fresh settings: Settings → General → "Pause or resume Typo" shows `⌃⌘`; pressing ⌃ and ⌘ together and releasing them in TextEdit dims the icon and `ghbdtn␣` stays; doing it again corrects again
- [ ] ⌃⌘ followed by a key (⌃⌘F full screen, ⌃⌘Space emoji) or a click does not pause; a single tap of ⌃ or ⌘ does not pause
- [ ] ⌃⌘ also toggles inside a password field (Safari login form, Terminal with Secure Keyboard Entry on)
- [ ] Recorder: click, press ⌃⌥P → shows `⌃⌥P`, and ⌃⌥P now toggles from any app while ⌃⌘ does not; press ⌥⇧ alone → shows `⌥⇧`; Esc while recording keeps the old shortcut; ⌫ or ✕ clears it and it stays cleared after a relaunch; a plain letter only beeps
- [ ] A key combination another app has registered is removed at once, with "Another app uses … so it was removed" under the recorder
- [ ] Settings → Excluded Apps → add Terminal: nothing is corrected in Terminal, TextEdit still corrects; Spotlight opened over Terminal still corrects
- [ ] The menu-bar icon briefly fills on each correction
- [ ] No sound by default; with Settings → General → "Play a sound on each correction" on, each correction plays one sound, also two corrections in a row

## Settings

- [ ] Every change applies at once, without relaunching
- [ ] Changing the hotkey to "Double-tap Option": double Shift does nothing, double Option converts the last word
- [ ] Switch threshold 3: the layout switches after the third correction in a row; turning automatic switching off never switches
- [ ] Words: removing `ghbdtn` from Exceptions makes `ghbdtn␣` correct again; adding a word by hand stops it being corrected; removing a learned word stops its automatic correction
- [ ] Words shows one list at a time (Exceptions | Learned words), newest first: add `aaa`, then `bbb` → `bbb` is on top; adding `aaa` again moves it back to the top. Searching `cegth` or `супер` (any case) finds the word `cegth`; the search applies to whichever list is shown
- [ ] Upgrade: exceptions saved by 0.2.1 or earlier are all still listed, A to Z, after the ones added since (to repeat: `defaults delete app.typo.Typo wordsInAddedOrder` and relaunch)
- [ ] Thousands of words: quit Typo, back up its settings with `defaults export app.typo.Typo ~/typo-settings.plist`, write 10 000 exceptions with `defaults write app.typo.Typo exceptions -array $(python3 -c 'import random, string; print(" ".join("".join(random.choices(string.ascii_lowercase, k=random.randint(4, 10))) for _ in range(10000)))')`, launch Typo. Settings → Words opens without a visible pause and shows 50 words and "Show all (N)"; typing in the search field and in "Add a word" stays smooth; "Show all" scrolls smoothly to the end; removing a word is immediate. Afterwards quit Typo and restore with `defaults import app.typo.Typo ~/typo-settings.plist`
- [ ] Layouts lists every enabled layout, with U.S. and Russian – PC marked supported and an unsupported one (e.g. Ukrainian) marked "Not supported"

## Correction

Run in each app: TextEdit, Safari (a text field), Chrome (a text field), Terminal, an Electron app (VS Code or Slack). Record failures with the app name and version.

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn rfr ␣` on U.S. → `привет как `, and the menu-bar layout indicator switches to Russian after `rfr` | | | | | |
| After a click, `yt ghbdtn␣` on U.S. → `не привет ` (the short word is fixed with the next one); ⌫ right after → `yt ghbdtn ` | | | | | |
| `ghbdtn d␣` on U.S. → `привет в ` (the second correction, so the layout switches to Russian); `plan b␣` stays | | | | | |
| `ghbdtn API rfr␣` → `привет API как`, and the layout does not switch | | | | | |
| `,eltn␣` on U.S. → `будет ` (U.S. punctuation keys are Russian letters) | | | | | |
| `Ghbdtn␣` on U.S. → `Привет ` | | | | | |
| With Caps Lock on, `GHBDTN␣` on U.S. → `ПРИВЕТ ` | | | | | |
| `ghbdtn2␣`, `ghbdtn_rfr␣`, `getValue␣` on U.S. are left alone (skipped words) | | | | | |
| `/exit⏎`, `@user␣`, `#tag␣`, `$HOME␣` on U.S. are left alone; on Russian – PC, `.учше⏎` → `/exit` | | | | | |
| `ghb`, switch the layout with Caps Lock or 🌐 (no ⌘/⌃/⌥), `вет␣` → no correction | | | | | |
| `ghbdtn⏎` → `привет` then a new line | | | | | |
| `ghbdtn⇥` → `привет` then a tab (or focus moves on, as Tab does in that app) | | | | | |
| `hello world␣` on U.S. is left alone | | | | | |
| `plan b␣` on U.S. is left alone (short word) | | | | | |
| On Russian – PC, the keys of `hello␣` (`руддщ`) → `hello ` | | | | | |
| On Russian – PC, `сщву␣` → `code `, `тпштч␣` → `nginx ` | | | | | |
| `fdnjirjks␣` on U.S. → `автошколы ` (not in the bundled lexicon; confirmed by the system spell checker) | | | | | |
| Typing a normal paragraph in English on U.S. changes nothing | | | | | |
| Typing a normal paragraph in Russian on Russian – PC changes nothing | | | | | |
| `ghbdtnn⌫␣` → `привет ` (Backspace edits the word) | | | | | |
| `ghb`, click elsewhere in the text, `dtn␣` → no correction | | | | | |
| `ghb`, ⌘-Tab away and back, `dtn␣` → no correction | | | | | |
| `ghb`, ←, `dtn␣` → no correction | | | | | |

## Spelling fix

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `teh␣` → `the `, `превет␣` → `привет ` | | | | | |
| ⌫ right after `teh␣` → `teh ` again, and `teh` is left alone from then on | | | | | |
| A rare real word (`агентствах`, a name like `Кузьменков`) is left alone | | | | | |
| Settings → General → "Fix typos" off: `teh␣` stays | | | | | |

## ё, umlauts and accents

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| On Russian – PC: `еще␣` → `ещё `, `Елка␣` → `Ёлка `; `все␣`, `осел␣` stay | | | | | |
| On U.S. with German enabled: `konnen␣` → `können `; `schon␣` stays; `fur␣` stays (English) | | | | | |
| On U.S. with Spanish enabled: `tambien␣` → `también `; `esta␣`, `como␣` stay | | | | | |
| `tot␣` on U.S. (wrong layout) → `ещё ` | | | | | |
| ⌫ right after `еще␣` → `ещё` back to `еще `, and `еще` is left alone from then on | | | | | |
| Settings → General → "Add ё, umlauts and accents" off: `еще␣` stays | | | | | |

## Fast typing

Type as fast as you can, without pausing at the spaces. Nothing may be lost, duplicated or reordered.

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn rfr ltkf ` → `привет как дела ` | | | | | |
| `ghbdtn ,elen hf,jnfnm ` → `привет будут работать ` (letters on punctuation keys) | | | | | |
| `ghbdtn rfr ltkf ` typed fast: the layout switches to Russian only after `ltkf` is in, and it still becomes `дела` | | | | | |
| On Russian – PC: `сщву тпштч ршерги ` → `code nginx github ` | | | | | |
| Hold a letter key (auto-repeat) right after a corrected word: the repeated letters come after the correction | | | | | |

- [ ] Tap health: in a debug build, add `usleep(2_000_000)` to `KeyboardMonitor.keyDown` and type. The keyboard keeps working, Console (subsystem `app.typo.Typo`, category `tap`) logs "event tap timed out 3 times in a minute; pausing", and typo resumes after 60 s.

## Revert and exceptions

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `ghbdtn␣` then ⌫ at once → `ghbdtn ` again; typing `ghbdtn␣` later is left alone | | | | | |
| `ghbdtn rfr␣` (layout switches) then ⌫ → `привет rfr ` (only the last correction is reverted) and the layout is back to U.S. | | | | | |
| `ghbdtn⏎` or `ghbdtn⇥` then ⌫ → an ordinary Backspace (no revert after Return or Tab) | | | | | |

- [ ] Quit and relaunch typo: a word reverted before (`ghbdtn`) is still left alone (`defaults read app.typo.Typo exceptions` lists it)

## Manual conversion and learned words

| Check | TextEdit | Safari | Chrome | Terminal | Electron |
| --- | --- | --- | --- | --- | --- |
| `b␣` then double-tap Shift → `и ` and the layout switches to Russian | | | | | |
| Mid-word: `ghbd` then double-tap Shift → `прив`, keep typing `tn` on Russian → `привет` | | | | | |
| Double-tap Shift twice after `b␣` → back to `b ` and the layout back to U.S. | | | | | |
| `ghbdtn␣` (auto-corrected) then double-tap Shift → `ghbdtn ` (revert) | | | | | |
| After converting `b` by hand, typing `b␣` again later → `и ` | | | | | |
| Typing capitals (`Hello World`, Shift held while typing) never triggers a conversion | | | | | |

| Learning by retyping: type a word typo misses on U.S. (e.g. `cutythbhetv␣`), erase it with ⌫ (word and space), switch with ⌃Space, type `сгенерируем␣` → Settings → Words shows `cutythbhetv → сгенерируем`, and the next `cutythbhetv␣` is converted | | | | | |

- [ ] Quit and relaunch: a learned word is still corrected (`defaults read app.typo.Typo learnedWords`)

## Statistics

- [ ] After a few corrections, wait a minute (or quit Typo): `defaults read app.typo.Typo statistics` shows one entry for today, keyed like `2026-10-20`, holding only numbers under `layoutCorrection`, `spellingFix`, `accentRestoration`, `manualConversion`, `learnedFromRetyping`, `reverts`, `characters` and `secondsSaved`: no words, no times
- [ ] Corrections made just before quitting Typo are still counted after a relaunch
- [ ] With Settings → Statistics open, `ghbdtn␣` in TextEdit raises "Words fixed" by one under Today, 7 days and 30 days at once, and "Time saved" by ≈ 4 s
- [ ] ⌫ right after a correction lowers "Words fixed" by one again, and "Time saved" by a little more than the correction added
- [ ] "Time saved" shows seconds below a minute (`≈ 45 s`), then minutes (`≈ 2 min`), then hours and minutes (`≈ 1 h 5 min`)
- [ ] "Reset Statistics…" asks first: Cancel keeps the numbers, Reset empties every column (0 and `≈ 0 s`)
- [ ] Turning "Keep statistics" off shows "Statistics are off." and `defaults read app.typo.Typo statistics` finds nothing; corrections made while off are not counted; turned back on, every column starts from zero

## Password fields

- [ ] In a Safari login form's password field, typing `ghbdtn␣` is not corrected
- [ ] The same in Chrome, in an Electron app's login (e.g. Slack), and in a native app's password field (System Settings → Users & Groups → change password)
- [ ] In a password field, double Shift does nothing and nothing is learned
- [ ] Tab from the user name into the password field and type `ghbdtn⏎` at once: not corrected
- [ ] After leaving the password field, `ghbdtn␣` in a normal field is corrected again
- [ ] Terminal: `sudo -v`, then type a password like `ghbdtn⏎` without Secure Keyboard Entry: it may be corrected (known limit, see README). With Terminal → Secure Keyboard Entry on, nothing is corrected anywhere in Terminal

## Localization

- [ ] With macOS set to Russian (or `defaults write app.typo.Typo AppleLanguages '("ru")'` and relaunch), the menu, the "Set Up Typo" window, every Settings tab and About Typo are fully in Russian; with English, fully in English
- [ ] Settings → General shows "После 1 исправления подряд" / "После 2 исправлений подряд" as the stepper changes
- [ ] Settings → Статистика: "Сегодня", "7 дней", "30 дней", "Исправлено слов", "Сэкономлено" with `≈ 4 с`, `≈ 2 мин`, `≈ 1 ч 5 мин`

## Updates

Before a release, with the previous release installed in /Applications and the new one published (or `scripts/package-release.sh` checked locally):

- [ ] Fresh settings (`defaults delete app.typo.Typo`): the first launch does not ask about updates; the second launch asks once whether to check automatically, and the answer shows in Settings → General → "Check for updates automatically"
- [ ] **Check for Updates…** with the newest version installed says it is up to date
- [ ] With an older version installed, **Check for Updates…** shows the new version with its CHANGELOG notes; Install Update downloads, quits Typo, replaces it and relaunches it as the new version
- [ ] After the update, corrections work at once: Accessibility and Input Monitoring stay granted, no setup window
- [ ] Automatic checks on, an update published while Typo has been running a while: no window pops up while typing; the menu shows **Install Typo <version>…**, which opens the update window
- [ ] In Russian, Sparkle's update window is in Russian too
- [ ] A feed with one character changed (`appcast.xml` served locally via `defaults write app.typo.Typo SUFeedURL http://localhost:8000/appcast.xml`, remove it afterwards) is rejected with a signature error, nothing is installed

## Privacy

- [ ] Console.app filtered on process `Typo` shows nothing you typed
