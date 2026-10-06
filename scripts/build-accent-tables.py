#!/usr/bin/env python3
"""Builds the accent tables: words typed without ё, umlauts or accents, and how to restore them.

Usage: scripts/build-accent-tables.py

Writes LanguageModels/<code>.accents for ru, de, es:

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
- German, Spanish: from the 2024 Leipzig news corpora (CC BY), which write umlauts and accents
  consistently. A word is restored only if its plain form is all but absent there (at most 1% as
  often), so pairs that are both words (schon/schön, esta/está, como/cómo) are left out. Words
  with ß are left out too: "ss" for ß is correct in Switzerland.
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
}
PLAIN_SHARE = 0.01  # the plain form may be at most this often as the marked one
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


def strip(word: str) -> str:
    return "".join(ch for ch in unicodedata.normalize("NFD", word) if unicodedata.category(ch) != "Mn")


def word_counts(corpus: str, sha256: str, letters: str) -> collections.Counter:
    """Lowercased word counts of a Leipzig corpus, words of the given letters only."""
    token = re.compile(f"^[{letters}]+$")
    counts = collections.Counter()
    with tarfile.open(download(corpus, sha256), "r:gz") as tar:
        with tar.extractfile(f"{corpus}/{corpus}-words.txt") as f:
            for raw in f:
                fields = raw.decode("utf-8").rstrip("\n").split("\t")
                if len(fields) == 3 and token.match(fields[1]):
                    counts[fields[1].lower()] += int(fields[2])
    return counts


def from_corpus(code: str) -> None:
    corpus, sha256, letters = LEIPZIG[code]
    counts = word_counts(corpus, sha256, letters)
    rows = {}
    for word, count in counts.items():
        plain = strip(word)
        if plain == word or "ß" in word or count < MIN_COUNT:
            continue
        if counts[plain] <= PLAIN_SHARE * count:
            # Several marked forms with one plain form: keep the most frequent
            if plain not in rows or counts[rows[plain][0]] < count:
                rows[plain] = (word, "a")
    write(code, f"{corpus} (CC BY)", rows)


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    russian()
    for code in LEIPZIG:
        from_corpus(code)


if __name__ == "__main__":
    main()
