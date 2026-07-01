#!/usr/bin/env python3
"""List or generate missing chapter scroll art (one chapter at a time)."""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios/NFGWords/Resources/ChapterMaps"
DEV = ROOT / "ios/ChapterMaps-dev"
STRIPS = DEV / "strips"
ASSETS = Path.home() / ".cursor/projects/Users-y666suf-Documents-nfg-word-games/assets"
PROMPT = ROOT / "scripts/chapter-strip-prompt.py"
STITCH = ROOT / "scripts/stitch-chapter-full.py"


def missing_chapters() -> list[int]:
    out: list[int] = []
    for ch in range(1, 41):
        full = MAPS / f"chapter-{ch:02d}-full.png"
        if full.is_file():
            continue
        strip_count = sum(
            1 for s in range(1, 6) if (STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").is_file()
        )
        if strip_count < 5:
            out.append(ch)
    return out


def copy_strip(chapter: int, segment: int) -> bool:
    nn = f"{chapter:02d}"
    seg = f"{segment:02d}"
    src = ASSETS / f"chapter-{nn}-strip-{seg}.png"
    if not src.is_file():
        return False
    dest = STRIPS / f"chapter-{nn}-strip-{seg}.png"
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(src.read_bytes())
    return True


def stitch_if_ready(chapter: int) -> bool:
    if all((STRIPS / f"chapter-{chapter:02d}-strip-{s:02d}.png").exists() for s in range(1, 6)):
        subprocess.run([sys.executable, str(STITCH), str(chapter)], check=True)
        return True
    return False


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] == "list":
        missing = missing_chapters()
        print("Missing or incomplete chapters:", ", ".join(f"{c:02d}" for c in missing) or "none")
        for ch in missing:
            cnt = sum(1 for s in range(1, 6) if (STRIPS / f"chapter-{ch:02d}-strip-{s:02d}.png").exists())
            print(f"  Ch{ch:02d}: {cnt}/5 strips")
        return 0

    if sys.argv[1] == "copy" and len(sys.argv) >= 4:
        ch, seg = int(sys.argv[2]), int(sys.argv[3])
        ok = copy_strip(ch, seg)
        print("copied" if ok else "missing asset")
        stitch_if_ready(ch)
        return 0

    if sys.argv[1] == "prompt" and len(sys.argv) >= 4:
        ch, seg = int(sys.argv[2]), int(sys.argv[3])
        subprocess.run([sys.executable, str(PROMPT), str(ch), str(seg)], check=True)
        return 0

    if sys.argv[1] == "stitch" and len(sys.argv) >= 3:
        stitch_if_ready(int(sys.argv[2]))
        return 0

    print("Usage: generate-missing-chapters.py [list|prompt CH SEG|copy CH SEG|stitch CH]")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
