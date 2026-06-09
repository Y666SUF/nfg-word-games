"""
NFG Word Games — standalone Python server (separate from NFG Crash).

  python -m uvicorn server:app --host 0.0.0.0 --port 19877

Open http://127.0.0.1:19877/
"""
from __future__ import annotations

import json
import os
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from profanity import validate_username
from wordwheel_progress import (
    level_from_wordwheel_score,
    reconcile_player_wordwheel,
    reconcile_wordwheel_level,
    repair_player_totals,
)

try:
    from wordwich_round import store as wordwich_store
except Exception as exc:  # noqa: BLE001 — keep core API up if Wordwich files are missing
    wordwich_store = None
    print(f"[Wordwich] disabled on startup: {exc}", flush=True)

load_dotenv()

ROOT = Path(__file__).resolve().parent
LEGAL_DIR = ROOT / "legal"
DATA_DIR = Path(os.getenv("WORD_GAMES_DATA_DIR", str(ROOT / "data")))
SCORES_FILE = DATA_DIR / "scores.json"
LEVELS_FILE = ROOT / "data" / "wordwheel-levels.json"
DIST_DIR = ROOT / "app" / "dist"
BRIDGE_TOKEN = os.getenv("WORD_GAMES_BRIDGE_TOKEN", "change-me-to-a-long-secret")
PORT = int(os.getenv("WORD_GAMES_PORT", "19877"))
GAME_IDS = ("wordwheel", "hangman", "wordwich")


def _load_scores() -> dict[str, Any]:
    if not SCORES_FILE.is_file():
        return {"players": {}}
    try:
        return json.loads(SCORES_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        backup = SCORES_FILE.with_suffix(".json.bak")
        if backup.is_file():
            return json.loads(backup.read_text(encoding="utf-8"))
        return {"players": {}}


def _save_scores(data: dict[str, Any]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, indent=2)
    tmp = SCORES_FILE.with_suffix(".json.tmp")
    tmp.write_text(payload, encoding="utf-8")
    tmp.replace(SCORES_FILE)
    backup = SCORES_FILE.with_suffix(".json.bak")
    backup.write_text(payload, encoding="utf-8")


def _auth(token: Optional[str]) -> None:
    if token != BRIDGE_TOKEN:
        raise HTTPException(status_code=401, detail="unauthorized")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _git_short_rev() -> Optional[str]:
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if result.returncode == 0:
            rev = result.stdout.strip()
            return rev or None
    except (OSError, subprocess.TimeoutExpired):
        pass
    return None


def _deploy_info() -> dict[str, Any]:
    path = DATA_DIR / "deploy-info.json"
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def _find_player_by_username(data: dict[str, Any], username: str) -> Optional[str]:
    target = username.lower()
    for player_id, player in data["players"].items():
        if str(player.get("username", "")).lower() == target:
            return player_id
    return None


def _wordwheel_score(player: dict[str, Any]) -> int:
    return int((player.get("gameHighScores") or {}).get("wordwheel") or 0)


def _reconciled_wordwheel_level(player: dict[str, Any]) -> int:
    return reconcile_wordwheel_level(_wordwheel_score(player), int(player.get("wordwheelLevel") or 1))


def _player_payload(player: dict[str, Any]) -> dict[str, Any]:
    return {
        "username": player.get("username", ""),
        "totalScore": int(player.get("totalScore") or 0),
        "gameHighScores": player.get("gameHighScores") or {},
        "wordwheelLevel": _reconciled_wordwheel_level(player),
        "updatedAt": player.get("updatedAt"),
    }


def _merge_scores(existing: dict[str, Any], incoming: dict[str, Any]) -> dict[str, Any]:
    merged_high: dict[str, int] = dict(existing.get("gameHighScores") or {})
    for game_id, value in (incoming.get("gameHighScores") or {}).items():
        if game_id in GAME_IDS:
            merged_high[game_id] = max(int(merged_high.get(game_id) or 0), int(value or 0))

    merged = {
        "username": existing.get("username") or incoming.get("username"),
        "totalScore": max(int(existing.get("totalScore") or 0), int(incoming.get("totalScore") or 0)),
        "gameHighScores": merged_high,
        "wordwheelLevel": max(int(existing.get("wordwheelLevel") or 1), int(incoming.get("wordwheelLevel") or 1)),
        "updatedAt": _now(),
    }
    reconcile_player_wordwheel(merged)
    return merged


def _leaderboard_rows(data: dict[str, Any], game_id: Optional[str] = None) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for player_id, player in data["players"].items():
        username = str(player.get("username") or "").strip()
        if not username:
            continue
        if game_id:
            score = int((player.get("gameHighScores") or {}).get(game_id) or 0)
        else:
            score = int(player.get("totalScore") or 0)
        rows.append({
            "playerId": player_id,
            "username": username,
            "score": score,
            "wordwheelLevel": _reconciled_wordwheel_level(player),
        })
    rows.sort(key=lambda row: (-row["score"], row["username"].lower()))
    for index, row in enumerate(rows, start=1):
        row["rank"] = index
    return rows


app = FastAPI(title="NFG Word Games", version="0.2.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/privacy")
def privacy_page() -> FileResponse:
    return FileResponse(LEGAL_DIR / "privacy.html")


@app.get("/terms")
def terms_page() -> FileResponse:
    return FileResponse(LEGAL_DIR / "terms.html")


@app.get("/support")
def support_page() -> FileResponse:
    return FileResponse(LEGAL_DIR / "support.html")


def _reconcile_all_players(data: dict[str, Any]) -> int:
    changed = 0
    for player in data.get("players", {}).values():
        if repair_player_totals(player) or reconcile_player_wordwheel(player):
            player["updatedAt"] = _now()
            changed += 1
    if changed:
        _save_scores(data)
    return changed


@app.on_event("startup")
def _log_startup() -> None:
    data = _load_scores()
    players = len(data.get("players") or {})
    fixed = _reconcile_all_players(data)
    print(
        f"[WordGames] Ready on port {PORT} | scores={SCORES_FILE} | players={players} | reconciled={fixed}",
        flush=True,
    )


@app.get("/api/word-games/health")
def health() -> dict[str, Any]:
    data = _load_scores()
    deploy = _deploy_info()
    return {
        "ok": True,
        "app": "nfg-word-games",
        "port": PORT,
        "standalone": True,
        "crash_linked": False,
        "players": len(data.get("players") or {}),
        "scoresFile": str(SCORES_FILE),
        "gitRev": _git_short_rev(),
        "deployedAt": deploy.get("timestamp"),
    }


@app.post("/api/word-games/players/login")
def login_player(body: dict[str, Any]) -> dict[str, Any]:
    try:
        username = validate_username(str(body.get("username") or ""))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    data = _load_scores()
    player_id = _find_player_by_username(data, username)
    if player_id is None:
        player_id = str(uuid.uuid4())
        data["players"][player_id] = {
            "username": username,
            "totalScore": 0,
            "gameHighScores": {},
            "wordwheelLevel": 1,
            "updatedAt": _now(),
        }
        _save_scores(data)
        created = True
    else:
        created = False
        player = data["players"][player_id]
        if player.get("username") != username:
            player["username"] = username
            player["updatedAt"] = _now()
            _save_scores(data)

    player = data["players"][player_id]
    return {
        "ok": True,
        "created": created,
        "playerId": player_id,
        "player": _player_payload(player),
    }


@app.put("/api/word-games/players/{player_id}/username")
def update_player_username(player_id: str, body: dict[str, Any]) -> dict[str, Any]:
    try:
        username = validate_username(str(body.get("username") or ""))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    data = _load_scores()
    player = data["players"].get(player_id)
    if not player:
        raise HTTPException(status_code=404, detail="player_not_found")

    other_id = _find_player_by_username(data, username)
    if other_id and other_id != player_id:
        raise HTTPException(status_code=409, detail="username_taken")

    player["username"] = username
    player["updatedAt"] = _now()
    data["players"][player_id] = player
    _save_scores(data)
    return {"ok": True, "player": _player_payload(player)}


@app.put("/api/word-games/players/{player_id}/scores")
def put_player_scores(player_id: str, body: dict[str, Any]) -> dict[str, Any]:
    data = _load_scores()
    player = data["players"].get(player_id)
    if not player:
        raise HTTPException(status_code=404, detail="player_not_found")

    incoming = {
        "username": player.get("username"),
        "totalScore": body.get("totalScore"),
        "gameHighScores": body.get("gameHighScores"),
        "wordwheelLevel": body.get("wordwheelLevel"),
    }
    data["players"][player_id] = _merge_scores(player, incoming)
    _save_scores(data)
    return {"ok": True, "player": _player_payload(data["players"][player_id])}


@app.get("/api/word-games/leaderboard")
def overall_leaderboard(limit: int = 100) -> dict[str, Any]:
    data = _load_scores()
    rows = _leaderboard_rows(data)[: max(1, min(limit, 500))]
    return {"ok": True, "gameId": None, "entries": rows}


@app.get("/api/word-games/leaderboard/{game_id}")
def game_leaderboard(game_id: str, limit: int = 100) -> dict[str, Any]:
    if game_id not in GAME_IDS:
        raise HTTPException(status_code=400, detail="invalid_game")
    data = _load_scores()
    rows = _leaderboard_rows(data, game_id=game_id)[: max(1, min(limit, 500))]
    return {"ok": True, "gameId": game_id, "entries": rows}


@app.delete("/api/word-games/players/{player_id}")
def delete_player(player_id: str) -> dict[str, Any]:
    data = _load_scores()
    if player_id not in data["players"]:
        raise HTTPException(status_code=404, detail="player_not_found")
    del data["players"][player_id]
    _save_scores(data)
    return {"ok": True, "deleted": True, "playerId": player_id}


@app.get("/api/word-games/scores/{player_id}")
def get_scores(player_id: str) -> dict[str, Any]:
    data = _load_scores()
    player = data["players"].get(player_id)
    if not player:
        raise HTTPException(status_code=404, detail="player_not_found")
    return {"ok": True, "scores": _player_payload(player)}


@app.post("/api/word-games/scores")
def post_scores(
    body: dict[str, Any],
    x_bridge_token: Optional[str] = Header(default=None),
) -> dict[str, Any]:
    _auth(x_bridge_token)
    player_id = str(body.get("playerId") or "").strip()
    scores = body.get("scores")
    if not player_id or not isinstance(scores, dict):
        raise HTTPException(status_code=400, detail="missing_fields")
    data = _load_scores()
    existing = data["players"].get(player_id, {"username": scores.get("username", player_id)})
    data["players"][player_id] = _merge_scores(existing, scores)
    _save_scores(data)
    return {"ok": True}


def _wordwich_required() -> Any:
    if wordwich_store is None:
        raise HTTPException(status_code=503, detail="wordwich_unavailable")
    return wordwich_store


@app.get("/api/wordwich/state")
@app.get("/api/word-games/wordwich/state")
def wordwich_state() -> dict[str, Any]:
    return _wordwich_required().get_state()


@app.post("/api/wordwich/guess")
@app.post("/api/word-games/wordwich/guess")
def wordwich_guess(body: dict[str, Any]) -> dict[str, Any]:
    word = str(body.get("word") or "")
    player_id = str(body.get("playerId") or "").strip() or None
    username = str(body.get("username") or "").strip() or None
    return _wordwich_required().submit_guess(word, player_id=player_id, username=username)


@app.post("/api/wordwich/rounds")
@app.post("/api/word-games/wordwich/rounds")
def wordwich_new_round() -> dict[str, Any]:
    return _wordwich_required().new_round()


@app.get("/api/word-games/wordwheel/levels")
def wordwheel_levels() -> dict[str, Any]:
    if not LEVELS_FILE.is_file():
        raise HTTPException(status_code=404, detail="levels_not_found")
    return json.loads(LEVELS_FILE.read_text(encoding="utf-8"))


if DIST_DIR.is_dir():
    app.mount("/assets", StaticFiles(directory=DIST_DIR / "assets"), name="assets")

    @app.get("/")
    def index() -> FileResponse:
        return FileResponse(DIST_DIR / "index.html")

    @app.get("/{full_path:path}")
    def spa_fallback(full_path: str) -> FileResponse:
        if full_path.startswith("api/"):
            raise HTTPException(status_code=404)
        candidate = DIST_DIR / full_path
        if candidate.is_file():
            return FileResponse(candidate)
        return FileResponse(DIST_DIR / "index.html")
else:

    @app.get("/")
    def dev_notice() -> dict[str, str]:
        return {
            "message": "Build the frontend first: cd app && npm install && npm run build",
            "dev": "Or run Vite on :5174 while this API runs on :19877",
        }
