#!/usr/bin/env python3
"""Build UK English dictionary — common words, UK spellings preferred over American."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wordfreq import iter_wordlist

from word_filters import (
    collect_dynamic_rejections,
    is_common_english_word,
    is_wordwheel_dictionary_word,
    prefer_uk_english,
    write_rejections_file,
    write_sensitive_words_file,
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "english-dictionary.json"
IOS_OUT = ROOT / "ios" / "NFGWords" / "Resources" / "english-dictionary.json"
APP_OUT = ROOT / "app" / "src" / "data" / "english-dictionary.json"
VOWELS = set("aeiouy")


def passes_shape(word: str) -> bool:
    w = word.lower()
    if len(w) < 3 or len(w) > 15:
        return False
    if not w.isalpha():
        return False
    if not any(c in VOWELS for c in w):
        return False
    if re.search(r"(.)\1{2,}", w):
        return False
    return True


def main() -> None:
    source_words = [w.lower() for w in iter_wordlist("en")]
    write_sensitive_words_file()
    write_rejections_file(collect_dynamic_rejections(source_words))

    pool: set[str] = set()
    for w in source_words:
        if not passes_shape(w):
            continue
        if is_common_english_word(w) or is_wordwheel_dictionary_word(w):
            pool.add(w)

    pool = prefer_uk_english(pool)

    payload = {
        "version": 8,
        "source": "wordfreq-en-uk-preferred",
        "count": len(pool),
        "words": sorted(pool),
    }
    body = json.dumps(payload, separators=(",", ":"))
    OUT.write_text(body, encoding="utf-8")
    IOS_OUT.write_text(body, encoding="utf-8")
    APP_OUT.write_text(body, encoding="utf-8")
    print(f"Wrote {payload['count']} UK-preferred words → {OUT}")


if __name__ == "__main__":
    main()
