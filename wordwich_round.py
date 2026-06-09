"""Shared Wordwich round state — multiplayer sync on the Word Games server."""
from __future__ import annotations

import json
import random
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
DICT_FILE = ROOT / "data" / "wordwich-dictionary.json"
ROUNDS_FILE = Path(__file__).resolve().parent / "data" / "wordwich-round.json"

TIER_WEIGHTS = ("easy", "medium", "hard")
TIER_PROBS = (0.6, 0.3, 0.1)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _prefix_match_len(guess: str, answer: str) -> int:
    """Consecutive matching letters from the start only (fare vs fire → 1)."""
    g = guess.lower()
    a = answer.lower()
    n = 0
    for i in range(min(len(g), len(a))):
        if g[i] == a[i]:
            n += 1
        else:
            break
    return n


class WordwichStore:
    def __init__(self) -> None:
        self._dict: dict[str, Any] = {}
        self._round: dict[str, Any] | None = None
        self._load_dictionary()
        self._load_round()

    def _load_dictionary(self) -> None:
        if not DICT_FILE.is_file():
            self._dict = {"words": [], "tiers": {"easy": [], "medium": [], "hard": []}}
            return
        self._dict = json.loads(DICT_FILE.read_text(encoding="utf-8"))

    def valid_words(self) -> set[str]:
        return {w.lower() for w in self._dict.get("words") or []}

    def _pick_answer(self) -> str:
        tiers = self._dict.get("tiers") or {}
        tier = random.choices(TIER_WEIGHTS, weights=TIER_PROBS, k=1)[0]
        pool = list(tiers.get(tier) or [])
        if not pool:
            pool = list(self._dict.get("words") or [])
        if not pool:
            return "horse"
        recent = {g["word"] for g in (self._round or {}).get("guesses", [])[-20:]}
        candidates = [w for w in pool if w not in recent] or pool
        return random.choice(candidates).lower()

    def _load_round(self) -> None:
        if ROUNDS_FILE.is_file():
            try:
                self._round = json.loads(ROUNDS_FILE.read_text(encoding="utf-8"))
                self._migrate_round_format()
            except json.JSONDecodeError:
                self._round = None
        if not self._round or self._round.get("status") != "active":
            self._start_round()

    def _migrate_round_format(self) -> None:
        if not self._round:
            return
        if "revealedPrefixLen" in self._round:
            return
        revealed = self._round.get("revealed")
        if isinstance(revealed, list):
            n = 0
            for flag in revealed:
                if flag:
                    n += 1
                else:
                    break
            self._round["revealedPrefixLen"] = n
        else:
            self._round["revealedPrefixLen"] = 0
        self._round.pop("revealed", None)
        self._round.pop("answerLength", None)

    def _save_round(self) -> None:
        ROUNDS_FILE.parent.mkdir(parents=True, exist_ok=True)
        if self._round:
            ROUNDS_FILE.write_text(json.dumps(self._round, indent=2), encoding="utf-8")

    def _start_round(self) -> None:
        answer = self._pick_answer()
        self._round = {
            "roundId": str(uuid.uuid4()),
            "answer": answer,
            "revealedPrefixLen": 0,
            "guesses": [],
            "status": "active",
            "wonBy": None,
            "startedAt": _now(),
        }
        self._save_round()

    def _sync_revealed_prefix(self) -> None:
        if not self._round:
            return
        answer = self._round["answer"]
        if self._round.get("status") == "won":
            self._round["revealedPrefixLen"] = len(answer)
            return
        lengths = [_prefix_match_len(g["word"], answer) for g in self._round.get("guesses", [])]
        self._round["revealedPrefixLen"] = max(lengths) if lengths else 0

    def _alphabetical_neighbors(self, answer: str, guess_words: list[str]) -> tuple[list[str], list[str]]:
        a = answer.lower()
        below = sorted({w.lower() for w in guess_words if w.lower() < a})
        above = sorted({w.lower() for w in guess_words if w.lower() > a})
        before = below[-5:] if below else []
        after = above[:5] if above else []
        return before, after

    def _revealed_prefix_text(self, answer: str) -> str:
        if not self._round:
            return ""
        n = int(self._round.get("revealedPrefixLen") or 0)
        if self._round.get("status") == "won":
            return answer.upper()
        return answer[:n].upper()

    def _guess_prefix_flags(self, guess: str, answer: str) -> list[bool]:
        plen = _prefix_match_len(guess, answer)
        return [i < plen for i in range(len(guess))]

    def _public_round(self) -> dict[str, Any]:
        if not self._round:
            self._start_round()
        assert self._round
        answer = self._round["answer"]
        guesses = self._round["guesses"]
        guess_words = [g["word"] for g in guesses]
        before, after = self._alphabetical_neighbors(answer, guess_words)
        return {
            "roundId": self._round["roundId"],
            "revealedPrefix": self._revealed_prefix_text(answer),
            "guesses": [
                {
                    "id": g["id"],
                    "playerId": g.get("playerId"),
                    "username": g.get("username", "Player"),
                    "word": g["word"],
                    "at": g.get("at"),
                    "matches": self._guess_prefix_flags(g["word"], answer),
                }
                for g in guesses
            ],
            "before": before,
            "after": after,
            "status": self._round["status"],
            "wonBy": self._round.get("wonBy"),
            "playerCount": len({g.get("playerId") for g in guesses if g.get("playerId")}),
        }

    def get_state(self) -> dict[str, Any]:
        return {"ok": True, "round": self._public_round()}

    def submit_guess(
        self,
        word: str,
        player_id: str | None = None,
        username: str | None = None,
    ) -> dict[str, Any]:
        if not self._round or self._round.get("status") != "active":
            self._start_round()

        assert self._round
        w = word.strip().lower()
        if not w.isalpha() or len(w) < 3:
            return {"ok": False, "error": "invalid_word", "message": "Enter a real word (3+ letters)."}

        if w not in self.valid_words():
            return {"ok": False, "error": "not_in_dictionary", "message": "Not in the Wordwich dictionary."}

        dup = any(g["word"] == w for g in self._round["guesses"])
        if dup:
            return {"ok": False, "error": "already_guessed", "message": "That word was already guessed."}

        answer = self._round["answer"]
        entry = {
            "id": str(uuid.uuid4()),
            "playerId": player_id,
            "username": (username or "Player").strip()[:32] or "Player",
            "word": w,
            "at": _now(),
        }
        self._round["guesses"].append(entry)
        self._sync_revealed_prefix()

        won = w == answer
        if won:
            self._round["status"] = "won"
            self._round["wonBy"] = {
                "playerId": player_id,
                "username": entry["username"],
                "word": w,
            }
            self._round["revealedPrefixLen"] = len(answer)

        self._save_round()
        result = {
            "ok": True,
            "correct": won,
            "guess": entry,
            "round": self._public_round(),
        }
        if won:
            result["answer"] = answer
        return result

    def new_round(self) -> dict[str, Any]:
        self._start_round()
        return self.get_state()


store = WordwichStore()
