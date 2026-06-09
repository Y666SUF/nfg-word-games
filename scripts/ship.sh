#!/bin/bash
# Mac one-command push — Windows auto-pulls if install-auto-update-task was run once
set -euo pipefail
cd "$(dirname "$0")/.."

MSG="${1:-Ship NFG Word Games server and app updates.}"

echo "→ Shipping NFG Word Games to origin main"
echo ""

# Fix broken/partial .git (Cursor sandbox sometimes leaves an invalid repo)
if [ -d .git ] && ! git rev-parse --git-dir &>/dev/null; then
  echo "Removing broken .git folder..."
  rm -rf .git
fi

if [ ! -d .git ]; then
  echo "Initializing git repository..."
  EMPTY_TEMPLATE="$(mktemp -d)"
  git init --initial-branch=main --template="$EMPTY_TEMPLATE"
  rmdir "$EMPTY_TEMPLATE" 2>/dev/null || true
fi

if ! git remote get-url origin &>/dev/null; then
  git remote add origin git@github.com:Y666SUF/nfg-word-games.git
fi

git add -A
if git diff --cached --quiet; then
  echo "Nothing new to commit."
else
  git commit -m "$MSG"
fi

echo ""
echo "Pushing to origin main..."
git push -u origin main

echo ""
echo "Done. Windows will auto-pull within 5 minutes if install-auto-update-task was run once."
echo "Verify: curl -s https://y666suf.com/api/word-games/health | python3 -m json.tool"
