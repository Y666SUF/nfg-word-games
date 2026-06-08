#!/usr/bin/env python3
"""Quick API smoke test for NFG Word Games server."""
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

BASE = sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:19877"


def req(method: str, path: str, body: dict | None = None) -> tuple[int, dict]:
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=8) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode()
        try:
            return exc.code, json.loads(raw)
        except json.JSONDecodeError:
            return exc.code, {"raw": raw}


def main() -> int:
    results: list[tuple[str, bool, object]] = []
    print(f"Testing {BASE}\n")

    code, data = req("GET", "/api/word-games/health")
    results.append(("Health", code == 200 and data.get("app") == "nfg-word-games", data))

    code, data = req("GET", "/api/word-games/leaderboard")
    results.append(("Overall leaderboard", code == 200 and "entries" in data, f"HTTP {code}"))

    code, data = req("GET", "/api/word-games/leaderboard/wordwheel")
    results.append(("WordWheel leaderboard", code == 200, f"HTTP {code}"))

    code, data = req("POST", "/api/word-games/players/login", {"username": "test_runner"})
    player_id = data.get("playerId")
    results.append(("Player login", code == 200 and bool(player_id), data.get("username", data)))

    code, data = req("POST", "/api/word-games/players/login", {"username": "badword_fuck"})
    results.append(("Profanity filter", code == 400, data.get("detail", f"HTTP {code}")))

    if player_id:
        code, data = req(
            "PUT",
            f"/api/word-games/players/{player_id}/scores",
            {"totalScore": 42, "gameHighScores": {"wordwheel": 42}, "wordwheelLevel": 2},
        )
        results.append(("Score sync", code == 200 and data.get("player", {}).get("totalScore") == 42, "ok"))

        code, data = req("GET", "/api/word-games/leaderboard")
        found = any(e.get("username") == "test_runner" for e in data.get("entries", []))
        results.append(("Leaderboard lists player", found, "ok"))

    passed = 0
    for name, ok, detail in results:
        status = "PASS" if ok else "FAIL"
        if ok:
            passed += 1
        print(f"[{status}] {name} — {detail}")

    print(f"\n{passed}/{len(results)} passed")

    if not results[0][1]:
        print("\nFIX: Wrong or missing server. Run: windows\\run-server.bat")
    elif any(not r[1] for r in results[1:3]):
        print("\nFIX: Old server running (health OK but APIs missing).")
        print("     Stop the server window, then run: windows\\run-server.bat")
        print("     Must use: py -m uvicorn server:app --host 0.0.0.0 --port 19877")

    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
