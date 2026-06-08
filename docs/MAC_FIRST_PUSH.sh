#!/bin/bash
# Run in Terminal.app (not inside Cursor sandbox) — first-time GitHub push
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ NFG Word Games first push to Y666SUF/nfg-word-games"
echo "  Create empty repo first: https://github.com/new  (name: nfg-word-games)"
echo ""

if [ ! -d .git ]; then
  git init
  git branch -M main
fi

git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit."
else
  git commit -m "Initial NFG Word Games — standalone WordWheel hub with 1000 levels"
fi

if ! git remote get-url origin &>/dev/null; then
  git remote add origin git@github.com:Y666SUF/nfg-word-games.git
fi

echo ""
echo "Pushing to origin main..."
git push -u origin main

echo ""
echo "Done. On Windows, paste docs/WINDOWS_NFG_WORD_GAMES_SETUP.txt into Cursor."
