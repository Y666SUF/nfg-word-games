#!/usr/bin/env python3
"""Build AI strip prompt for a chapter segment."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
THEMES = ROOT / "ios/NFGWords/Resources/ChapterMaps/chapter-themes.json"

BASE_RULES = (
    "VERTICAL PORTRAIT tall narrow mobile game journey map environment. "
    "A PROMINENT worn winding TRAIL/PATH must zigzag clearly visible from TOP EDGE centre to BOTTOM EDGE centre — "
    "cobblestone or dirt path worn into the terrain, obvious route for footsteps, not just scenery. "
    "Path follows centre zigzag. "
    "NO white borders NO letterboxing — full bleed edge to edge on all sides. "
    "NO stone pads NO circles NO numbers NO text NO UI. "
    "Seamless top and bottom edges for vertical stacking with adjacent panels."
)


def quality_tier(chapter: int) -> str:
    if chapter <= 10:
        return "Premium painterly iOS game illustration, rich lush environmental detail, magical word puzzle aesthetic."
    if chapter <= 20:
        return "Cinematic premium mobile game art, dramatic lighting, heightened depth, exquisite textures, more spectacular than earlier chapters."
    if chapter <= 30:
        return "Epic AAA mobile game environment, breathtaking atmospheric perspective, ultra-detailed foliage rock and water, grander scale than prior chapters."
    return "Legendary masterpiece finale quality, radiant grandeur, jewel-like detail, the most spectacular and improved vista in the entire game."


def prompt(chapter: int, segment: int) -> str:
    themes = {c["id"]: c for c in json.loads(THEMES.read_text())["chapters"]}
    t = themes[chapter]
    return (
        f"Ultra high quality strip {segment} of 5 for chapter {chapter} \"{t['name']}\". "
        f"{t['scene']}. A clear worn {t['path']} winds through the scene following the zigzag route. "
        f"The path material must match the biome ({t['path']}) and look integrated into the ground. "
        f"{quality_tier(chapter)} {BASE_RULES}"
    )


if __name__ == "__main__":
    ch = int(sys.argv[1])
    seg = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    print(prompt(ch, seg))
