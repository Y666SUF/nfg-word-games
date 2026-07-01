#!/usr/bin/env python3
"""Convert bundled chapter scroll PNGs to high-quality JPEG (same pixels, much smaller)."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))

from chapter_maps_paths import JPEG_QUALITY, MAPS, SOURCE_PNG

TOTAL_CHAPTERS = 40


def convert_chapter(ch: int) -> tuple[int, float, float]:
    png = MAPS / f"chapter-{ch:02d}-full.png"
    jpg = MAPS / f"chapter-{ch:02d}-full.jpg"
    if jpg.is_file() and not png.is_file():
        return ch, jpg.stat().st_size, jpg.stat().st_size

    if not png.is_file():
        raise FileNotFoundError(png)

    before = png.stat().st_size
    img = Image.open(png).convert("RGB")
    if img.size != (1024, 20480):
        print(f"  warning chapter {ch:02d}: unexpected size {img.size}")

    jpg.parent.mkdir(parents=True, exist_ok=True)
    img.save(jpg, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
    after = jpg.stat().st_size

    SOURCE_PNG.mkdir(parents=True, exist_ok=True)
    archive = SOURCE_PNG / png.name
    if not archive.is_file():
        png.rename(archive)
    else:
        png.unlink()

    return ch, before, after


def main() -> None:
    converted: list[tuple[int, float, float]] = []
    for ch in range(1, TOTAL_CHAPTERS + 1):
        try:
            converted.append(convert_chapter(ch))
            b, a = converted[-1][1], converted[-1][2]
            print(f"  chapter {ch:02d}: {b / 1024 / 1024:.1f} MB → {a / 1024 / 1024:.1f} MB JPEG")
        except FileNotFoundError as exc:
            print(f"  chapter {ch:02d}: SKIP — {exc}")

    if not converted:
        print("No chapter scrolls converted.")
        sys.exit(1)

    before_total = sum(x[1] for x in converted)
    after_total = sum(x[2] for x in converted)
    print(f"\nConverted {len(converted)} chapters")
    print(f"  before: {before_total / 1024 / 1024:.0f} MB PNG")
    print(f"  after:  {after_total / 1024 / 1024:.0f} MB JPEG ({100 * after_total / before_total:.0f}%)")


if __name__ == "__main__":
    main()
