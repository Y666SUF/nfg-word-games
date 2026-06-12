#!/usr/bin/env python3
"""Export username + player restore codes from scores.json (admin use only)."""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCORES_FILE = Path(os.getenv("WORD_GAMES_DATA_DIR", str(ROOT / "data"))) / "scores.json"


def main() -> int:
    if not SCORES_FILE.is_file():
        print(f"No scores file: {SCORES_FILE}", file=sys.stderr)
        return 1

    data = json.loads(SCORES_FILE.read_text(encoding="utf-8"))
    players = data.get("players") or {}
    if not players:
        print("No players in scores file.")
        return 0

    rows = []
    for player_id, player in players.items():
        username = str(player.get("username") or "").strip() or "(no username)"
        total = int(player.get("totalScore") or 0)
        rows.append((username.lower(), username, player_id, total))

    rows.sort(key=lambda r: (-r[3], r[0]))

    print(f"NFG Words player restore codes ({len(rows)} accounts)")
    print(f"Source: {SCORES_FILE}")
    print()
    print(f"{'Username':<24} {'Player code (restore key)':<38} {'Score':>8}")
    print("-" * 74)
    for _, username, player_id, total in rows:
        print(f"{username:<24} {player_id:<38} {total:>8}")

    print()
    print("Users restore via: Mine → Restore on a new device → paste player code.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
