# 0001 — Language-model data, how existing switchers detect, and on-device AI

- Date: 2026-09-26
- Scope: data for the per-language **Language model** (EN, RU, DE, ES); detection techniques in existing layout switchers; on-device ML/LLM options on macOS for a ~10 ms per-word budget.
- Evidence labels used throughout:
  - **[V]** verified against the primary source linked next to it (docs, license file, source code at a pinned commit).
  - **[M]** measured locally by this research on an Apple M1 Pro, macOS 26.5.2 (25F84), Xcode toolchain Swift 6.3. Throwaway benchmark code lived in `/tmp` and was not committed; the method is described so it can be re-run.
  - **[I]** inference or recommendation by the author. Not a fact, and not legal advice.

> **Discrepancy with the brief.** The brief says typo is "MIT, may be sold later". The repo decided otherwise: [ADR 0002](../adr/0002-gplv3-license.md) licenses the code under **GPLv3**, and [ADR 0001](../adr/0001-distribute-outside-app-store.md) ships **outside the Mac App Store**. CONTEXT.md also says corrections **only ever cross scripts** ([CONTEXT.md](../../CONTEXT.md), "Script"). This document checks data licenses against **both** MIT and GPLv3. Where they differ, the GPLv3 answer is the one that applies to the repo as it stands.

---

## TL;DR

1. **Build our own language models from CC BY data.** The Leipzig Corpora Collection licenses its downloadable corpora under **CC BY** ([terms of usage](https://wortschatz.uni-leipzig.de/en/usage)) [V]. It has EN/RU/DE/ES corpora of up to 1M sentences [V] and works under MIT, GPLv3 and paid builds. Tatoeba (CC BY 2.0 FR) [V] is a good source of evaluation sentences. [I]
2. **Share-alike lists are usable under GPLv3 but carry obligations.** FrequencyWords data and wordfreq data are **CC BY-SA 4.0** [V]. CC BY-SA 4.0 is one-way compatible with **GPLv3** ([CC](https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/), [FSF](https://www.gnu.org/licenses/license-list.en.html#ccbysa)) [V]. So a GPLv3 typo *may* ship a model derived from them, but not under "GPLv3 **or later**" [V: FSF]. Under MIT, the derived data file would stay CC BY-SA. wordfreq's author asks that its data not be flattened into attribution-less formats like CSV [V]. Prefer Leipzig and keep these as cross-checks. [I]
3. **Dictionary licenses.** Permissive: en_US (SCOWL) and ru_RU (Lebedev, BSD-style) [V]. es is tri-licensed GPLv3+/LGPLv3+/MPL 1.1+ [V]. de_DE_frami is **GPL v2 or v3** only [V]; its OASIS exception covers only unmodified use in ODF-primary office apps [V]. That is fine for a GPLv3 typo and a blocker for an MIT typo. [I]
4. **NSSpellChecker is a strong zero-bundle baseline** [M]:
   - It has dictionaries for en, ru, de and es.
   - Warm calls take ~0.08–0.10 ms median and ≤0.85 ms p99.
   - It accepts ~33% of *random* 2-letter Latin strings as English and ~21% of random 2-letter Cyrillic strings as Russian.
   - It accepts `привет!` and `дума.` (the trailing punctuation passes).
   - It rejects **lowercased German nouns**: 855 of 3,000 frequent 4+-letter German words, e.g. `frau`, `vater`.
5. **A character-trigram model is ~2 µs per word in Swift** [M]. Measured on EN↔RU, a hybrid rule gives ~98–99% recall on 6+-letter words at ~0% false positives. The hybrid is: "typed word is not a valid source word" AND ("converted word is valid in the target language and has a positive trigram margin" OR "the trigram margin is large"). Its 2-letter false positives are 6–8%. All the risk is in words of ≤3 letters. [M]
6. **About 30% of frequent Russian words** (24% of Russian tokens) contain a letter that lives on a U.S. punctuation key [M]. `б ю ж э х ъ` sit on `,` `.` `;` `'` `[` `]`, and `ё` is on `\` or keycode 10 depending on the layout. My accuracy experiment *excluded* these words. Handling them is a first-class requirement, not an edge case.
7. **On-device ML fits the budget if it is tiny and runs on the CPU** [M]:
   - Custom Core ML MLP: 53 µs on CPU, 270 µs on the Neural Engine, 404 µs on the GPU.
   - Create ML maxEnt text classifier via `NLModel`: 33–39 µs.
   - `NLLanguageRecognizer`: ~110 µs, and it cannot help across scripts (`ghbdtn` → `en = 1.00`).
   - `NLEmbedding` has **no Russian** word embedding on macOS 26.5.
8. **The Foundation Models framework does not fit the per-word path** [V]+[I]:
   - It needs macOS 26 and Apple Intelligence enabled.
   - The device language and the Siri language must be the same supported language.
   - It has a 4,096-token context.
   - Its supported languages **do not include Russian** [V/M]; the framework throws `unsupportedLanguageOrLocale` for unsupported input [V].
   - Latency was not measured here because Apple Intelligence is off on the test Mac.
   - Apple's only published figure is 0.6 ms per prompt token plus 30 tokens/s generation, on iPhone 15 Pro [V]. That puts one call in the tens-to-hundreds of ms. [I]
   - MLX Swift is unnecessary for a problem this size. [I]
9. **Recommended architecture** [I]:
   - Hot path, deterministic, < 1 ms per word, running off the event-tap callback thread: keycode buffer → re-read under every enabled layout (UCKeyTranslate) → gates → char n-gram margin + bundled frequency lexicon + NSSpellChecker cross-check → a small logistic combiner.
   - Two thresholds: auto-correct only above τ_high; hold ambiguous words for the next word's context.
   - No LLM in v1.

---

## 1. Data sources for word frequency and character n-grams

### 1.1 License comparison

"Bundle OK?" answers whether typo may ship data **derived** from the source (e.g. a trigram table or frequency lexicon) inside the app. The first answer is for an MIT app sold commercially, the second for the repo's actual GPLv3 license. All "OK?" judgements are **[I]**. The license facts are **[V]** with links.

| Source | What it is | Data license (verified) | MIT + paid build | GPLv3 + paid build (repo) | Size | Quality notes |
|---|---|---|---|---|---|---|
| **hermitdave/FrequencyWords** | Word-frequency lists from OpenSubtitles 2016/2018 | "MIT License for code. **CC-by-sa-4.0 for content**." ([README](https://github.com/hermitdave/FrequencyWords)). OPUS asks users of OpenSubtitles to "add a link to http://www.opensubtitles.org/" ([OPUS](https://opus.nlpl.eu/legacy/OpenSubtitles-v2018.php)) | Yes. The derived data file stays CC BY-SA 4.0 with attribution. Code stays MIT. [I] | Yes. BY-SA 4.0 → GPLv3 one-way compatible, but not "or later" ([FSF](https://www.gnu.org/licenses/license-list.en.html#ccbysa)) [V] | `ru_50k.txt` 0.95 MB, `ru_full.txt` 27.7 MB, `de_full.txt` 16.7 MB ([GitHub API listing](https://api.github.com/repos/hermitdave/FrequencyWords/contents/content/2018/ru)) [V] | Spoken/subtitle register. The RU top 50k holds **736 Latin tokens** (`the` at rank 725). `ё` is used inconsistently (`все` 722,378 vs `всё` 373,088) [M, from [ru_50k.txt](https://raw.githubusercontent.com/hermitdave/FrequencyWords/master/content/2018/ru/ru_50k.txt)]. Many proper names. |
| **rspeer/wordfreq** | Blended frequencies (Wikipedia, subtitles, news, books, web, Twitter, Reddit) | Code **Apache-2.0**. Data "**Creative Commons Attribution-ShareAlike 4.0**". Includes SUBTLEX under an e-mailed permission with conditions ("must credit the SUBTLEX authors", "must remain clear that SUBTLEX is freely available data"). Google Books terms: "may be freely used for any purpose". OpenSubtitles "may be used with attribution" ([README § License](https://github.com/rspeer/wordfreq#license)) | Yes with SA, but the author says converting to CSV "does not follow the CC-By-SA license" and suggests porting the library with credits instead ([README FAQ](https://github.com/rspeer/wordfreq#can-i-convert-wordfreq-to-a-more-convenient-form-for-my-purposes-like-a-csv-file)). Awkward. [I] | Same as MIT with SA, plus GPLv3 compatibility for BY-SA parts [V: FSF] | "small" lists: words ≥1 per million. "large" lists: ≥1 per 100 million. EN/DE/RU/ES all have "large" ([README](https://github.com/rspeer/wordfreq)) | **Frozen**: "a snapshot of language usage through about 2021 … unlikely to be updated again" ([README](https://github.com/rspeer/wordfreq), [SUNSET.md](https://github.com/rspeer/wordfreq/blob/master/SUNSET.md)). Good multi-register blend. Needs its Python tokenizer and normalisation to reproduce. |
| **Leipzig Corpora Collection** | Random-sentence corpora (news, web, Wikipedia) with precomputed word lists and co-occurrences | "The text corpora offered for download are made available under the Creative Commons licence **CC BY**." The web portal and other data are "CC BY-NC" and ban "commercial use of the data" ([Terms of Usage](https://wortschatz.uni-leipzig.de/en/usage)) | **Yes**, attribution only. Use the *downloaded corpora*, not the portal or API data. The version is not stated; see open questions. [I] | Yes. FSF lists CC BY **4.0** as compatible with all GPL versions ([FSF](https://www.gnu.org/licenses/license-list.en.html#ccby)); the version of Leipzig's "CC BY" is unstated. [I] | "from 10,000 sentences up to 1 million sentences" ([downloads](https://wortschatz.uni-leipzig.de/en/download)) [V]. `rus_news_2022_1M.tar.gz` is 227 MB (HTTP HEAD) [M] | Formal (news/web) register, fewer colloquial forms. Sentences are shuffled to break documents ([downloads](https://wortschatz.uni-leipzig.de/en/download)). The tarball ships a `-words.txt` frequency list but **no license file** [M]: we must record attribution ourselves. Cite Goldhahn et al. LREC 2012 as requested. |
| **Hunspell en_US (SCOWL)** in LibreOffice | Spelling dictionary + affix rules | "Permission to use, copy, modify, distribute and **sell** these word lists … provided that the above copyright notice appears in all copies". The affix file is under the Ispell BSD license ([README_en_US.txt](https://github.com/LibreOffice/dictionaries/blob/master/en/README_en_US.txt)) | Yes | Yes | Normal dictionaries "correspond to SCOWL size 60", large to size 70 ([README_en_US.txt](https://github.com/LibreOffice/dictionaries/blob/master/en/README_en_US.txt)) | No frequencies. Needs affix expansion. The large lists "contain uncommon, yet valid, words that might cause problems" (same README). |
| **Hunspell ru_RU (Lebedev)** | Spelling dictionary | BSD-style: retain the notice; "Modified versions must be clearly marked as such"; no-endorsement clause ([README_ru_RU.txt](https://github.com/LibreOffice/dictionaries/blob/master/ru_RU/README_ru_RU.txt)) | Yes | Yes (permissive) [I] | — | No frequencies. Needs affix expansion. |
| **Hunspell de_DE_frami (igerman98)** | Spelling dictionary | "lizenziert unter der **GNU GPL, Version 2 oder 3**" ([README_de_DE_frami.txt](https://github.com/LibreOffice/dictionaries/blob/master/de/README_de_DE_frami.txt)). The OASIS 0.1 alternative applies only "without any modifications" to programs "whose PRIMARY format for saving documents is the Open Document Format" ([COPYING_OASIS.txt](https://github.com/LibreOffice/dictionaries/blob/master/de/COPYING_OASIS.txt)) | **No** for a closed or MIT build: GPL. Where "aggregate" ends is "a legal question" ([GPL FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation)). [I] | Yes (use it under GPLv3) [I] | — | Good coverage; noun capitalisation matters (see §3.3). |
| **Hunspell es (RLA-ES)** | Spelling dictionaries per country | Tri-license: "GNU GPL versión 3 o posterior, GNU LGPL versión 3 o posterior, ó MPL versión 1.1 o posterior" ([LICENSE.md](https://github.com/LibreOffice/dictionaries/blob/master/es/LICENSE.md)) | Yes, choosing MPL 1.1 (file-level copyleft: modified dictionary files must stay MPL) [I] | Yes, choosing GPLv3. MPL 1.1 alone is GPL-incompatible, but a GPL alternative makes it compatible ([FSF](https://www.gnu.org/licenses/license-list.en.html#MPL)) | — | — |
| Hunspell engine (if we parse .aff/.dic ourselves we do not need it) | Library | "MPL 1.1/GPL 2.0/LGPL 2.1" ([license.hunspell](https://github.com/hunspell/hunspell/blob/master/license.hunspell)) | — | — | — | — |
| **Google Books Ngram v3 (2020-02-17)** | 1–5-grams per year from scanned books; has eng/ger/rus/spa | "This compilation is licensed under a **Creative Commons Attribution 3.0 Unported** License" ([datasets v3](https://storage.googleapis.com/books/ngrams/books/datasetsv3.html)) | Yes, attribution | Likely fine for data shipped as a separate file. FSF names only CC BY 4.0 as GPL-compatible ([FSF](https://www.gnu.org/licenses/license-list.en.html#ccby)) [I] | Very large: one of the Russian 1-gram shards (`rus/1-00000-of-00002.gz`) is 840 MB compressed (HTTP HEAD) [M] | Book register (formal, historical), OCR noise, per-year rows. Only n-grams with >40 occurrences are included ([datasets page](https://storage.googleapis.com/books/ngrams/books/datasetsv3.html)). |
| **Wiktionary frequency lists** | Wiki pages listing frequencies | Wiktionary text is dual-licensed "CC-BY-SA" 4.0 and GFDL ([Wiktionary:Copyrights](https://en.wiktionary.org/wiki/Wiktionary:Copyrights)) | As FrequencyWords (SA) | As FrequencyWords | — | Mostly re-hosts other lists. The Russian page links "50K and larger word lists based on www.opensubtitles.org for Russian (CC BY-SA-4.0)" ([page](https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Russian)). Prefer the upstream source. |
| **Tatoeba** | Crowd-sourced sentences | "These files are released under **CC BY 2.0 FR**"; "A part of our sentences are also available under CC0 1.0" ([downloads](https://tatoeba.org/en/downloads)) | Yes (attribution) | Data file OK as a separate work; best used only for the **evaluation set**, not bundled [I] | Small | Short, conversational sentences: close to real typing. |
| Data inside other OSS switchers (e.g. keyboop's `words_ru.json` / `trigrams_*.json`) | Word lists / trigram tables | keyboop says they come from `graninilya/keyswitcher`, MIT ([THIRD_PARTY.md](https://github.com/iffuno/keyboop/blob/2862cf12cc4db3c52ff9e827b20c8f5c743dc2af/THIRD_PARTY.md)) | **Avoid** [I] | **Avoid** [I] | 3.9 MB RU word list [M] | keyswitcher documents no upstream source for these lists [M: repo at `0a51fc2`]. SwitchFix's `ru_RU.txt` starts with the same entries (`а, абажур, абажурный, абажурчик, абаз`) [M]. The MIT label may not match the true origin. |

### 1.2 How share-alike interacts with a derived n-gram model [V] + [I]

- CC BY-SA 4.0 defines Adapted Material as material "derived from or based upon the Licensed Material … in a manner requiring permission under the Copyright and Similar Rights". Those rights explicitly include **Sui Generis Database Rights** (EU Directive 96/9/EC) ([legal code §1, §4](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en)) [V].
- §4 says that if you include "all or a substantial portion of the database contents in a database in which You have Sui Generis Database Rights, then the database … is Adapted Material" [V]. **Inference:** a frequency lexicon or n-gram table built from a *substantial portion* of a CC BY-SA list is safest treated as Adapted Material. It must stay BY-SA, or become GPLv3 for a GPLv3 project.
- BY-SA 4.0 also forbids "Effective Technological Measures" that restrict recipients ([legal code §2(a)(5)(C)](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en)) [V]. **Inference:** this is moot for us because ADR 0001 rules out the App Store. Notarised Developer ID distribution applies no DRM to bundled data files.
- Whether pure character-trigram probabilities are copyrightable at all varies by jurisdiction. **Do not rely on "statistics aren't copyrightable"**: attribute everything and pick sources whose license we are happy to comply with anyway. [I]

### 1.3 Data recommendation [I]

- **Primary:** Leipzig downloadable corpora (CC BY), e.g. `*_news_*_1M` and `*_web_*_1M` for eng/rus/deu/spa. From them derive (a) a character n-gram model per language and (b) a frequency lexicon (top ~100k word forms with log frequencies). Record attribution and the corpus IDs in `THIRD_PARTY`/About.
- **Add informal register** so the model is not news-only. Options:
  - Tatoeba (CC BY 2.0 FR) text for training, if we accept its attribution terms.
  - Under GPLv3, OpenSubtitles-derived FrequencyWords (BY-SA 4.0 → GPLv3), limited to a frequency feature.
- **Spell dictionaries:** don't bundle them. Use the system `NSSpellChecker` as a cross-check (§3.1). If we ever need offline dictionaries: en (SCOWL) and ru (Lebedev) are permissive, es can be taken under GPLv3/MPL, de is GPL.
- **Evaluation set:** Tatoeba sentences plus held-out Leipzig sentences, re-typed through real layout tables (§2.5). The set must include the punctuation-key letters.

---

## 2. How existing switchers detect the wrong layout

### 2.1 xneur / gxneur (Linux/X11, C, GPL-2.0-or-later)

Source: [`AndrewCrewKuznetsov/xneur-devel` @ `5a96481` (2024-10-18)](https://github.com/AndrewCrewKuznetsov/xneur-devel/tree/5a964810103cf73783f8f8ebb2998be8a5b91eda). License header: "either version 2 of the License, or (at your option) any later version" ([detection.c](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c)) [V]. **Do not copy its code or data into typo without GPL compliance.** GPLv3 typo can take GPL-2.0-or-later code; MIT typo cannot. [I]

- **Keeps keycodes and re-renders the word in every layout.** The buffer holds keycodes, with `i18n_content[lang]` per layout. `check_lang` reads "the last word" in every enabled layout ([detection.c `check_lang`](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c#L365)) [V].
- **Cascade** ([detection.c L400–L425](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c#L400-L425)) [V]:
  1. **Per-language regex "dictionary"**. It holds user-learned words plus hand rules:
     - Russian single-letter words `(?i)^а$`, `(?i)^в$`, `(?i)^и$`, `(?i)^к$`, `(?i)^о$`, `(?i)^у$`, `(?i)^я$`, `(?i)^ну$` ([ru/dictionary](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/share/languages/ru/dictionary)).
     - English IP/MAC/URL patterns and `(?i)^http`, `^www` ([en/dictionary](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/share/languages/en/dictionary)).
  2. **Enchant/Aspell spell-check**, current layout first, then the others. Words of ≤1 symbol are skipped (`word_len / sym_len > 1`).
  3. Optional **misprint check**: the dictionary suggestion within Levenshtein < 3 wins.
  4. **"proto" = forbidden letter bigrams.** If the current-layout word contains any forbidden bigram and another layout's reading contains none, switch to that layout ([`get_proto_lang`](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/ai/detection.c#L193)). Data:
     - `ru/proto`: 203 entries, e.g. `аъ аы аь бй вй гй`.
     - `en/proto`: 69 entries, e.g. `bq cj cx dx fq`.
  5. **"proto3" = forbidden trigrams**: 19,141 for ru, 8,990 for en [M: line counts of the files in `share/languages/*/`].
- **Mid-word check.** `program_check_lang_last_syllable` re-runs detection while typing once the word reaches 3 characters ([program.c L1436](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/main/program.c#L1436)) [V].
- **Self-learning ("EducationMode").** When the user manually re-converts a word, it goes to a temp dictionary for the new language. If it happens again, the word is promoted to the permanent dictionary and removed from the other languages' dictionaries ([program.c `program_add_word_to_dict`](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/lib/main/program.c#L2776)) [V].
- **Operational safety valves** in the default config ([xneurrc](https://github.com/AndrewCrewKuznetsov/xneur-devel/blob/5a964810103cf73783f8f8ebb2998be8a5b91eda/xneur/etc/xneurrc)) [V]:
  - `ExcludeApp` list (VirtualBox, Wine, rdesktop, …).
  - `TroubleshootBackspace/LeftArrow/…/Switch/FullScreen` options that disable auto-switching after those keys.
  - Configurable `Delimeter`s.
  - Leading punctuation/digits are skipped with byte-wise `ispunct`/`isdigit`, which is fragile for UTF-8 [I].

### 2.2 Punto Switcher (Yandex, closed source)

- The official help says it "распознает бессмысленное сочетание букв и автоматически переключает раскладку на нужную" (recognises meaningless letter combinations) ([Yandex help — Автопереключение](https://yandex.ru/support/punto-win/features/autoswitch.html?lang=ru)) [V].
- Users can add rules and exceptions. It does not switch in password fields. In non-standard password fields it switches only if the input does not look like a password (digits, mixed case, punctuation) [V: same page].
- No algorithmic detail is published beyond this. Third-party blogs describe "impossible letter combinations" (e.g. Ь at word start); they are secondary and not relied on here.

### 2.3 Caramba Switcher (closed source)

- Its site claims: "Высокоточный алгоритм от автора Punto Switcher", "Работа Caramba Switcher основана на нейронных сетях", and that it learns while working ([caramba-switcher.com](https://caramba-switcher.com/)) [V: claims only].
- The Mac App Store listing describes a "high-precision algorithm" and "statistical methods" for abbreviations. It requires macOS 12+ and is free with a $6.99/yr subscription ([App Store](https://apps.apple.com/us/app/caramba-switcher-autocorrect/id1565826179?mt=12)) [V].
- No technical documentation exists. The App Store presence shows that *some* form of switcher is possible in the store, but we don't know how it gets keystrokes inside the sandbox [I]. This is irrelevant given ADR 0001.

### 2.4 Open-source macOS switchers (Swift, 2025–2026)

Found with GitHub search ("punto switcher macos", "wrong keyboard layout macos"). The most-starred Swift ones:

**RuSwitcher** (MIT, ~249★). Source: [`rashn/RuSwitcher` @ `52e60aa`](https://github.com/rashn/RuSwitcher/tree/52e60aabc8f8ad39a7d76eba4f764c2e413a475b); detector in [`AutoSwitch.swift`](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/AutoSwitch.swift) [V].

- **Detection uses the system `NSSpellChecker` only, with no bundled data.** Code comments claim "~0.1мс на проверку, 40+ языков".
- **Two-sided rule for ≥3 letters:** convert only if the converted word is valid in the target language AND the typed word is not valid in the source language.
- **1-letter words:** never converted.
- **2-letter words:** a curated `ShortWords` frequency list is used as a *positive* signal only. The comment says "NSSpellChecker на длине 2 принимает почти любой набор букв за «слово»".
- **Vetoes:** digits/URLs; all-caps (unless Caps Lock); camelCase; mixed Latin+Cyrillic in one token.
- **Punctuation keys** — the trailing set `, . ! ? ; : ) \` [ ]` is split off and kept literally. The comments explain why:
  - "'.', ',', ';', ':' в EN — клавиши букв ю/б/ж/Ж … неоднозначность «думаю» vs «дума.»" — the caller must check the full conversion against the dictionary.
  - Quotes are excluded because smart punctuation and dead keys (U.S. International) break them.
- **Other gotchas documented in its comments:**
  - The first `NSSpellChecker` call starts the AppleSpell XPC process ("сотни мс на main"), so it warms up at launch.
  - The macOS Hebrew dictionary "принимает любой набор букв".
  - `NSSpellChecker` tokenises, so "привет!" counts as valid.
- **macOS APIs:**
  - `CGEvent.tapCreate` at `.cghidEventTap`, or at `.cgSessionEventTap` in "remote desktop" mode because Screen Sharing injects events that a HID tap doesn't see.
  - `.listenOnly` tap except for Caps Lock.
  - Re-enables the tap on `.tapDisabledByTimeout` / `.tapDisabledByUserInput` ([KeyboardMonitor.swift L218, L689](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/KeyboardMonitor.swift#L218)).
  - `CGPreflightListenEventAccess` / `CGRequestListenEventAccess` plus `AXIsProcessTrusted`.
  - `UCKeyTranslate` with `LMGetKbdType()` ([DynamicKeyMapping.swift](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/DynamicKeyMapping.swift#L282)).
  - Re-types via `keyboardSetUnicodeString` ([TextConverter.swift L666](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/TextConverter.swift#L666)).
  - Checks `IsSecureEventInputEnabled()` and finds the secure-input holder via IORegistry `kCGSSessionSecureInputPID`.
  - Calls `TISEnableInputSource` **only if the source is disabled**, then `TISSelectInputSource`. Enabling an already-enabled third-party layout showed a security prompt on every switch (issue #19 per the comment) ([LayoutSwitcher.swift L77](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/LayoutSwitcher.swift#L77)).
  - Auto-conversion is off by default in terminals, IDEs and password managers.

**keyboop** (MIT, ~242★). Source: [`iffuno/keyboop` @ `2862cf1`](https://github.com/iffuno/keyboop/tree/2862cf12cc4db3c52ff9e827b20c8f5c743dc2af) [V].

- **Cascade:** "guard'ы → force-swap → словарь → триграммная плаузивность (margin)" ([LayoutDetector.swift](https://github.com/iffuno/keyboop/blob/2862cf12cc4db3c52ff9e827b20c8f5c743dc2af/Sources/Keyboop/LayoutDetector.swift)).
- **Plausibility score:** the mean trigram log-probability over `" " + word + " "`, with −20 for unseen trigrams ([LayoutData.swift L24](https://github.com/iffuno/keyboop/blob/2862cf12cc4db3c52ff9e827b20c8f5c743dc2af/Sources/Keyboop/LayoutData.swift#L24)). `margin = 2.0`; the short-English floor is −10.
- **Documented findings in code comments:**
  - "ВСЕ промахи детектора — слова 2–3 буквы (28.6% / 5.7%)". They are dictionary collisions such as `yt↔не`, `in↔шт`, `th↔ер`.
  - Their fix is a **previous-word script prior** (`ContextHint`).
- **Other rules:**
  - An abbreviation force-swap list (`http`, `json`, `gpu`, …).
  - De-elongation (`круууто`).
  - A trailing-punctuation guard: `it.` must not become `шею`.

**SwitchFix** (README says MIT, ~26★). Source: [`rundax/SwitchFix` @ `d31f7b6`](https://github.com/rundax/SwitchFix/tree/d31f7b6b2030d77a19312ba7e6dda2592bb8cabb) [V].

- Word-list dictionaries (`en_US.txt` 48k, `ru_RU.txt` 146k, `uk_UA.txt` 2.96M lines [M]).
- Bloom filter plus a memory-mapped binary dictionary.
- Damerau-Levenshtein suggestions.
- Vowel sets per language, and `consecutiveThreshold` (default 1) before correcting ([LayoutDetector.swift](https://github.com/rundax/SwitchFix/blob/d31f7b6b2030d77a19312ba7e6dda2592bb8cabb/Sources/Core/LayoutDetector.swift)).

### 2.5 Cross-cutting gotchas, verified locally with UCKeyTranslate [M]

Layout tables were dumped via `TISCreateInputSourceList` + `kTISPropertyUnicodeKeyLayoutData` + `UCKeyTranslate(…, LMGetKbdType(), kUCKeyTranslateNoDeadKeysMask …)` ([UCKeyTranslate docs](https://developer.apple.com/documentation/coreservices/1390584-uckeytranslate)). Apple notes that the mapping "may also depend on … the type of physical keyboard being used" [V].

- **Apple "Russian" ≠ "Russian – PC".**
  - `ё` is on virtual keycode 42 (`\`) in *Russian* but on keycode 10 in *Russian – PC*.
  - *Russian* puts `,` and `.` on Shift+6 and Shift+7; *Russian – PC* puts `.`/`,` on keycode 44 (`/`).
  - Hard-coded ЙЦУКЕН tables are therefore wrong for some users. Derive every table from the enabled layouts and invalidate on input-source-change notifications.
- **Letters on punctuation keys.** The table shows unshifted output per virtual keycode. The column header is the U.S. character on that key.

  | Layout (TIS ID) | `,` (43) | `.` (47) | `;` (41) | `'` (39) | `[` (33) | `]` (30) | `\` (42) | `/` (44) | `-` (27) | kc 10 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | Russian (`com.apple.keylayout.Russian`) | б | ю | ж | э | х | ъ | **ё** | / | - | > |
  | Russian – PC (`com.apple.keylayout.RussianWin`) | б | ю | ж | э | х | ъ | \ | **.** | - | **ё** |
  | German (`com.apple.keylayout.German`) | , | . | ö | ä | ü | + | # | - | ß | ^ |
  | Spanish (`com.apple.keylayout.Spanish`) | , | . | ñ | ; | ´ | ` | ' | ç | - | [ |

  Keycodes 10 and 50 depend on the physical keyboard type (ISO vs ANSI); this dump used `LMGetKbdType()` of the test Mac.

- **Scale:** 30.4% of Russian word types in an 8,000-word frequency sample (23.8% of Russian tokens) contain one of `б ю ж э х ъ ё` [M, computed on FrequencyWords `ru_50k`]. Typed on U.S., these produce `,` `.` `;` `'` `[` `]` or the `ё` key's character.
- **German U.S.↔QWERTZ swaps y/z**, so Latin↔Latin readings are often both plausible. CONTEXT.md already limits corrections to cross-script. §4.2 has data supporting that choice.

---

## 3. On-device AI options on macOS

### 3.1 Summary table

Latency is per word on an M1 Pro, macOS 26.5.2 [M] unless marked otherwise.

| API | What it does | OS | Latency (warm) | Language coverage for EN/RU/DE/ES | Fit for a ~10 ms per-word budget |
|---|---|---|---|---|---|
| `NSSpellChecker.checkSpelling(of:startingAt:language:wrap:inSpellDocumentWithTag:wordCount:)` ([docs](https://developer.apple.com/documentation/appkit/nsspellchecker/checkspelling(of:startingat:language:wrap:inspelldocumentwithtag:wordcount:))) | System spell check; returns the range of the first misspelled word | macOS (all supported) | **median 82–101 µs, p99 0.21–0.84 ms, max 3.1 ms** (n = 3,924, two runs). First call per language 1–10 ms in this CLI. RuSwitcher reports "hundreds of ms" cold in an app ([source](https://github.com/rashn/RuSwitcher/blob/52e60aabc8f8ad39a7d76eba4f764c2e413a475b/macos/Sources/RuSwitcher/AutoSwitch.swift)) | `availableLanguages` here: en (+regional), ru, de, es [M]. The list follows the user's preferred order ([docs](https://developer.apple.com/documentation/appkit/nsspellchecker/availablelanguages)) | **Yes**, as a cross-check. Warm it up at launch. Mind the quirks in §3.3. |
| `NLLanguageRecognizer` (`languageHypotheses(withMaximum:)`, `languageConstraints`, `languageHints`) ([docs](https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer)) | Language identification with probabilities; constraints restrict the output set; hints are prior probabilities | macOS 10.14+ | **median 107–117 µs, p99 ~0.2 ms, outliers 3–5 ms** (reset+process+hypotheses) | Script-driven. `ghbdtn` with constraints `[en, ru]` → `en = 1.00`; `привет` → `ru = 1.00`. Among Latin languages single words are weak: `ghbdtn` → en .45 / de .40 / es .15; `zes` → en .71 [M] | **Low value.** It cannot tell gibberish from a real word, and cross-script is trivial. Maybe a sentence-level prior. "Don't use an instance … from more than one thread simultaneously" ([docs](https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer)) |
| `NLEmbedding.wordEmbedding(for:)` ([docs](https://developer.apple.com/documentation/naturallanguage/nlembedding)) | Built-in word vectors; `contains()` doubles as a vocabulary check | macOS 10.15+ | Load 50–77 ms. `contains()` 1–20 µs, first lookups up to 0.7 ms | en (57,171 words, dim 300), de (49,315), es (42,337); **ru = nil** [M] | **No.** No Russian. A single instance "isn't safe for concurrent use" ([docs](https://developer.apple.com/documentation/naturallanguage/nlembedding)) |
| `NLModel` + Create ML `MLTextClassifier` ([NLModel](https://developer.apple.com/documentation/naturallanguage/nlmodel), [algorithms](https://developer.apple.com/documentation/createml/mltextclassifier/modelalgorithmtype)) | Custom text classifier (maxEnt, CRF, transfer learning with static/dynamic/BERT/ELMo embeddings) | Inference macOS 10.14+; training on a Mac | **33–39 µs** per `predictedLabel` | Whatever you train | **Yes, only with character features.** Toy task (EN words vs RU-typed-on-US, 20k each, held out by word): maxEnt on raw words = **49.9%** (chance); on space-separated characters = **97.1%** [M]. The default word tokeniser can't generalise to unseen words. |
| Core ML custom model (e.g. PyTorch/MIL → coremltools) | Any small NN; choose compute units | macOS 14+ as built here (`mlprogram`) | Tiny MLP (4096→64→4, 262k params, fp16): **CPU median 53 µs, p99 88 µs**; **ANE 270–278 µs**; **GPU 404 µs** (first GPU call 539 ms); load 40–74 ms [M] | Whatever you train | **Yes on CPU** (`computeUnits = .cpuOnly`). ANE/GPU dispatch overhead outweighs the compute for tiny models [M]. |
| Foundation Models (`SystemLanguageModel`, `LanguageModelSession`, `@Generable`) ([framework](https://developer.apple.com/documentation/foundationmodels)) | ~3B-parameter on-device LLM, 2-bit ([WWDC25 286](https://developer.apple.com/videos/play/wwdc2025/286/), [Apple ML 2025](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)); guided generation via constrained decoding | **macOS 26+**; Apple Intelligence enabled; Mac with M1 or later; device and Siri language set to the same supported language; not on China-mainland devices/accounts ([Apple support 121115](https://support.apple.com/en-us/121115)) | **Unmeasured** (on the test Mac `availability = unavailable(appleIntelligenceNotEnabled)` [M]). Apple's only published figure is "time-to-first-token latency of about 0.6 millisecond per prompt token, and a generation rate of 30 tokens per second" on iPhone 15 Pro, for the 2024 model ([Apple ML 2024](https://machinelearning.apple.com/research/introducing-apple-foundation-models)) [V]. "Each token in your instructions and prompt adds extra latency" ([WWDC25 301](https://developer.apple.com/videos/play/wwdc2025/301/)) [V] | `supportedLanguages` on 26.5.2 includes de, en, es … but **not ru** [M]. The Apple support list has no Russian [V]. Unsupported input throws `unsupportedLanguageOrLocale` ([docs](https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models)) [V]. `contextSize` = 4,096 [M/V] | **No** for the per-word path. A ~50–100-token prompt plus a few output tokens is roughly 30–200 ms by Apple's iPhone numbers [I]. One request per session at a time ([docs](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)) [V]. `prewarm` wants "a window of at least 1 second" ([docs](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:))) [V]. Russian, the main language pair, is unsupported. |
| MLX / MLX Swift ([repo](https://github.com/ml-explore/mlx-swift)) | Array/NN framework for Apple silicon; LLMs via `mlx-swift-lm` | "MLX is only available on devices running macOS >= 14.0" on Apple silicon ([install docs](https://ml-explore.github.io/mlx/build/html/install.html)); MIT | Unmeasured | Whatever you train or download | **Not needed.** Adds a large dependency and excludes Intel Macs; Core ML on CPU already meets the budget [I]. |

### 3.2 Detection-quality experiment [M]

**Method.**
- Test words came from FrequencyWords 50k lists (odd ranks, first 8,000 per language). Only words whose re-typed form is all letters were kept. **This excluded the punctuation-key letters**, i.e. ~30% of Russian words (§2.5).
- Each word was re-typed through real UCKeyTranslate tables: U.S., Russian – PC, German, Spanish.
- "Positives" are words of language T typed on the wrong layout; "negatives" are correctly typed words of language S. Recall is the share of positives converted; FP is the share of negatives converted.
- The trigram model was trained on the *even* ranks, weighted by log frequency, with a mean log-probability per trigram and word-boundary padding.
- Rules compared:
  - *spell*: `spell(conv,T) && !spell(typed,S)`, as RuSwitcher does.
  - *tri*: margin `score_T(conv) − score_S(typed) > 2`.
  - *hybrid*: `!spell(typed,S) && ((spell(conv,T) && margin > 0) || margin > 4)`.
- There is no sentence context. The thresholds were not tuned on a separate set, so the numbers are indicative only.

| Scenario | Rule | Recall 2 / 3 / 4–5 / 6+ letters | FP 2 / 3 / 4–5 / 6+ letters | Token-weighted recall / FP |
|---|---|---|---|---|
| RU words typed on U.S. (neg: EN words) | spell | 46.6 / 77.2 / 87.7 / 95.7% | 10.1 / 1.3 / 0 / 0% | 87.2% / 0.02% |
| | tri | 60.3 / 79.2 / 91.0 / 99.1% | 12.8 / 0.8 / 0 / 0% | 82.2% / 8.35% |
| | hybrid | 46.6 / 80.7 / 94.1 / 98.8% | 6.4 / 0.3 / 0 / 0% | 82.3% / 0.01% |
| EN words typed on RU (neg: RU words) | spell | 52.3 / 75.3 / 83.0 / 88.3% | 17.2 / 3.0 / 0 / 0% | 85.7% / 0.04% |
| | tri | 60.6 / 84.7 / 97.3 / 99.4% | 5.2 / 2.0 / 0.15 / 0% | 80.6% / 3.46% |
| | hybrid | 65.1 / 83.7 / 95.6 / 98.5% | 6.9 / 1.5 / 0 / 0% | 87.7% / 0.03% |
| DE words typed on RU (neg: RU words) | spell / tri / hybrid (6+) | 59.2 / 99.4 / 94.2% | 0 / 0 / 0% | 85.6 / 97.4 / 94.0% recall |
| ES words typed on RU (neg: RU words) | spell / tri / hybrid (6+) | 90.2 / 99.6 / 97.6% | 0 / 0 / 0% | 86.0 / 87.7 / 87.8% recall |
| DE words typed on U.S. (Latin↔Latin, only words that differ) | spell / tri / hybrid (4–5) | 24.1 / 20.5 / 17.9% | 0 / 0 / 0% | low; trigram margins barely move for one y/z swap |

**Takeaways** [I]:
- A trigram margin alone is excellent for long words and dangerous for 1–2-letter words: its token-weighted FP is 3–8% because short words dominate running text.
- The spell rule has the lowest FP but loses recall on German. `NSSpellChecker` rejects lowercased nouns, see §3.3.
- Combining both gives near-zero FP at ≥3 letters. Everything left is in 2-letter and some 3-letter words, which matches keyboop's finding and typo's "Short word" rule in CONTEXT.md.

### 3.3 NSSpellChecker quirks that matter for detection [M] unless noted

- **Short strings.** Share of *random* letter strings accepted:

  | Length | en | de | es | ru |
  |---|---|---|---|---|
  | 2 letters | 221/676 (33%) | 177/676 | 206/676 | 214/1,024 (21%) |
  | 3 letters | 1,595/17,576 (9.1%) | — | — | 1,718/32,768 (5.2%) |

  Never trust it alone below 4 letters.
- **Trailing punctuation passes.** `привет!`, `привет,` and `дума.` are all accepted, so strip punctuation before checking. For RU, test both readings of `, . ; '`.
- **German case.** Of 3,000 frequent ≥4-letter German words in lowercase, 855 were rejected: `frau gott leute vater geld mutter …`. Some lowercase nouns pass anyway (`zeit`, `haus`). Check the original case and a Capitalised variant.
- **Proper names in lowercase are rejected** in every language: `berlin`, `москва`, `michael`, `джон`.
- **User dictionary.** Words the user has "learned" are accepted. The API exposes `learnWord(_:)`/`hasLearnedWord(_:)` ([topics](https://developer.apple.com/documentation/appkit/nsspellchecker)) [V]. Results can therefore differ per user.
- **Threading.**
  - Apple's docs don't state thread-safety. The archived [Thread Safety Summary](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html) doesn't list `NSSpellChecker` [V].
  - In the macOS 26 SDK it is **not** `@MainActor`: a nonisolated call compiles clean in Swift 6 mode, while `NSWindow()` warns [M].
  - A background-queue call returned correctly [M].
  - The header says "There is only one NSSpellChecker instance per application" [V: `NSSpellChecker.h`].
  - [I] Call it from **one** serial queue, never concurrently.
  - The async `requestChecking(…)` completion handler is "called (in an arbitrary context)" ([docs](https://developer.apple.com/documentation/appkit/nsspellchecker/requestchecking(of:range:types:options:inspelldocumentwithtag:completionhandler:))) [V].

---

## 4. Recommended hybrid architecture [I]

```
CGEventTap callback (listen-only, returns immediately)
  └─ append keycode+modifiers to the Word (keys, not chars)          ~0 µs
word boundary ──► detection queue (serial, userInitiated)
  1. Gates: excluded app / secure input / pause / exception list /
     Skipped-word rules (digit, @ / _, camelCase, mixed script)       ~1 µs
  2. Re-read the Word under every enabled layout of another script
     (cached UCKeyTranslate tables per (layout, LMGetKbdType))         ~1 µs
  3. Features per (typed reading S, candidate reading T):
       a. char n-gram margin  m = LM_T(cand) − LM_S(typed)              ~2–5 µs
       b. lexicon log-freq of cand in T and of typed in S (bundled)     <1 µs
       c. NSSpellChecker(typed,S), NSSpellChecker(cand,T), with
          punctuation stripped + case variants (DE)                    ~0.1–0.4 ms
       d. length, # punctuation-key letters used, previous-word
          direction (Short-word rule), user exceptions
  4. Combiner: logistic regression (or Create ML maxEnt/boosted tree
     → Core ML on CPU)                                                 ~0.05 ms
  5. p ≥ τ_high → Correction;  τ_low ≤ p < τ_high → ambiguous:
     keep, re-score jointly when the next word ends; else keep
```

- **Budget.** The whole hot path is ≈0.2–0.6 ms typical and < 2 ms p99 by the measurements above. That leaves most of the 10 ms budget for retyping. Keep all work out of the tap callback: Apple defines `tapDisabledByTimeout` ([docs](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)) but publishes no numeric timeout, and RuSwitcher re-enables the tap when it fires.
- **Language model as data.** Ship one file per supported language with the n-gram table, the lexicon and a meta/attribution block. Build them offline from Leipzig (CC BY) plus optional informal-register data. This fits CONTEXT.md's "Language model … added as data, not code".
- **Thresholds.** Pick τ_high so the token-weighted FP rate is ≤ 1 per 10,000 words on the evaluation set, then maximise recall. Start with 3+ letters only. Use the curated Short-word path plus previous-word context for 2 letters, as CONTEXT.md already prescribes.
- **Escalation.** No LLM in v1. If ever used:
  - Foundation Models only for EN/DE/ES pairs (not RU), on macOS 26+ with `availability == .available`.
  - Asynchronous and never blocking. Examples: a user-initiated "fix this phrase", or offline re-scoring of an ambiguous word once the sentence ends.
  - This stays consistent with ADR 0003 because the model is on-device. Private Cloud Compute would need a new ADR.
- **What to measure** (locally only, per ADR 0003 — no telemetry):
  1. Latency p50/p99/max per stage, measured inside the app, not a CLI. Include the cold first call after launch and after sleep/wake.
  2. Token-weighted FP and recall per layout pair (en-ru, de-ru, es-ru) and per length bucket. The eval text must include punctuation-key letters and capitalised/proper nouns.
  3. Recall on words containing `б ю ж э х ъ ё`, measured separately.
  4. Memory and disk of each language model, and model load time.
  5. Revert rate during dogfooding, counted in memory and shown to the developer in a debug window only.

---

## 5. Open questions

1. **License posture.** The brief says MIT; ADR 0002 says GPLv3. If GPLv3, is it "v3 only" or "v3 or later"? BY-SA-derived data can go to GPLv3 but not to "or later" ([FSF](https://www.gnu.org/licenses/license-list.en.html#ccbysa)).
2. **Leipzig's CC BY version.** The Terms of Usage page does not state 3.0 or 4.0 ([usage](https://wortschatz.uni-leipzig.de/en/usage)). Its Wikipedia-sourced corpora may still carry upstream BY-SA. Prefer the news and web corpora, or ask Leipzig in writing.
3. **Foundation Models latency** on an M-series Mac with Apple Intelligence enabled is unmeasured, and so is the accuracy of a `@Generable` enum classifier on single words. Worth one spike only if an EN/DE/ES escalation path is ever wanted.
4. **Russian `ё` handling.** Should the model fold `ё`→`е` (the subtitle data is inconsistent), and how does that interact with `ё` living on different keys in Russian vs Russian – PC?
5. **NSSpellChecker thread-safety and cold start** inside a real menu-bar app (not a CLI). RuSwitcher saw hundreds of ms cold; we saw ≤10 ms.
6. **Are there permissively licensed informal-register (chat-like) RU/DE/ES corpora** beyond Tatoeba?

---

## Sources

Data and licenses
- FrequencyWords: https://github.com/hermitdave/FrequencyWords · file listing https://api.github.com/repos/hermitdave/FrequencyWords/contents/content/2018/ru
- OPUS OpenSubtitles v2018: https://opus.nlpl.eu/legacy/OpenSubtitles-v2018.php
- wordfreq README and SUNSET: https://github.com/rspeer/wordfreq · https://github.com/rspeer/wordfreq/blob/master/SUNSET.md
- Leipzig Terms of Usage: https://wortschatz.uni-leipzig.de/en/usage · downloads https://wortschatz.uni-leipzig.de/en/download
- LibreOffice dictionaries: https://github.com/LibreOffice/dictionaries (`en/README_en_US.txt`, `ru_RU/README_ru_RU.txt`, `de/README_de_DE_frami.txt`, `de/COPYING_OASIS.txt`, `es/LICENSE.md`)
- Hunspell license: https://github.com/hunspell/hunspell/blob/master/license.hunspell
- Google Books Ngram datasets v3: https://storage.googleapis.com/books/ngrams/books/datasetsv3.html
- Wiktionary copyrights: https://en.wiktionary.org/wiki/Wiktionary:Copyrights · Russian frequency lists https://en.wiktionary.org/wiki/Wiktionary:Frequency_lists/Russian
- Tatoeba downloads: https://tatoeba.org/en/downloads
- CC BY-SA 4.0 legal code: https://creativecommons.org/licenses/by-sa/4.0/legalcode.en
- CC compatible licenses: https://creativecommons.org/share-your-work/licensing-considerations/compatible-licenses/
- FSF license list: https://www.gnu.org/licenses/license-list.en.html · GPL FAQ https://www.gnu.org/licenses/gpl-faq.en.html#MereAggregation

Existing switchers
- xneur @ 5a96481: https://github.com/AndrewCrewKuznetsov/xneur-devel/tree/5a964810103cf73783f8f8ebb2998be8a5b91eda
- Punto Switcher help (auto-switch): https://yandex.ru/support/punto-win/features/autoswitch.html?lang=ru
- Caramba Switcher: https://caramba-switcher.com/ · App Store https://apps.apple.com/us/app/caramba-switcher-autocorrect/id1565826179?mt=12
- RuSwitcher @ 52e60aa: https://github.com/rashn/RuSwitcher/tree/52e60aabc8f8ad39a7d76eba4f764c2e413a475b
- keyboop @ 2862cf1: https://github.com/iffuno/keyboop/tree/2862cf12cc4db3c52ff9e827b20c8f5c743dc2af
- keyswitcher @ 0a51fc2: https://github.com/graninilya/keyswitcher
- SwitchFix @ d31f7b6: https://github.com/rundax/SwitchFix/tree/d31f7b6b2030d77a19312ba7e6dda2592bb8cabb

Apple
- NSSpellChecker: https://developer.apple.com/documentation/appkit/nsspellchecker · checkSpelling https://developer.apple.com/documentation/appkit/nsspellchecker/checkspelling(of:startingat:language:wrap:inspelldocumentwithtag:wordcount:) · availableLanguages https://developer.apple.com/documentation/appkit/nsspellchecker/availablelanguages · requestChecking https://developer.apple.com/documentation/appkit/nsspellchecker/requestchecking(of:range:types:options:inspelldocumentwithtag:completionhandler:)
- Thread Safety Summary (archive): https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Multithreading/ThreadSafetySummary/ThreadSafetySummary.html
- NLLanguageRecognizer: https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer · languageHints https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer/languagehints-7dwgv · languageConstraints https://developer.apple.com/documentation/naturallanguage/nllanguagerecognizer/languageconstraints
- NLEmbedding: https://developer.apple.com/documentation/naturallanguage/nlembedding · NLModel https://developer.apple.com/documentation/naturallanguage/nlmodel
- Create ML MLTextClassifier algorithms: https://developer.apple.com/documentation/createml/mltextclassifier/modelalgorithmtype · feature extractors https://developer.apple.com/documentation/createml/mltextclassifier/featureextractortype
- Foundation Models: https://developer.apple.com/documentation/foundationmodels · SystemLanguageModel https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel · contextSize https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize · languages https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models · generating content https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models · prewarm https://developer.apple.com/documentation/foundationmodels/languagemodelsession/prewarm(promptprefix:)
- WWDC25 286 “Meet the Foundation Models framework”: https://developer.apple.com/videos/play/wwdc2025/286/ · WWDC25 301 “Deep dive into the Foundation Models framework”: https://developer.apple.com/videos/play/wwdc2025/301/
- Apple ML Research: https://machinelearning.apple.com/research/introducing-apple-foundation-models · https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- Apple Intelligence requirements and languages: https://support.apple.com/en-us/121115
- CGEvent tapCreate: https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate(tap:place:options:eventsofinterest:callback:userinfo:) · tapDisabledByTimeout https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout · CGPreflightListenEventAccess https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess() · keyboardSetUnicodeString https://developer.apple.com/documentation/coregraphics/cgevent/keyboardsetunicodestring(stringlength:unicodestring:)
- UCKeyTranslate: https://developer.apple.com/documentation/coreservices/1390584-uckeytranslate · TISSelectInputSource: `TextInputSources.h` in the macOS SDK (HIToolbox)

MLX
- MLX Swift: https://github.com/ml-explore/mlx-swift · MLX install requirements https://ml-explore.github.io/mlx/build/html/install.html
