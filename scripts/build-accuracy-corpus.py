#!/usr/bin/env python3
"""Builds the Engine's accuracy-test corpus from held-out Leipzig news sentences.

Usage: scripts/build-accuracy-corpus.py

Writes Tests/EngineTests/Accuracy/<code>.txt: running text from 2023 news (the language models
are built from 2024 news), one word per line, in sentence order so frequent words appear as often
as they do in real typing. Only words made of the language's letters are kept; their case and
Russian `ё` are kept as written. Standard library only; deterministic.
"""

import re
import tarfile

from leipzig import ROOT, download

OUT_DIR = ROOT / "Tests" / "EngineTests" / "Accuracy"
WORDS_PER_LANGUAGE = 3000

# language code -> (Leipzig corpus, its SHA-256, letters)
CORPORA = {
    "en": ("eng_news_2023_10K", "7116a5d0bce0ec44d8764ed80a403e0ea6ad3f766c57d562d5c62f7f8244f922", "a-zA-Z"),
    "ru": ("rus_news_2023_10K", "bd2f4a88132e14ae7df6ecef128b884f33d0d1abf01eea3cc530da3788e026cb", "а-яА-ЯёЁ"),
    "de": ("deu_news_2023_10K", "166d8ff8b4e6c30d38c6fdf9cbe847f7ba6ca18da15633799a72dc11cfee7380", "a-zA-ZäöüÄÖÜß"),
    "es": ("spa_news_2023_10K", "8679c4ab0f1fd19d379155493611e347f0379e34e8870417fe3c039a5a120aa4",
           "a-zA-ZáéíóúüñÁÉÍÓÚÜÑ"),
}


def words(corpus: str, sha256: str, letters: str) -> list:
    token = re.compile(f"^[{letters}]+$")
    out = []
    with tarfile.open(download(corpus, sha256), "r:gz") as tar:
        with tar.extractfile(f"{corpus}/{corpus}-sentences.txt") as f:
            for raw in f:
                sentence = raw.decode("utf-8").rstrip("\n").split("\t", 1)[-1]
                for piece in sentence.split():
                    piece = piece.strip(".,;:!?\"'«»„“”()[]—–-…")
                    if token.match(piece):
                        out.append(piece)
                        if len(out) == WORDS_PER_LANGUAGE:
                            return out
    return out


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for code, (corpus, sha256, letters) in CORPORA.items():
        corpus_words = words(corpus, sha256, letters)
        (OUT_DIR / f"{code}.txt").write_text("\n".join(corpus_words) + "\n", encoding="utf-8")
        print(f"{code}: {len(corpus_words)} words from {corpus}")


if __name__ == "__main__":
    main()
