# Changelog

Each release's notes: `scripts/package-release.sh` publishes the section headed with the version from `Support/Info.plist` on GitHub Releases and in the update window. Write them for people who use Typo.

## 0.5.0

- Accents without a layout. If you write Spanish, German or French on the U.S. layout, tick the language in Settings → Layouts → **Languages without a layout**: `ninos` becomes `niños`, `konnen` becomes `können`, `francais` becomes `français`. Typo also stops treating that language's words as typos. Languages from your macOS Preferred Languages start ticked.
- Words that exist in English too (`nino`, `mas`, `ano`, `fur`, `uber`) now get their accent when the words before them are Spanish or German. Typed alone or in English text they stay as they are.
- French is supported: words typed on a French layout instead of a Russian one, and the other way round, are corrected, and French accents are restored (`deja` → `déjà`, `coeur` → `cœur`, `l'ecole` → `l'école`). Words with `é`, `è`, `ç` or `à` typed on a Russian layout are not corrected yet: those keys type digits there.
- As before, a pair where both spellings are words (`esta`/`está`, `ou`/`où`) is left alone, Backspace right after a change takes it back, and "Add ё, umlauts and accents where certain" in Settings → General turns all of this off.

## 0.4.0

- Typo updates itself from GitHub Releases. On the second launch it asks whether to check automatically, once a day; Settings → General can turn that on or off, and **Check for Updates…** in the menu checks at once.
- The update window appears on its own only right after launch; later on, the menu offers **Install Typo …**, so it never takes the keyboard mid-sentence.
