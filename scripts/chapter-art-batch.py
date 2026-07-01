#!/usr/bin/env python3
"""Print AI strip prompts for a chapter; stitch if strips exist."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios" / "ChapterMaps-dev"
THEMES = MAPS / "chapter-themes.json"
STRIPS = DEV / "strips"
SUFFIX = (
    "VERTICAL PORTRAIT tall fantasy mobile game environment. "
    "NO white borders NO letterboxing full bleed edge to edge. "
    "NO stone pads NO circles NO text. Cobblestone-style path zigzag top-centre to bottom-centre. "
    "Seamless vertical stacking."
)


def main() -> int:
    themes = {c["id"]: c for c in json.loads(THEMES.read_text())["chapters"]}
    chapters = [int(sys.argv[1])] if len(sys.argv) > 1 else list(range(1, 41))

    for ch in chapters:
        t = themes[ch]
        print(f"\n{'='*60}\nChapter {ch:02d}: {t['name']}\n{'='*60}")
        for seg in range(1, 6):
            prompt = (
                f"Strip {seg} of 5. {t['name']}: {t['scene']}. "
                f"{t['path']} path. {SUFFIX}"
            )
            out = STRIPS / f"chapter-{ch:02d}-strip-{seg:02d}.png"
            have = "✅" if out.exists() else "⏳"
            print(f"\n{have} chapter-{ch:02d}-strip-{seg:02d}.png\n{prompt}")

        full = MAPS / f"chapter-{ch:02d}-full.png"
        if all((STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").exists() for s in range(1, 6)):
            print(f"\n→ Stitching chapter {ch}…")
            subprocess.run([sys.executable, str(ROOT / "scripts/stitch-chapter-full.py"), str(ch)], check=True)
        elif full.exists():
            print(f"\n✅ chapter-{ch:02d}-full.png already exists")
        else:
            print(f"\n⏳ Waiting for 5 strips before stitch")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
