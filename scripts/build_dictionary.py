#!/usr/bin/env python3
"""Build professional English dictionary — real usage-based words only."""
from __future__ import annotations

import json
import re
from pathlib import Path

from wordfreq import iter_wordlist, zipf_frequency

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "data" / "english-dictionary.json"
LEVELS = ROOT / "data" / "wordwheel-levels.json"
VOWELS = set("aeiouy")


def is_professional(word: str) -> bool:
    w = word.lower()
    if len(w) < 3 or len(w) > 15:
        return False
    if not w.isalpha():
        return False
    if not any(c in VOWELS for c in w):
        return False
    if re.search(r"(.)\1{2,}", w):
        return False
    z = zipf_frequency(w, "en")
    if len(w) <= 4:
        return z >= 4.0
    if len(w) <= 6:
        return z >= 3.2
    return z >= 2.8


def main() -> None:
    words = {w.lower() for w in iter_wordlist("en") if is_professional(w.lower())}

    if LEVELS.is_file():
        levels = json.loads(LEVELS.read_text(encoding="utf-8"))
        for level in levels.get("levels", []):
            for entry in level.get("words", []):
                w = str(entry.get("word", "")).lower()
                if w.isalpha() and len(w) >= 3:
                    words.add(w)

    payload = {
        "version": 1,
        "source": "wordfreq-en-professional",
        "count": len(words),
        "words": sorted(words),
    }
    OUT.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {payload['count']} words → {OUT}")


if __name__ == "__main__":
    main()
