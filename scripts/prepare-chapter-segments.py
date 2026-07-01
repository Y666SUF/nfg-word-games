#!/usr/bin/env python3
"""Prepare chapter map segment PNGs: enforce portrait 1024×3584, copy to bundle."""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
ASSETS = Path.home() / ".cursor/projects/Users-y666suf-Documents-nfg-word-games/assets"
TARGET_W, TARGET_H = 1024, 3584


def resize_portrait(src: Path, dst: Path) -> None:
    tmp = dst.with_suffix(".tmp.png")
    shutil.copy2(src, tmp)
    subprocess.run(
        ["sips", "-z", str(TARGET_H), str(TARGET_W), str(tmp), "--out", str(dst)],
        check=True,
        capture_output=True,
    )
    tmp.unlink(missing_ok=True)
    print(f"  ✅ {dst.name} → {TARGET_W}×{TARGET_H}")


def main() -> int:
    chapter = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    print(f"\n📐 Preparing Chapter {chapter:02d} segments ({TARGET_W}×{TARGET_H} portrait)\n")

    for seg in range(1, 6):
        name = f"chapter-{chapter:02d}-seg-{seg:02d}.png"
        dst = MAPS / name
        src = ASSETS / name
        if not src.exists():
            src = MAPS / name
        if not src.exists():
            print(f"  ⏭  {name} — source not found, skipping")
            continue
        resize_portrait(src, dst)

    progress = MAPS / "PROGRESS.json"
    if progress.exists():
        data = json.loads(progress.read_text())
        done = sum(1 for seg in range(1, 6) if (MAPS / f"chapter-{chapter:02d}-seg-{seg:02d}.png").exists())
        data["currentTask"] = f"Chapter {chapter} — {done}/5 segments ready"
        data["completedSegments"] = sum(
            1 for ch in range(1, 41) for seg in range(1, 6)
            if (MAPS / f"chapter-{ch:02d}-seg-{seg:02d}.png").exists()
        )
        progress.write_text(json.dumps(data, indent=2) + "\n")

    print("\nDone.\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
