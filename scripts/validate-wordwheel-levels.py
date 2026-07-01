#!/usr/bin/env python3
"""Validate bundled WordWheel levels — wheel letters, formability, Wordscapes layout, play tier."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from generate_levels import (  # noqa: E402
    can_form,
    place_words_best,
    required_wheel_size,
    validate_wheel_word_letters,
)

LEVELS_PATH = ROOT / "data" / "wordwheel-levels.json"


def key(r: int, c: int) -> str:
    return f"{r},{c}"


def parse_key(cell: str) -> tuple[int, int]:
    r, c = cell.split(",")
    return int(r), int(c)


def is_valid_wordscapes_layout(words: list[dict]) -> bool:
    """Match CrosswordPlacer.isValidLayout — no orphan adjacent letter runs."""
    if not words:
        return False

    grid: dict[str, str] = {}
    for entry in words:
        for i, ch in enumerate(entry["word"]):
            row = entry["startRow"] + (i if entry["direction"] == "down" else 0)
            col = entry["startCol"] + (i if entry["direction"] == "across" else 0)
            k = key(row, col)
            if k in grid and grid[k] != ch:
                return False
            grid[k] = ch

    cells: dict[str, int] = {}
    duplicates = 0
    for entry in words:
        for i in range(len(entry["word"])):
            row = entry["startRow"] + (i if entry["direction"] == "down" else 0)
            col = entry["startCol"] + (i if entry["direction"] == "across" else 0)
            k = key(row, col)
            cells[k] = cells.get(k, 0) + 1
            if cells[k] == 2:
                duplicates += 1

    expected = sum(len(w["word"]) for w in words) - duplicates
    if len(grid) != expected:
        return False

    positions = [parse_key(k) for k in grid]
    min_r, max_r = min(p[0] for p in positions), max(p[0] for p in positions)
    min_c, max_c = min(p[1] for p in positions), max(p[1] for p in positions)

    def matches(run: str, row: int, col: int, across: bool) -> bool:
        direction = "across" if across else "down"
        return any(
            e["direction"] == direction
            and e["startRow"] == row
            and e["startCol"] == col
            and e["word"] == run
            for e in words
        )

    for row in range(min_r, max_r + 1):
        col = min_c
        while col <= max_c:
            if key(row, col) not in grid:
                col += 1
                continue
            start_col = col
            run = ""
            while col <= max_c and key(row, col) in grid:
                run += grid[key(row, col)]
                col += 1
            if len(run) >= 2 and not matches(run, row, start_col, True):
                return False

    for col in range(min_c, max_c + 1):
        row = min_r
        while row <= max_r:
            if key(row, col) not in grid:
                row += 1
                continue
            start_row = row
            run = ""
            while row <= max_r and key(row, col) in grid:
                run += grid[key(row, col)]
                row += 1
            if len(run) >= 2 and not matches(run, start_row, col, False):
                return False

    return True


def required_outer(level_id: int) -> int:
    return required_wheel_size(level_id) - 1


def min_words_for_play(level_id: int) -> int:
    if level_id <= 15:
        return 3
    if level_id <= 150:
        return 4
    tier = (level_id - 1) // 100
    return min(7, 5 + tier)


def apply_progressive_wheel(level: dict, max_outer: int) -> dict:
    center = level["centerLetter"].lower()
    native_wheel = [x.lower() for x in level["wheelLetters"]]
    native_outers = [x for x in native_wheel if x != center]
    if len(native_outers) <= max_outer:
        return level

    outer_scores = sorted(
        [
            (letter, sum(w["word"].lower().count(letter) for w in level["words"]))
            for letter in native_outers
        ],
        key=lambda x: (-x[1], x[0]),
    )

    def wheel(outer_count: int) -> list[str]:
        picked = sorted(x[0] for x in outer_scores[:outer_count])
        return [center, *picked]

    for outer in range(max_outer, 0, -1):
        trimmed = wheel(outer)
        if all(can_form(w["word"], trimmed, center) for w in level["words"]):
            return {**level, "wheelLetters": trimmed}

    return {**level, "wheelLetters": wheel(max_outer)}


def simulate_play_level(level: dict) -> dict | None:
    """Mirror LevelStore.buildPlayLevel — returns playable level or None."""
    level_id = level["id"]
    tier_size = required_wheel_size(level_id)
    max_outer = tier_size - 1
    min_words = min_words_for_play(level_id)

    trimmed = apply_progressive_wheel(level, max_outer)
    center = trimmed["centerLetter"].lower()
    wheel = [x.lower() for x in trimmed["wheelLetters"]]

    filtered = [
        w
        for w in trimmed["words"]
        if len(w["word"]) <= tier_size and can_form(w["word"], wheel, center)
    ]
    if len(filtered) < min(min_words, 3):
        return None

    native_wheel = [x.lower() for x in level["wheelLetters"]]
    if (
        len(filtered) == len(level["words"])
        and len(wheel) == len(native_wheel)
        and {w["word"] for w in filtered} == {w["word"] for w in level["words"]}
    ):
        return level

    layout = place_words_best(
        [w["word"] for w in filtered],
        min(min_words, len(filtered)),
    )
    if not layout or not is_valid_wordscapes_layout(layout["words"]):
        return None

    return {
        **level,
        "centerLetter": trimmed["centerLetter"],
        "wheelLetters": wheel,
        "gridRows": layout["gridRows"],
        "gridCols": layout["gridCols"],
        "words": layout["words"],
    }


def validate_all(levels: list[dict]) -> dict[str, list]:
    issues: dict[str, list] = {
        "unformable_native": [],
        "wheel_mismatch_native": [],
        "bad_layout_native": [],
        "word_longer_than_wheel_native": [],
        "play_tier_fail": [],
    }

    for lvl in levels:
        lid = lvl["id"]
        wheel = [x.lower() for x in lvl["wheelLetters"]]
        center = lvl["centerLetter"].lower()
        words = lvl["words"]

        for w in words:
            if not can_form(w["word"], wheel, center):
                issues["unformable_native"].append((lid, w["word"]))
            if len(w["word"]) > len(wheel):
                issues["word_longer_than_wheel_native"].append(
                    (lid, w["word"], len(w["word"]), len(wheel))
                )

        if not validate_wheel_word_letters(wheel, center, words):
            issues["wheel_mismatch_native"].append(lid)

        if not is_valid_wordscapes_layout(words):
            issues["bad_layout_native"].append(lid)

        if simulate_play_level(lvl) is None:
            issues["play_tier_fail"].append(lid)

    return issues


def play_grid_letters(level: dict) -> set[str]:
    return {ch for w in level["words"] for ch in w["word"].lower()}


def play_wheel_letters(level: dict) -> set[str]:
    return {x.lower() for x in level["wheelLetters"]}


def validate_play_grid_subset(levels: list[dict]) -> list[tuple[int, list[str]]]:
    """Every letter on the play-tier crossword must exist on the play-tier wheel."""
    bad: list[tuple[int, list[str]]] = []
    for lvl in levels:
        played = simulate_play_level(lvl)
        if played is None:
            bad.append((lvl["id"], ["play_tier_fail"]))
            continue
        extra = sorted(play_grid_letters(played) - play_wheel_letters(played))
        if extra:
            bad.append((lvl["id"], extra))
    return bad


def main() -> None:
    data = json.loads(LEVELS_PATH.read_text(encoding="utf-8"))
    levels = data["levels"]
    issues = validate_all(levels)
    subset_bad = validate_play_grid_subset(levels)

    print("WordWheel level validation")
    print("==========================")
    for name, items in issues.items():
        print(f"  {name}: {len(items)}")
        for sample in items[:8]:
            print(f"    - {sample}")
    print(f"  play_grid_subset: {len(subset_bad)}")
    for sample in subset_bad[:8]:
        print(f"    - {sample}")

    total = sum(len(v) for v in issues.values()) + len(subset_bad)
    if total:
        sys.exit(1)
    print("All checks passed.")


if __name__ == "__main__":
    main()
