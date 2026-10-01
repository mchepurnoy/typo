# Accuracy corpus

`en.txt`, `ru.txt`, `de.txt`, `es.txt`: the first 3,000 words of running text from the Leipzig Corpora Collection news corpora `eng_news_2023_10K`, `rus_news_2023_10K`, `deu_news_2023_10K` and `spa_news_2023_10K` (Universität Leipzig, https://wortschatz.uni-leipzig.de, CC BY; see `LanguageModels/SOURCES.md` for the licence note and citation). Changes: reduced to words made of the language's letters, one per line, punctuation removed.

The language models are built from the 2024 corpora, so this text is held out. Regenerate with `scripts/build-accuracy-corpus.py`.

The detector's thresholds were tuned on these files. On the next 3,000 words of the same corpora, without retuning (2026-10-01), recall on wrong-layout words of 3+ letters was 98.6% (RU on U.S.), 99.5% (EN on Russian – PC), 98.8% (DE), 99.8% (ES), and at most 2 of 3,000 correctly typed words were changed, all abbreviations (`Hbf`, `Ltd`, `NBD`, `Туту`).
