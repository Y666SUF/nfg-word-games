#!/usr/bin/env python3
"""Build expanded Wordwich dictionary — real words only, broader than WordWheel."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wordfreq import iter_wordlist, zipf_frequency

from word_filters import (
    collect_dynamic_rejections,
    is_wordwich_allowed,
    is_wordwich_word,
    write_rejections_file,
    write_sensitive_words_file,
)

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "wordwich-dictionary.json"
CORE = ROOT / "data" / "english-dictionary.json"
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
    words: set[str] = set()
    easy: list[str] = []
    medium: list[str] = []
    hard: list[str] = []

    # Core WordWheel list — already filtered for common real words.
    if CORE.is_file():
        core_data = json.loads(CORE.read_text(encoding="utf-8"))
        for w in core_data.get("words", []):
            wl = w.lower()
            if passes_shape(wl) and is_wordwich_allowed(wl):
                words.add(wl)

    scanned: list[str] = []
    for raw in iter_wordlist("en"):
        w = raw.lower()
        scanned.append(w)
        if not passes_shape(w) or not is_wordwich_allowed(w):
            continue
        words.add(w)
        z = zipf_frequency(w, "en")
        length = len(w)
        if z >= 4.0 and 4 <= length <= 6:
            easy.append(w)
        elif z >= 3.0 and 5 <= length <= 7:
            medium.append(w)
        elif z >= 2.3 and 6 <= length <= 8:
            hard.append(w)

    write_sensitive_words_file()
    write_rejections_file(collect_dynamic_rejections(scanned))
    unique = sorted(words)
    easy_set: set[str] = set()
    medium_set: set[str] = set()
    answer_set: set[str] = set()
    for w in unique:
        z = zipf_frequency(w, "en")
        length = len(w)
        # Hidden answers — everyday words only (iPhone-autocorrect territory).
        if z >= 4.3 and 4 <= length <= 6:
            easy_set.add(w)
            answer_set.add(w)
        elif z >= 3.6 and 5 <= length <= 7:
            medium_set.add(w)
            answer_set.add(w)
    payload = {
        "version": 5,
        "source": "wordfreq-en-wordwich-v5-common",
        "count": len(unique),
        "words": unique,
        "tiers": {
            "easy": sorted(easy_set),
            "medium": sorted(medium_set),
            "hard": [],
        },
        "answers": sorted(answer_set),
    }
    body = json.dumps(payload, separators=(",", ":"))
    OUT.write_text(body, encoding="utf-8")
    IOS_OUT.write_text(body, encoding="utf-8")
    APP_OUT.write_text(body, encoding="utf-8")
    print(
        f"Wrote {payload['count']} words "
        f"(easy={len(payload['tiers']['easy'])}, "
        f"medium={len(payload['tiers']['medium'])}, "
        f"answers={len(payload['answers'])}) → {OUT}"
    )


if __name__ == "__main__":
    main()
