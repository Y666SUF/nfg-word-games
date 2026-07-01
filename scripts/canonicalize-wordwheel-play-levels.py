#!/usr/bin/env python3
"""Bake bundled levels to their play-tier wheel + crossword (what iOS shows in-game)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_levels import (  # noqa: E402
    can_form,
    derive_wheel_from_words,
    place_words_best,
    validate_wheel_word_letters,
)
from word_length_balance import balanced_word_subset, is_balanced
import importlib.util

_spec = importlib.util.spec_from_file_location(
    "validate_wordwheel_levels",
    ROOT / "scripts" / "validate-wordwheel-levels.py",
)
_vwl = importlib.util.module_from_spec(_spec)
assert _spec and _spec.loader
_spec.loader.exec_module(_vwl)

LEVELS_PATH = _vwl.LEVELS_PATH
is_valid_wordscapes_layout = _vwl.is_valid_wordscapes_layout
validate_all = _vwl.validate_all

OUT_PATHS = (
    LEVELS_PATH,
    ROOT / "ios" / "NFGWords" / "Resources" / "wordwheel-levels.json",
    ROOT / "app" / "src" / "data" / "wordwheel-levels.json",
)


def required_outer(level_id: int) -> int:
    return min(10, 4 + max(0, level_id - 1) // 150)


def min_words(level_id: int) -> int:
    if level_id <= 15:
        return 3
    if level_id <= 150:
        return 4
    return min(7, 5 + (level_id - 1) // 100)


def target_puzzle_words(level_id: int) -> int:
    if level_id <= 15:
        return 4
    if level_id <= 150:
        return 5
    tier = (level_id - 1) // 100
    bump = 1 if level_id % 5 == 0 else 0
    return min(5 + tier + (level_id % 3) + bump, 8)


def grid_letters(level: dict) -> set[str]:
    return {ch for w in level["words"] for ch in w["word"].lower()}


def wheel_letters(level: dict) -> set[str]:
    return {x.lower() for x in level["wheelLetters"]}


def build_play_level(source: dict, display_id: int) -> dict | None:
    tier_size = required_outer(display_id) + 1
    min_w = min_words(display_id)
    trimmed = _vwl.apply_progressive_wheel(source, required_outer(display_id))
    center = trimmed["centerLetter"].lower()
    wheel = [x.lower() for x in trimmed["wheelLetters"]]

    filtered = [
        w
        for w in trimmed["words"]
        if len(w["word"]) <= tier_size and can_form(w["word"], wheel, center)
    ]
    if len(filtered) < min(min_w, 3):
        return None

    filtered_strings = [w["word"] for w in filtered]
    target = min(len(filtered_strings), target_puzzle_words(display_id))
    balanced = balanced_word_subset(
        filtered_strings, tier_size, max(min_w, target), display_id
    )
    balanced_set = {w.lower() for w in balanced}

    native_wheel = [x.lower() for x in source["wheelLetters"]]
    is_native = (
        len(filtered) == len(source["words"])
        and len(wheel) == len(native_wheel)
        and {w.lower() for w in filtered_strings}
        == {w["word"].lower() for w in source["words"]}
        and balanced_set == {w.lower() for w in filtered_strings}
        and is_balanced(filtered_strings, tier_size)
    )

    if is_native:
        built = {**source, "id": display_id, "wheelLetters": wheel}
    else:
        layout = place_words_best(balanced, min(min_w, len(balanced)))
        if layout and is_valid_wordscapes_layout(layout["words"]):
            built = {
                **trimmed,
                "id": display_id,
                "wheelLetters": wheel,
                "bonusMultiplier": source.get("bonusMultiplier", 1.0),
                **layout,
            }
        else:
            final_words = [
                w for w in filtered if w["word"].lower() in balanced_set
            ]
            built = {
                **trimmed,
                "id": display_id,
                "wheelLetters": wheel,
                "bonusMultiplier": source.get("bonusMultiplier", 1.0),
                "words": final_words,
            }

    derived = derive_wheel_from_words(built["centerLetter"], built["words"])
    if derived:
        built["wheelLetters"] = derived

    if not validate_wheel_word_letters(
        built["wheelLetters"], built["centerLetter"], built["words"]
    ):
        return None
    if grid_letters(built) - wheel_letters(built):
        return None
    if not is_valid_wordscapes_layout(built["words"]):
        return None
    return built


def main() -> None:
    data = json.loads(LEVELS_PATH.read_text(encoding="utf-8"))
    by_id = {lvl["id"]: lvl for lvl in data["levels"]}

    changed = 0
    failed: list[int] = []
    for level_id in sorted(by_id):
        source = by_id[level_id]
        built = build_play_level(source, level_id)
        if built is None:
            failed.append(level_id)
            continue
        if json.dumps(source, sort_keys=True) != json.dumps(built, sort_keys=True):
            by_id[level_id] = built
            changed += 1

    if failed:
        print(f"ERROR: {len(failed)} levels failed canonicalization: {failed[:20]}")
        sys.exit(1)

    data["levels"] = sorted(by_id.values(), key=lambda x: x["id"])
    data["version"] = data.get("version", 14) + 1
    payload = json.dumps(data, separators=(",", ":"))

    for path in OUT_PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")

    issues = validate_all(data["levels"])
    total = sum(len(v) for v in issues.values())
    print(f"Canonicalized {changed} levels → version {data['version']}")
    print(f"Validation issues: {total}")
    if total:
        for name, items in issues.items():
            if items:
                print(f"  {name}: {items[:5]}")
        sys.exit(1)

    l54 = by_id[54]
    print(
        f"Level 54: wheel={l54['wheelLetters']} "
        f"words={[w['word'] for w in l54['words']]}"
    )
    print("All checks passed.")


if __name__ == "__main__":
    main()
