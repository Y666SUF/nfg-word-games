# NFG Word Games

Standalone word games hub — **completely separate from NFG Crash** (shared colour scheme only).

## Features

- **Centralized scoring** across all word games
- **Per-game high scores** (WordWheel, Hangman, Wordwich)
- **NFG WordWheel** — wheel letters + mandatory centre letter + Wordscapes-style crossword grid
- **1000 levels** with progressive difficulty
- **Bonus points** for valid dictionary words not in the puzzle
- **Windows bridge** placeholder for your PC companion file (no NFG Crash link)

## Quick start

### Python server (PC / Mac — port 19877)

```bash
cd ~/Documents/nfg-word-games
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m uvicorn server:app --host 0.0.0.0 --port 19877
```

**Windows one-liner:** `windows\run-server.bat` after `git pull`

**API endpoints:** health, player login, score sync, overall + per-game leaderboards (`server.py` + `profanity.py`)

Open http://127.0.0.1:19877

Build the frontend first for the full UI:

```bash
cd app && npm install && npm run build
```

### Dev (hot reload UI)

```bash
cd app && npm run dev
```

Vite on http://localhost:5174 — API on http://127.0.0.1:19877

### iOS app (native SwiftUI — recommended on iPhone)

```bash
open ~/Documents/nfg-word-games/ios/NFGWords.xcodeproj
```

Build & run in Xcode. See `ios/README.md`.

## Regenerate levels

```bash
npm run generate:levels
cp ../data/wordwheel-levels.json src/data/wordwheel-levels.json
```

## GitHub

Same account as NFG Crash: **Y666SUF**

- Repo: https://github.com/Y666SUF/nfg-word-games
- SSH: `git@github.com:Y666SUF/nfg-word-games.git`
- HTTPS: `https://github.com/Y666SUF/nfg-word-games.git`

First push from Mac: see `docs/MAC_GITHUB_PUSH.md`

## Windows PC

Copy-paste prompts (same style as NFG Crash):

```bash
pbcopy < ~/Documents/nfg-word-games/docs/WINDOWS_PULL_AND_RUN_SERVER.txt    # pull + run server
pbcopy < ~/Documents/nfg-word-games/docs/WINDOWS_NFG_WORD_GAMES_SETUP.txt   # first time
pbcopy < ~/Documents/nfg-word-games/docs/WINDOWS_NFG_WORD_GAMES_SYNC.txt    # updates
```

Index: `docs/WINDOWS_CURSOR_PASTE.txt`

## Project layout

- `app/` — React + Vite standalone app
- `data/` — generated WordWheel levels (1000)
- `scripts/` — level generator
- `windows-bridge/` — Windows PC server (port **3850**, not Crash 3847)
- `shared/` — cross-device protocol notes
- `docs/` — Mac push + Windows Cursor prompts
