#!/usr/bin/env python3
"""Build WordWheel bonus-round packs — common words, smaller wheels, 3–4 targets."""
from __future__ import annotations

import json
import random
from pathlib import Path

from wordfreq import zipf_frequency

from word_filters import is_common_english_word, is_likely_place_or_surname

ROOT = Path(__file__).resolve().parent.parent
WORDWICH = ROOT / "data" / "wordwich-dictionary.json"
OUT = ROOT / "data" / "bonus-round-packs.json"
IOS = ROOT / "ios" / "NFGWords" / "Resources" / "bonus-round-packs.json"

CENTERS = list("aeiort")
TARGET_COUNT = 80
MIN_WORDS = 3
MAX_WORDS = 4
MIN_LEN = 4
MAX_LEN = 6
MIN_WHEEL = 6
MAX_WHEEL = 8
MIN_ZIPF = 4.0
BRAND_BLOCKLIST = frozenset({
    "itunes", "iphone", "ipad", "google", "amazon", "facebook", "twitter",
    "puerto", "ortiz", "huston", "malik", "ringo", "django", "icloud",
})


def can_form(word: str, wheel: list[str], center: str) -> bool:
    w = word.lower()
    c = center.lower()
    if c not in w:
        return False
    letters = list(wheel)
    for ch in w:
        try:
            letters.remove(ch)
        except ValueError:
            return False
    return True


def is_bonus_target(word: str) -> bool:
    w = word.lower()
    if w in BRAND_BLOCKLIST:
        return False
    if not (MIN_LEN <= len(w) <= MAX_LEN):
        return False
    if not is_common_english_word(w):
        return False
    if is_likely_place_or_surname(w):
        return False
    return zipf_frequency(w, "en") >= MIN_ZIPF


def main() -> None:
    wj = json.loads(WORDWICH.read_text(encoding="utf-8"))
    tier_pool = set(wj.get("tiers", {}).get("easy", [])) | set(wj.get("tiers", {}).get("medium", []))
    common: list[str] = []
    for w in tier_pool:
        wl = w.lower()
        if is_bonus_target(wl):
            common.append(wl)
    common.sort(key=lambda w: (-zipf_frequency(w, "en"), w))

    by_center: dict[str, list[str]] = {c: [] for c in CENTERS}
    for w in common:
        for c in CENTERS:
            if c in w:
                by_center[c].append(w)

    packs: list[dict] = []
    seen_sigs: set[tuple[str, tuple[str, ...]]] = set()
    attempts = 0

    while len(packs) < TARGET_COUNT and attempts < 120_000:
        attempts += 1
        wheel_size = random.randint(MIN_WHEEL, MAX_WHEEL)
        center = random.choice(CENTERS)
        pool = by_center[center]
        if len(pool) < MIN_WORDS:
            continue

        start = random.randint(0, max(0, len(pool) - 40))
        candidates = pool[start : start + 80]

        chosen: list[str] = []
        letters: set[str] = set()
        for w in candidates:
            needed = set(w)
            merged = letters | needed
            if len(merged) > wheel_size:
                continue
            if w in chosen:
                continue
            chosen.append(w)
            letters = merged
            if len(chosen) >= MAX_WORDS and len(letters) >= wheel_size - 1:
                break

        if len(chosen) < MIN_WORDS:
            continue

        if center not in letters:
            continue

        outer = sorted(letters - {center})
        if len(outer) > wheel_size - 1:
            continue
        while len(outer) < wheel_size - 1:
            extras = [c for c in "snrltdm" if c != center and c not in outer]
            if not extras:
                break
            outer.append(extras[0])
            outer = sorted(set(outer))
        if len(outer) != wheel_size - 1:
            continue

        wheel = [center] + outer
        if not all(can_form(w, wheel, center) for w in chosen):
            continue

        chosen = sorted(chosen, key=lambda w: (-zipf_frequency(w, "en"), -len(w), w))[:MAX_WORDS]
        if len(chosen) < MIN_WORDS:
            continue

        sig = (center, tuple(sorted(chosen)))
        if sig in seen_sigs:
            continue
        seen_sigs.add(sig)

        packs.append({
            "id": len(packs) + 1,
            "centerLetter": center,
            "wheelLetters": wheel,
            "targetWords": chosen,
        })

    if len(packs) < 30:
        raise SystemExit(f"Only built {len(packs)} packs — relax filters or expand dictionary")

    payload = {
        "version": 2,
        "count": len(packs),
        "packs": packs,
    }
    body = json.dumps(payload, separators=(",", ":"))
    OUT.write_text(body, encoding="utf-8")
    IOS.write_text(body, encoding="utf-8")

    sample = packs[0]
    print(
        f"Wrote {len(packs)} bonus packs (v2) → {OUT}\n"
        f"Sample: wheel={''.join(sample['wheelLetters'])} "
        f"words={', '.join(sample['targetWords'])}"
    )


if __name__ == "__main__":
    main()
