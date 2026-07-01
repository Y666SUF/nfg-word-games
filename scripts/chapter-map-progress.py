#!/usr/bin/env python3
"""Compute chapter scroll art progress and print a visual bar."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios" / "ChapterMaps-dev"
STRIPS = DEV / "strips"
PROGRESS_FILE = MAPS / "PROGRESS.json"

STRIPS_PER_CHAPTER = 5
STEPS_PER_CHAPTER = STRIPS_PER_CHAPTER + 1  # strips + stitched full scroll
TOTAL_CHAPTERS = 40


def chapter_steps(ch: int) -> tuple[int, str]:
    nn = f"{ch:02d}"
    full = MAPS / f"chapter-{nn}-full.png"
    if full.is_file():
        return STEPS_PER_CHAPTER, "complete"

    strip_count = sum(
        1
        for s in range(1, STRIPS_PER_CHAPTER + 1)
        if (STRIPS / f"chapter-{nn}-strip-{s:02d}.png").is_file()
    )
    if strip_count == STRIPS_PER_CHAPTER:
        return STRIPS_PER_CHAPTER, "stitch"
    if strip_count > 0:
        return strip_count, "strips"
    return 0, "pending"


def render_bar(percent: float, width: int = 40) -> str:
    pct = max(0.0, min(100.0, percent))
    filled = int(round((pct / 100.0) * width))
    return f"[{'█' * filled}{'░' * (width - filled)}]"


def main() -> None:
    total_steps = TOTAL_CHAPTERS * STEPS_PER_CHAPTER
    completed_steps = 0
    full_chapters = 0
    stitch_queue: list[int] = []
    in_progress: list[tuple[int, int]] = []
    chapters: dict[str, dict] = {}

    for ch in range(1, TOTAL_CHAPTERS + 1):
        steps, status = chapter_steps(ch)
        completed_steps += steps
        if status == "complete":
            full_chapters += 1
        elif status == "stitch":
            stitch_queue.append(ch)
        elif status == "strips":
            in_progress.append((ch, steps))

        chapters[str(ch)] = {
            "name": _chapter_name(ch),
            "strips": min(steps, STRIPS_PER_CHAPTER),
            "status": status,
        }

    percent = (completed_steps / total_steps) * 100 if total_steps else 0.0

    if stitch_queue:
        task = f"Stitch chapters {', '.join(str(c) for c in stitch_queue[:6])}"
        if len(stitch_queue) > 6:
            task += f" +{len(stitch_queue) - 6} more"
    elif in_progress:
        ch, done = in_progress[0]
        task = f"Chapter {ch:02d} strips {done}/{STRIPS_PER_CHAPTER}"
    elif full_chapters == TOTAL_CHAPTERS:
        task = "All chapter scrolls complete"
    else:
        task = "Waiting for next chapter"

    payload = {
        "updatedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "totalChapters": TOTAL_CHAPTERS,
        "completedChapters": full_chapters,
        "totalSteps": total_steps,
        "completedSteps": completed_steps,
        "percentComplete": round(percent, 1),
        "currentTask": task,
        "chapters": chapters,
    }
    PROGRESS_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║       NFG Journey — Chapter Scroll Art (40 chapters)           ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    print(f"  {render_bar(percent)}  {percent:.1f}%")
    print(f"  {completed_steps}/{total_steps} steps · {full_chapters}/{TOTAL_CHAPTERS} chapters ready")
    print(f"  {task}")
    print()

    for ch in range(1, TOTAL_CHAPTERS + 1):
        nn = f"{ch:02d}"
        info = chapters[str(ch)]
        if info["status"] == "complete":
            full = MAPS / f"chapter-{nn}-full.png"
            mb = full.stat().st_size / (1024 * 1024)
            print(f"  ✅ Ch{nn} full scroll ({mb:.0f}M)")
        elif info["status"] == "stitch":
            print(f"  🧵 Ch{nn} strips 5/5 — ready to stitch")
        elif info["status"] == "strips":
            print(f"  🔄 Ch{nn} strips {info['strips']}/{STRIPS_PER_CHAPTER}")
        else:
            print(f"  ⬜ Ch{nn} not started")
    print()


def _chapter_name(ch: int) -> str:
    themes = MAPS / "chapter-themes.json"
    if themes.is_file():
        try:
            data = json.loads(themes.read_text(encoding="utf-8"))
            for entry in data.get("chapters", []):
                if entry.get("chapter") == ch:
                    return entry.get("name", f"Chapter {ch}")
        except json.JSONDecodeError:
            pass
    return f"Chapter {ch}"


if __name__ == "__main__":
    main()
