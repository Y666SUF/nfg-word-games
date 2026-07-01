#!/usr/bin/env python3
"""Repair bundled levels that fail play-tier validation (wheel vs crossword mismatch)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_levels import (  # noqa: E402
    Generator,
    load_dict,
    min_words_for_level,
    puzzle_fingerprint,
    required_wheel_size,
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
LEVELS_PATH = _vwl.LEVELS_PATH
is_valid_wordscapes_layout = _vwl.is_valid_wordscapes_layout
simulate_play_level = _vwl.simulate_play_level
validate_all = _vwl.validate_all

OUT_PATHS = (
    LEVELS_PATH,
    ROOT / "ios" / "NFGWords" / "Resources" / "wordwheel-levels.json",
    ROOT / "app" / "src" / "data" / "wordwheel-levels.json",
)


def rebuild_level(gen: Generator, level_id: int) -> dict | None:
    """Build a level whose wheel matches the play tier exactly."""
    target = target_words_for_level(level_id)
    bonus = 1 + (level_id // 200) * 0.25
    tier = required_wheel_size(level_id)
    min_words = min_words_for_level(level_id)

    def accept(pack: dict) -> dict | None:
        if len(pack["wheel"]) != tier:
            return None
        for word_target in range(target, min_words - 1, -1):
            built = gen.build_level(level_id, pack, word_target, bonus)
            if not built:
                continue
            if len(built["wheelLetters"]) != tier:
                continue
            if not is_valid_wordscapes_layout(built["words"]):
                continue
            if simulate_play_level(built) is None:
                continue
            pf = puzzle_fingerprint(built["words"])
            if pf in gen.puzzle_sets_used:
                continue
            outer = [l for l in built["wheelLetters"] if l != built["centerLetter"]]
            wk = wheel_key(built["centerLetter"], outer)
            if wk in gen.wheel_last_used:
                continue
            return built
        return None

    for pack in gen.iter_random_wheels(level_id, tier, limit=30_000):
        built = accept(pack)
        if built:
            return built

    for pack in gen.iter_on_demand_packs(level_id, tier, limit=30_000):
        built = accept(pack)
        if built:
            return built

    return None


def main() -> None:
    data = json.loads(LEVELS_PATH.read_text(encoding="utf-8"))
    levels = data["levels"]
    by_id = {lvl["id"]: lvl for lvl in levels}

    issues = validate_all(levels)
    failing = issues["play_tier_fail"]
    if not failing:
        print("No play-tier failures — nothing to repair.")
        return

    print(f"Repairing {len(failing)} levels: {failing}")

    words = load_dict()
    gen = Generator(words)

    # Seed generator history from existing levels (skip failing ids).
    for lvl in levels:
        if lvl["id"] in failing:
            continue
        for w in lvl["words"]:
            gen.word_last_used[w["word"].lower()] = lvl["id"]
        outer = [l for l in lvl["wheelLetters"] if l != lvl["centerLetter"]]
        gen.wheel_last_used[wheel_key(lvl["centerLetter"], outer)] = lvl["id"]
        gen.puzzle_sets_used.add(puzzle_fingerprint(lvl["words"]))

    repaired = 0
    for level_id in failing:
        built = rebuild_level(gen, level_id)
        if not built:
            print(f"  WARN: could not rebuild level {level_id}")
            continue

        if not is_valid_wordscapes_layout(built["words"]):
            print(f"  WARN: rebuilt level {level_id} has invalid layout")
            continue

        if simulate_play_level(built) is None:
            print(f"  WARN: rebuilt level {level_id} still fails play-tier check")
            continue

        by_id[level_id] = built
        for w in built["words"]:
            gen.word_last_used[w["word"].lower()] = level_id
        outer = [l for l in built["wheelLetters"] if l != built["centerLetter"]]
        gen.wheel_last_used[wheel_key(built["centerLetter"], outer)] = level_id
        gen.puzzle_sets_used.add(puzzle_fingerprint(built["words"]))
        repaired += 1
        print(
            f"  OK level {level_id}: wheel={built['wheelLetters']} "
            f"words={[w['word'] for w in built['words']]}"
        )

    if repaired == 0:
        sys.exit("No levels repaired.")

    data["levels"] = sorted(by_id.values(), key=lambda x: x["id"])
    data["version"] = data.get("version", 11) + 1
    payload = json.dumps(data, separators=(",", ":"))

    for path in OUT_PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")
        print(f"Wrote {path}")

    remaining = validate_all(data["levels"])["play_tier_fail"]
    print(f"Repaired {repaired}/{len(failing)}; remaining play-tier failures: {len(remaining)}")
    if remaining:
        sys.exit(1)


if __name__ == "__main__":
    main()
