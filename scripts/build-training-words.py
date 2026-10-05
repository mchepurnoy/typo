#!/usr/bin/env python3
"""Extracts training words for the detector model (post-MVP 04) from the 2024 Leipzig corpora.

Usage: scripts/build-training-words.py

Writes build/training/<code>.txt: "word<TAB>count" for the most frequent word forms (as written,
letters only) of each language. The accuracy test uses the 2023 corpora, so this stays held apart.
"""

import collections
import re
import tarfile

from leipzig import ROOT, download

OUT_DIR = ROOT / "build" / "training"
WORDS_PER_LANGUAGE = 30_000

CORPORA = {
    "en": ("eng_news_2024_1M", "8f1d4d07b9771f8a7fc219ad587d5382eabf5009ef563f1bc4c12a467a8e3a97", "a-zA-Z"),
    "ru": ("rus_news_2024_1M", "7df13a6ba25c47fde0e156c1ef670fce7a86b126ee9ff9d7246ba840ef964242", "а-яА-ЯёЁ"),
    "de": ("deu_news_2024_1M", "203d98de187f6d87e7f97c1f516a64a9d19016d0dc81c935a72e769ef184fa64", "a-zA-ZäöüÄÖÜß"),
    "es": ("spa_news_2024_1M", "4666b54caad54cd46cdfea80e7cb727663b220c2ead871b4ccf6285df0599090", "a-zA-ZáéíóúüñÁÉÍÓÚÜÑ"),
}


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for code, (corpus, sha256, letters) in CORPORA.items():
        token = re.compile(f"^[{letters}]+$")
        counts = collections.Counter()
        with tarfile.open(download(corpus, sha256), "r:gz") as tar:
            with tar.extractfile(f"{corpus}/{corpus}-words.txt") as f:
                for raw in f:
                    fields = raw.decode("utf-8").rstrip("\n").split("\t")
                    if len(fields) == 3 and token.match(fields[1]):
                        counts[fields[1]] += int(fields[2])
        top = sorted(counts.items(), key=lambda wc: (-wc[1], wc[0]))[:WORDS_PER_LANGUAGE]
        (OUT_DIR / f"{code}.txt").write_text("".join(f"{w}\t{c}\n" for w, c in top), encoding="utf-8")
        print(f"{code}: {len(top)} words")


if __name__ == "__main__":
    main()
