# Windows bridge

Standalone PC server for NFG Word Games — **not** NFG Crash (port 3850, not 3847).

## Setup (after git pull)

```powershell
cd C:\Users\YOUR_USER\Documents\nfg-word-games\windows-bridge
copy .env.example .env
# edit .env — set BRIDGE_TOKEN
npm install
```

## Run

```powershell
start.bat
```

Opens http://127.0.0.1:3850 with the built Word Games app.

## API

- `GET /api/word-games/health`
- `GET /api/word-games/scores/:playerId`
- `POST /api/word-games/scores` (header `X-Bridge-Token`)
