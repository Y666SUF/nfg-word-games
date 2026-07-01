#!/usr/bin/env python3
"""Reorder bundled WordWheel levels 1…2000 by difficulty without changing any layout."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATHS = [
    ROOT / "data" / "wordwheel-levels.json",
    ROOT / "ios" / "NFGWords" / "Resources" / "wordwheel-levels.json",
    ROOT / "app" / "src" / "data" / "wordwheel-levels.json",
]


def outer_count(level: dict) -> int:
    center = level["centerLetter"].lower()
    return len([x for x in level["wheelLetters"] if x.lower() != center])


def difficulty_key(level: dict) -> tuple:
    words = level["words"]
    return (
        outer_count(level),
        len(words),
        max(len(w["word"]) for w in words) if words else 0,
        sum(len(w["word"]) for w in words),
        level["id"],
    )


def main() -> None:
    src = PATHS[0]
    data = json.loads(src.read_text(encoding="utf-8"))
    levels = data["levels"]
    if len(levels) != 2000:
        raise SystemExit(f"Expected 2000 levels, found {len(levels)}")

    ordered = sorted(levels, key=difficulty_key)
    for new_id, level in enumerate(ordered, start=1):
        level["id"] = new_id

    data["version"] = int(data.get("version", 9)) + 1
    data["ordering"] = "difficulty-outer-words-v1"
    payload = json.dumps(data, separators=(",", ":"))

    for path in PATHS:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8")

    print(f"Reordered {len(ordered)} levels by difficulty → v{data['version']}")
    for start in (1, 151, 301, 451, 601, 751, 901):
        end = min(start + 149, 2000)
        chunk = ordered[start - 1 : end]
        outers = [outer_count(lv) for lv in chunk]
        print(
            f"  L{start}-{end}: outer min={min(outers)} avg={sum(outers)/len(outers):.1f} max={max(outers)}"
        )


if __name__ == "__main__":
    main()
