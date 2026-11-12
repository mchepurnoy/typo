#!/usr/bin/env python3
"""Builds the accent tables: words typed without ё, umlauts or accents, and how to restore them.

Usage: scripts/build-accent-tables.py

Writes LanguageModels/<code>.accents for ru, de, es, fr:

    typo-accents<TAB>1
    language<TAB>ru
    source<TAB>...
    words<TAB>N
    еще<TAB>ещё<TAB>a      plain form (lowercase) <TAB> restored form <TAB> case rule

Case rule: a = restore whatever the case, l = only when typed lowercase (the capitalised plain
form is another word: "Киев" stays, "киев" → "киёв"), c = only when typed capitalised (names).

- Russian: the "safe" list of eyo-kernel (MIT), whose words certainly take ё; ambiguous ones
  (все/всё, осел/осёл) are in its "not safe" list and are left out. Pinned by commit and SHA-256.
  Only forms that occur in the 2024 Russian news corpus are kept (8.6k of 107k, all of the
  corpus's uses of ё-words), so the table stays small.
- German, Spanish, French: from the 2024 Leipzig news corpora (CC BY), which write umlauts and
  accents consistently. A word is restored only if its plain form is all but absent there (at most
  1% as often), so pairs that are both words (schon/schön, esta/está, a/à, ou/où) are left out.
  Words with ß are left out too: "ss" for ß is correct in Switzerland.
- French œ and æ are letters, not accent marks: the plain form spells them oe and ae. News text
  types "coeur" for "cœur" far more often than it leaves out an accent (13%, "soeur" 14%), so a
  word whose only difference is the ligature is restored if its plain form is at most half as
  often; names and Latin, where "ae" is the usual spelling (Laetitia, ex aequo), stay out.
- French writes capitals without their accents ("Ecole", "Etat"), so its plain forms are counted
  where they are written in lowercase only: a capitalised plain form is no sign of another word.
  Where the corpus writes the capitalised plain form that often, it is correct French (or a name:
  "Soignes", "Sidibe"), so the word is restored only when typed in lowercase (rule l).
- French verb forms often differ by one accent (présente/présenté, protège/protégé), so a French
  plain form is left out when its second most frequent marked form is more than 5% as often as
  the first (on 2023 news: 15 wrong restorations instead of 493, for 7% fewer right ones).
  German and Spanish would gain from it too (publicó/público), but their tables are kept as
  published.
"""

import collections
import hashlib
import re
import subprocess
import sys
import tarfile
import unicodedata

from leipzig import CORPORA_DIR, ROOT, download

OUT_DIR = ROOT / "LanguageModels"

EYO_COMMIT = "95577dfb33127956d1f5bd70d898e2af0df8cd97"
EYO_URL = f"https://raw.githubusercontent.com/hcodes/eyo-kernel/{EYO_COMMIT}/dictionary/safe.txt"
EYO_SHA256 = "11fc6d9c3cc6d0fff6a21cd642fa6aecbf3f9eb784f84ccd78141f32e51e0693"

RUSSIAN_CORPUS = ("rus_news_2024_1M", "7df13a6ba25c47fde0e156c1ef670fce7a86b126ee9ff9d7246ba840ef964242", "а-яА-ЯёЁ")
LEIPZIG = {
    "de": ("deu_news_2024_1M", "203d98de187f6d87e7f97c1f516a64a9d19016d0dc81c935a72e769ef184fa64", "a-zA-ZäöüÄÖÜß"),
    "es": ("spa_news_2024_1M", "4666b54caad54cd46cdfea80e7cb727663b220c2ead871b4ccf6285df0599090",
           "a-zA-ZáéíóúüñÁÉÍÓÚÜÑ"),
    "fr": ("fra_news_2024_1M", "907eed297ab7b5fbe0ea87105084899158f660890e87f121b2a24eb9853a6467",
           "a-zA-ZàâæçéèêëîïôœùûüÿÀÂÆÇÉÈÊËÎÏÔŒÙÛÜŸ"),
}
PLAIN_SHARE = 0.01  # the plain form may be at most this often as the marked one
LIGATURE_PLAIN_SHARE = 0.5  # the same, for a word that differs from its plain form only by œ or æ
UNACCENTED_CAPITALS = {"fr"}  # languages whose plain forms are counted in lowercase occurrences only
OTHER_FORM_SHARE = {"fr": 0.05}  # a second marked form of the same plain form may be at most this often
MIN_COUNT = 3  # marked forms seen fewer times are left out


def write(code: str, source: str, rows: dict) -> None:
    lines = [
        "typo-accents\t1", f"language\t{code}", f"source\t{source}", f"words\t{len(rows)}",
    ] + [f"{plain}\t{restored}\t{rule}" for plain, (restored, rule) in sorted(rows.items())]
    path = OUT_DIR / f"{code}.accents"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{code}: {len(rows)} words -> {path.relative_to(ROOT)} ({path.stat().st_size / 1e6:.2f} MB)")


def russian() -> None:
    path = CORPORA_DIR / "eyo-safe.txt"
    if not path.exists():
        CORPORA_DIR.mkdir(parents=True, exist_ok=True)
        subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--output", path, EYO_URL], check=True)
    if hashlib.sha256(path.read_bytes()).hexdigest() != EYO_SHA256:
        sys.exit(f"{path}: SHA-256 does not match the pinned eyo-kernel commit; delete it to download again")

    seen = {word.replace("ё", "е") for word in word_counts(*RUSSIAN_CORPUS)}
    rows = {}
    pattern = re.compile(r"^(_?)([А-ЯЁа-яё-]+)(?:\(([^()]*)\))?$")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        match = pattern.match(line)
        if not match:
            continue
        lowercase_only, stem, endings = match.groups()
        rule = "l" if lowercase_only else "c" if stem[0].isupper() else "a"
        for ending in (endings.split("|") if endings is not None else [""]):
            restored = (stem + ending).lower()
            plain = restored.replace("ё", "е")
            if plain != restored and plain in seen:
                rows[plain] = (restored, rule)
    write("ru", f"eyo-kernel {EYO_COMMIT[:7]} dictionary/safe.txt (MIT), forms in {RUSSIAN_CORPUS[0]}", rows)


def strip_marks(word: str) -> str:
    return "".join(ch for ch in unicodedata.normalize("NFD", word) if unicodedata.category(ch) != "Mn")


def strip(word: str) -> str:
    """The word as typed without accents, umlauts or ligatures: "cœur" → "coeur"."""
    return strip_marks(word).replace("œ", "oe").replace("æ", "ae")


def word_counts(corpus: str, sha256: str, letters: str, lowercase_only: bool = False) -> collections.Counter:
    """Lowercased word counts of a Leipzig corpus, words of the given letters only; with
    `lowercase_only`, only the occurrences written in lowercase."""
    token = re.compile(f"^[{letters}]+$")
    counts = collections.Counter()
    with tarfile.open(download(corpus, sha256), "r:gz") as tar:
        with tar.extractfile(f"{corpus}/{corpus}-words.txt") as f:
            for raw in f:
                fields = raw.decode("utf-8").rstrip("\n").split("\t")
                if len(fields) == 3 and token.match(fields[1]) and (not lowercase_only or fields[1].islower()):
                    counts[fields[1].lower()] += int(fields[2])
    return counts


def from_corpus(code: str) -> None:
    corpus, sha256, letters = LEIPZIG[code]
    counts = word_counts(corpus, sha256, letters)
    plain_counts = word_counts(corpus, sha256, letters, lowercase_only=True) if code in UNACCENTED_CAPITALS else counts
    rows = {}
    marked = collections.defaultdict(list)  # plain form -> counts of its marked forms
    for word, count in counts.items():
        plain = strip(word)
        if plain == word or "ß" in word or count < MIN_COUNT:
            continue
        marked[plain].append(count)
        share = LIGATURE_PLAIN_SHARE if strip_marks(word) == word else PLAIN_SHARE
        if plain_counts[plain] <= share * count:
            # Several marked forms with one plain form: keep the most frequent
            if plain not in rows or counts[rows[plain][0]] < count:
                rule = "l" if counts[plain] > share * count else "a"
                rows[plain] = (word, rule)
    if code in OTHER_FORM_SHARE:
        for plain in list(rows):
            second = sorted(marked[plain], reverse=True)[1:2]
            if second and second[0] > OTHER_FORM_SHARE[code] * counts[rows[plain][0]]:
                del rows[plain]
    write(code, f"{corpus} (CC BY)", rows)


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    russian()
    for code in LEIPZIG:
        from_corpus(code)


if __name__ == "__main__":
    main()
