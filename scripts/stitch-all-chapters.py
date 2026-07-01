#!/usr/bin/env python3
"""Stitch every chapter that has 5 strip PNGs → chapter-NN-full.png"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios/ChapterMaps-dev"
STRIPS = DEV / "strips"
STITCH = ROOT / "scripts/stitch-chapter-full.py"


def main() -> int:
    done = 0
    for ch in range(1, 41):
        if all((STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").exists() for s in range(1, 6)):
            full = MAPS / f"chapter-{ch:02d}-full.png"
            newest = max((STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").stat().st_mtime for s in range(1, 6))
            if full.exists() and full.stat().st_mtime >= newest:
                print(f"  ✓ chapter {ch:02d} — already stitched")
                done += 1
                continue
            print(f"\n→ Stitching chapter {ch:02d}…")
            subprocess.run([sys.executable, str(STITCH), str(ch)], check=True)
            done += 1
        else:
            missing = [s for s in range(1, 6) if not (STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").exists()]
            print(f"  ⏳ chapter {ch:02d} — missing strips {missing}")
    print(f"\n✅ {done}/40 chapters have full scroll art\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
