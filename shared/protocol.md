# NFG Word Games — cross-device protocol

Standalone from NFG Crash. GitHub: `Y666SUF/nfg-word-games` (same account as `Y666SUF/NFG`).

## Score sync

Local (browser): `localStorage` key `nfg-word-games-scores-v1`

PC bridge API (port **3850**):
- `GET /api/word-games/scores/:playerId`
- `POST /api/word-games/scores` + header `X-Bridge-Token`

Payload shape:
```json
{
  "playerId": "device-or-user-id",
  "scores": {
    "totalScore": 0,
    "gameHighScores": { "wordwheel": 0, "hangman": 0, "wordwich": 0 },
    "wordwheelLevel": 1
  }
}
```

## Ports

| App | Port |
|-----|------|
| NFG Crash (do not use) | 3847 |
| NFG Word Games | 3850 |
