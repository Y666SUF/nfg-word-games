#!/usr/bin/env python3
"""One-off: reconcile WordWheel level + points for every player in scores.json."""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from wordwheel_progress import reconcile_player_wordwheel, repair_player_totals  # noqa: E402

SCORES_FILE = Path(os.getenv("WORD_GAMES_DATA_DIR", str(ROOT / "data"))) / "scores.json"


def main() -> int:
    if not SCORES_FILE.is_file():
        print(f"No scores file: {SCORES_FILE}")
        return 1

    data = json.loads(SCORES_FILE.read_text(encoding="utf-8"))
    changed = 0
    for player_id, player in data.get("players", {}).items():
        username = str(player.get("username") or player_id)
        before_level = int(player.get("wordwheelLevel") or 1)
        before_ww = int((player.get("gameHighScores") or {}).get("wordwheel") or 0)
        before_total = int(player.get("totalScore") or 0)
        if repair_player_totals(player) or reconcile_player_wordwheel(player):
            player["updatedAt"] = datetime.now(timezone.utc).isoformat()
            changed += 1
            after_ww = int((player.get("gameHighScores") or {}).get("wordwheel") or 0)
            after_level = int(player.get("wordwheelLevel") or 1)
            after_total = int(player.get("totalScore") or 0)
            print(
                f"{username}: level {before_level}->{after_level}, "
                f"wordwheel {before_ww}->{after_ww}, total {before_total}->{after_total}"
            )

    if changed:
        SCORES_FILE.write_text(json.dumps(data, indent=2), encoding="utf-8")
        print(f"\nUpdated {changed} player(s) in {SCORES_FILE}")
    else:
        print("No players needed reconciliation.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
