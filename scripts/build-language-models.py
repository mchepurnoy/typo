#!/usr/bin/env python3
"""Builds typo's language models from Leipzig Corpora Collection downloads.

Usage: scripts/build-language-models.py

Downloads the corpora listed in CORPORA into build/corpora/ (once), then writes one
LanguageModels/<code>.lm per supported language: character trigram log-probabilities
and a word-frequency lexicon. Standard library only. Output is deterministic for the
same corpora; the archives are checked against pinned SHA-256 hashes. See
LanguageModels/SOURCES.md for the format, sources and licence.
"""

import collections
import math
import re
import tarfile

from leipzig import ROOT, download

OUT_DIR = ROOT / "LanguageModels"

# language code -> (Leipzig corpus, its SHA-256, letters of the language after lowercasing and folding,
# punctuation allowed between letters)
CORPORA = {
    "en": ("eng_news_2024_1M", "8f1d4d07b9771f8a7fc219ad587d5382eabf5009ef563f1bc4c12a467a8e3a97",
           "abcdefghijklmnopqrstuvwxyz", "'-"),
    "ru": ("rus_news_2024_1M", "7df13a6ba25c47fde0e156c1ef670fce7a86b126ee9ff9d7246ba840ef964242",
           "абвгдежзийклмнопрстуфхцчшщъыьэюя", "-"),
    "de": ("deu_news_2024_1M", "203d98de187f6d87e7f97c1f516a64a9d19016d0dc81c935a72e769ef184fa64",
           "abcdefghijklmnopqrstuvwxyzäöüß", "-"),
    "es": ("spa_news_2024_1M", "4666b54caad54cd46cdfea80e7cb727663b220c2ead871b4ccf6285df0599090",
           "abcdefghijklmnopqrstuvwxyzáéíóúüñ", "-"),
}

FORMAT_VERSION = 1
LEXICON_SIZE = 60_000  # most frequent word forms kept per language
MIN_WORD_COUNT = 3  # rarer forms are mostly typos and noise; ignored for lexicon and trigrams
BOUNDARY = " "  # pads words so trigrams see the start and end
MIN_TRIGRAM_WEIGHT = 2.0  # drop trigrams seen only in a couple of rare words
UNSEEN_PENALTY = 2.0  # unseen trigrams score this much below the rarest stored one


def normalize(word: str) -> str:
    """Same as LanguageModel.normalize in the Engine: lowercase, ё → е, ’ → '."""
    return word.lower().replace("ё", "е").replace("’", "'")


def word_counts(tarball, corpus: str, letters: str, inner: str) -> collections.Counter:
    """Counts of normalised word forms: the language's letters, with `inner` punctuation only
    between letters (`don't`, `из-за`)."""
    letter = f"[{re.escape(letters)}]"
    word_pattern = re.compile(f"^{letter}+(?:[{re.escape(inner)}]{letter}+)*$")
    counts = collections.Counter()
    with tarfile.open(tarball, "r:gz") as tar:
        member = tar.getmember(f"{corpus}/{corpus}-words.txt")
        with tar.extractfile(member) as f:
            for raw in f:
                fields = raw.decode("utf-8").rstrip("\n").split("\t")
                if len(fields) != 3:
                    continue
                word = normalize(fields[1])
                if word_pattern.match(word):
                    counts[word] += int(fields[2])
    return counts


def trigram_log_probs(counts: collections.Counter) -> dict:
    """log P(c3 | c1 c2) over padded word types, each type weighted by log(1 + count)."""
    trigrams = collections.Counter()
    for word, count in counts.items():
        if count < MIN_WORD_COUNT:
            continue
        weight = math.log1p(count)
        padded = BOUNDARY + word + BOUNDARY
        for i in range(len(padded) - 2):
            trigrams[padded[i : i + 3]] += weight
    trigrams = {t: w for t, w in trigrams.items() if w >= MIN_TRIGRAM_WEIGHT}
    contexts = collections.Counter()
    for trigram, weight in trigrams.items():
        contexts[trigram[:2]] += weight
    return {t: math.log(w / contexts[t[:2]]) for t, w in trigrams.items()}


def build(code: str, corpus: str, sha256: str, letters: str, inner: str) -> dict:
    tarball = download(corpus, sha256)
    counts = word_counts(tarball, corpus, letters, inner)
    total = sum(counts.values())
    lexicon = sorted(
        ((w, c) for w, c in counts.items() if c >= MIN_WORD_COUNT),
        key=lambda wc: (-wc[1], wc[0]),
    )[:LEXICON_SIZE]
    trigrams = trigram_log_probs(counts)
    unseen = min(trigrams.values()) - UNSEEN_PENALTY

    lines = [
        f"typo-language-model\t{FORMAT_VERSION}",
        f"language\t{code}",
        f"source\t{corpus}",
        f"unseen\t{unseen:.3f}",
        f"trigrams\t{len(trigrams)}",
    ]
    lines += [f"{t}\t{lp:.3f}" for t, lp in sorted(trigrams.items())]
    lines.append(f"lexicon\t{len(lexicon)}")
    # Zipf frequency: log10 of occurrences per billion words
    lines += [f"{w}\t{math.log10(c / total * 1e9):.2f}" for w, c in lexicon]
    path = OUT_DIR / f"{code}.lm"
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return {
        "code": code,
        "corpus": corpus,
        "tokens": total,
        "trigrams": len(trigrams),
        "lexicon": len(lexicon),
        "bytes": path.stat().st_size,
    }


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    for code, (corpus, sha256, letters, inner) in CORPORA.items():
        info = build(code, corpus, sha256, letters, inner)
        print(
            f"{info['code']}: {info['corpus']} tokens={info['tokens']} "
            f"trigrams={info['trigrams']} lexicon={info['lexicon']} -> {info['bytes'] / 1e6:.2f} MB"
        )


if __name__ == "__main__":
    main()
