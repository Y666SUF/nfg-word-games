#!/usr/bin/env python3
"""Build expanded Wordwich dictionary — real words only, broader than WordWheel."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wordfreq import iter_wordlist, zipf_frequency

from word_filters import is_wordwich_word

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "wordwich-dictionary.json"
IOS_OUT = ROOT / "ios" / "NFGWords" / "Resources" / "wordwich-dictionary.json"
APP_OUT = ROOT / "app" / "src" / "data" / "wordwich-dictionary.json"
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
    words: list[str] = []
    easy: list[str] = []
    medium: list[str] = []
    hard: list[str] = []

    for raw in iter_wordlist("en"):
        w = raw.lower()
        if not passes_shape(w) or not is_wordwich_word(w):
            continue
        z = zipf_frequency(w, "en")
        length = len(w)
        words.append(w)
        if z >= 4.0 and 4 <= length <= 6:
            easy.append(w)
        elif z >= 3.0 and 5 <= length <= 7:
            medium.append(w)
        elif z >= 2.3 and 6 <= length <= 8:
            hard.append(w)

    unique = sorted(set(words))
    payload = {
        "version": 1,
        "source": "wordfreq-en-wordwich-extended",
        "count": len(unique),
        "words": unique,
        "tiers": {
            "easy": sorted(set(easy)),
            "medium": sorted(set(medium)),
            "hard": sorted(set(hard)),
        },
    }
    body = json.dumps(payload, separators=(",", ":"))
    OUT.write_text(body, encoding="utf-8")
    IOS_OUT.write_text(body, encoding="utf-8")
    APP_OUT.write_text(body, encoding="utf-8")
    print(
        f"Wrote {payload['count']} words "
        f"(easy={len(payload['tiers']['easy'])}, "
        f"medium={len(payload['tiers']['medium'])}, "
        f"hard={len(payload['tiers']['hard'])}) → {OUT}"
    )


if __name__ == "__main__":
    main()
