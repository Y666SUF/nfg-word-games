#!/usr/bin/env python3
"""Build WordWheel bonus-round packs — 10-letter wheels with 4–6 longer target words."""
from __future__ import annotations

import json
import random
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DICT = ROOT / "data" / "english-dictionary.json"
OUT = ROOT / "data" / "bonus-round-packs.json"
IOS = ROOT / "ios" / "NFGWords" / "Resources" / "bonus-round-packs.json"

CENTERS = list("eartionls")
TARGET_COUNT = 60
MIN_WORDS = 4
MAX_WORDS = 6
MIN_LEN = 5
MAX_LEN = 8
WHEEL_SIZE = 10


def can_form(word: str, pool: list[str], center: str) -> bool:
    w = word.lower()
    c = center.lower()
    if c not in w:
        return False
    letters = list(pool)
    for ch in w:
        try:
            letters.remove(ch)
        except ValueError:
            return False
    return True


def letter_pool(center: str, outer: list[str]) -> list[str]:
    c = center.lower()
    return [c] + [x.lower() for x in outer if x.lower() != c]


def main() -> None:
    words = sorted(json.loads(DICT.read_text(encoding="utf-8"))["words"])
    by_center: dict[str, list[str]] = {c: [] for c in CENTERS}
    for w in words:
        wl = w.lower()
        if not (MIN_LEN <= len(wl) <= MAX_LEN):
            continue
        for c in CENTERS:
            if c in wl:
                by_center[c].append(wl)

    packs: list[dict] = []
    attempts = 0
    while len(packs) < TARGET_COUNT and attempts < 50_000:
        attempts += 1
        center = random.choice(CENTERS)
        pool_words = by_center[center]
        if len(pool_words) < MIN_WORDS:
            continue
        random.shuffle(pool_words)
        chosen: list[str] = []
        letters: set[str] = set()
        for w in pool_words:
            needed = set(w)
            merged = letters | needed
            if len(merged) > WHEEL_SIZE:
                continue
            chosen.append(w)
            letters = merged
            if len(chosen) >= MAX_WORDS and len(letters) == WHEEL_SIZE:
                break
        if len(chosen) < MIN_WORDS or len(letters) != WHEEL_SIZE:
            continue
        if center not in letters:
            continue
        outer = sorted(letters - {center})
        if len(outer) != WHEEL_SIZE - 1:
            continue
        wheel = [center] + outer
        if not all(can_form(w, wheel, center) for w in chosen):
            continue
        sig = (center, tuple(sorted(chosen)))
        if any((p["centerLetter"], tuple(sorted(p["targetWords"]))) == sig for p in packs):
            continue
        packs.append({
            "id": len(packs) + 1,
            "centerLetter": center,
            "wheelLetters": wheel,
            "targetWords": sorted(chosen, key=lambda x: (-len(x), x)),
        })

    if len(packs) < 20:
        raise SystemExit(f"Only built {len(packs)} packs — need more dictionary coverage")

    payload = {"version": 1, "count": len(packs), "packs": packs}
    body = json.dumps(payload, separators=(",", ":"))
    OUT.write_text(body, encoding="utf-8")
    IOS.write_text(body, encoding="utf-8")
    print(f"Wrote {len(packs)} bonus packs → {OUT}")


if __name__ == "__main__":
    main()
