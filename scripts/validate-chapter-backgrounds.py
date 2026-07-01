#!/usr/bin/env python3
"""Validate chapter scroll art — files present, size, seams, strip coverage."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios" / "ChapterMaps-dev"
STRIPS = DEV / "strips"
TOTAL_CHAPTERS = 40
EXPECTED_W, EXPECTED_H = 1024, 20480
SEAMS = [4000, 8000, 12000, 16000]


def find_strip(chapter: int, index: int) -> Path | None:
    nn = f"{index:02d}"
    for p in (
        STRIPS / f"chapter-{chapter:02d}-strip-{nn}.png",
        STRIPS / f"chapter-{chapter:02d}" / f"chapter-{chapter:02d}-strip-{nn}.png",
        MAPS / f"chapter-{chapter:02d}-strip-{nn}.png",
    ):
        if p.is_file():
            return p
    return None


def seam_score(path: Path) -> float:
    arr = np.array(Image.open(path).convert("RGB"), dtype=np.float32)
    scores = []
    for y in SEAMS:
        if 1 <= y < arr.shape[0]:
            scores.append(float(np.abs(arr[y] - arr[y - 1]).mean()))
    return max(scores) if scores else 0.0


def main() -> None:
    missing_full: list[int] = []
    bad_size: list[tuple[int, tuple[int, int]]] = []
    stale: list[int] = []
    weak_seams: list[tuple[int, float]] = []

    for ch in range(1, TOTAL_CHAPTERS + 1):
        full = MAPS / f"chapter-{ch:02d}-full.jpg"
        if not full.is_file():
            full = MAPS / f"chapter-{ch:02d}-full.png"
        if not full.is_file():
            missing_full.append(ch)
            continue

        with Image.open(full) as img:
            if img.size != (EXPECTED_W, EXPECTED_H):
                bad_size.append((ch, img.size))

        strip_mt = [find_strip(ch, s) for s in range(1, 6)]
        if any(p is None for p in strip_mt):
            missing = [s for s, p in enumerate(strip_mt, start=1) if p is None]
            print(f"  chapter {ch:02d}: missing strips {missing}")
        elif full.suffix == ".png":
            newest = max(p.stat().st_mtime for p in strip_mt if p)
            if full.stat().st_mtime < newest:
                stale.append(ch)

        score = seam_score(full)
        if score > 7.5:
            weak_seams.append((ch, score))

    print("Chapter background validation")
    print("============================")
    print(f"  missing full image: {len(missing_full)} {missing_full[:10]}")
    print(f"  wrong dimensions:   {len(bad_size)} {bad_size[:5]}")
    print(f"  stale vs strips:    {len(stale)} {stale}")
    print(f"  weak seams (>7.5):  {len(weak_seams)}")
    for ch, sc in sorted(weak_seams, key=lambda x: -x[1])[:10]:
        print(f"    chapter {ch:02d}: seam jump {sc:.1f}")

    issues = len(missing_full) + len(bad_size) + len(stale)
    if issues:
        sys.exit(1)
    print("All chapter full scrolls present and up to date.")


if __name__ == "__main__":
    main()
