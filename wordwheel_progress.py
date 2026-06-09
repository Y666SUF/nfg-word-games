"""Derive WordWheel level from cumulative score using bundled level data."""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

LEVELS_FILE = Path(__file__).resolve().parent / "data" / "wordwheel-levels.json"
# Players rarely bank every bonus word; ~35% of puzzle-only minimum matches real play.
SCORE_LEVEL_FACTOR = 0.35


@lru_cache(maxsize=1)
def _min_points_per_level() -> tuple[int, ...]:
    data = json.loads(LEVELS_FILE.read_text(encoding="utf-8"))
    mins: list[int] = []
    for level in data["levels"]:
        words = [w["word"] if isinstance(w, dict) else w for w in level["words"]]
        mult = float(level.get("bonusMultiplier") or 1)
        mins.append(int(sum(max(1, len(w) - 2) * 10 * mult for w in words)))
    return tuple(mins)


def level_from_wordwheel_score(score: int) -> int:
    """Highest level supported by `score` (level 1 = no completed rounds)."""
    score = max(0, int(score or 0))
    if score == 0:
        return 1
    cumulative = 0
    completed = 0
    for min_pts in _min_points_per_level():
        need = max(1, int(min_pts * SCORE_LEVEL_FACTOR))
        if cumulative + need <= score:
            cumulative += need
            completed += 1
        else:
            break
    return completed + 1


def reconcile_wordwheel_level(score: int, claimed_level: int) -> int:
    """Cap inflated levels so leaderboard level matches WordWheel points earned."""
    claimed = max(1, int(claimed_level or 1))
    derived = level_from_wordwheel_score(score)
    return min(claimed, derived)


def min_score_for_level(level: int) -> int:
    """Minimum WordWheel points to legitimately be on `level`."""
    level = max(1, int(level or 1))
    cumulative = 0
    for i, min_pts in enumerate(_min_points_per_level()):
        if i >= level - 1:
            break
        cumulative += max(1, int(min_pts * SCORE_LEVEL_FACTOR))
    return cumulative


def max_score_for_level(level: int) -> int:
    """Upper WordWheel score while still on `level` (before advancing)."""
    mins = _min_points_per_level()
    level = max(1, int(level or 1))
    if level >= len(mins):
        return 10**9
    return max(0, min_score_for_level(level + 1) - 1)


def clamp_wordwheel_score(score: int, level: int) -> int:
    """Keep WordWheel points inside the valid band for a reconciled level."""
    score = max(0, int(score or 0))
    level = max(1, int(level or 1))
    if score == 0:
        return 0
    low = min_score_for_level(level)
    high = max_score_for_level(level)
    return max(low, min(score, high))


def repair_player_totals(player: dict[str, Any]) -> bool:
    """Heal per-game scores and total after a bad clamp — never lower lifetime points."""
    highs = dict(player.get("gameHighScores") or {})
    ww = int(highs.get("wordwheel") or 0)
    wordwich = int(highs.get("wordwich") or 0)
    hangman = int(highs.get("hangman") or 0)
    total = int(player.get("totalScore") or 0)
    per_game = ww + wordwich + hangman
    changed = False

    if total > per_game:
        # Excess belongs to WordWheel when breakdown was under-reported.
        highs["wordwheel"] = max(ww, total - wordwich - hangman)
        player["gameHighScores"] = highs
        changed = True

    repaired_total = max(total, sum(int(v) for v in highs.values()))
    if repaired_total != total:
        player["totalScore"] = repaired_total
        changed = True

    return changed


def reconcile_player_wordwheel(player: dict[str, Any]) -> bool:
    """Cap inflated WordWheel level only — cumulative scores are never reduced."""
    repair_player_totals(player)
    highs = dict(player.get("gameHighScores") or {})
    ww = int(highs.get("wordwheel") or 0)
    claimed = int(player.get("wordwheelLevel") or 1)
    new_level = reconcile_wordwheel_level(ww, claimed)
    if new_level == claimed:
        return False
    player["wordwheelLevel"] = new_level
    return True
