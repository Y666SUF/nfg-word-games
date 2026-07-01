#!/usr/bin/env python3
"""Rebalance bundled levels — cap full-length words and rebuild crosswords."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_levels import (  # noqa: E402
    Generator,
    can_form,
    load_dict,
    min_words_for_level,
    place_words_best,
    puzzle_fingerprint,
    target_words_for_level,
    wheel_key,
)
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "validate_wordwheel_levels",
    ROOT / "scripts" / "validate-wordwheel-levels.py",
)
_vwl = importlib.util.module_from_spec(_spec)
assert _spec and _spec.loader
_spec.loader.exec_module(_vwl)
is_valid_wordscapes_layout = _vwl.is_valid_wordscapes_layout
simulate_play_level = _vwl.simulate_play_level
from word_length_balance import balanced_word_subset, is_balanced, max_full_length_words

LEVELS_PATH = ROOT / "data" / "wordwheel-levels.json"
OUT_PATHS = (
    LEVELS_PATH,
    ROOT / "ios" / "NFGWords" / "Resources" / "wordwheel-levels.json",
    ROOT / "app" / "src" / "data" / "wordwheel-levels.json",
)


def rebalance_level(level: dict) -> dict | None:
    wheel = [x.lower() for x in level["wheelLetters"]]
    wheel_size = len(wheel)
    center = level["centerLetter"].lower()
    words = [w["word"].lower() for w in level["words"]]
    min_words = min_words_for_level(level["id"])
    target = target_words_for_level(level["id"])

    formable = [
        w
        for w in words
        if can_form(w, wheel, center) and len(w) <= wheel_size
    ]
    if len(formable) < min(min_words, 3):
        return None

    if is_balanced(formable, wheel_size):
        return level

    balanced = balanced_word_subset(
        formable,
        wheel_size,
        max(min_words, min(len(formable), target)),
        level["id"] * 17_371,
    )
    if len(balanced) < min(min_words, 3):
        return None

    layout = place_words_best(balanced, min(min_words, len(balanced)))
    if not layout or not is_valid_wordscapes_layout(layout["words"]):
        return None

    rebuilt = {
        **level,
        "gridRows": layout["gridRows"],
        "gridCols": layout["gridCols"],
        "words": layout["words"],
    }
    if simulate_play_level(rebuilt) is None:
        return None
    return rebuilt


def main() -> None:
    data = json.loads(LEVELS_PATH.read_text(encoding="utf-8"))
    levels = data["levels"]
    by_id = {lvl["id"]: lvl for lvl in levels}

    unbalanced = []
    for lvl in levels:
        wheel_size = len(lvl["wheelLetters"])
        if wheel_size < 6:
            continue
        words = [w["word"] for w in lvl["words"]]
        if not is_balanced(words, wheel_size):
            unbalanced.append(lvl["id"])

    print(f"Found {len(unbalanced)} levels (wheel ≥6) with too many max-length words")
    if not unbalanced:
        print("Nothing to repair.")
        return

    repaired = 0
    failed: list[int] = []
    for level_id in unbalanced:
        built = rebalance_level(by_id[level_id])
        if not built:
            failed.append(level_id)
            continue
        by_id[level_id] = built
        repaired += 1
        full = sum(1 for w in built["words"] if len(w["word"]) == len(built["wheelLetters"]))
        print(
            f"  OK {level_id}: wheel={len(built['wheelLetters'])} "
            f"words={[w['word'] for w in built['words']]} full_len={full}"
        )

    if repaired == 0:
        sys.exit(f"Could not repair any level; failed: {failed[:20]}")

    data["levels"] = sorted(by_id.values(), key=lambda x: x["id"])
    data["version"] = data.get("version", 11) + 1
    payload = json.dumps(data, separators=(",", ":"))
    for path in OUT_PATHS:
        path.write_text(payload, encoding="utf-8")
        print(f"Wrote {path}")

    print(f"Repaired {repaired}/{len(unbalanced)}; failed: {len(failed)}")


if __name__ == "__main__":
    main()
