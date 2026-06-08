#!/bin/bash
# Run in Terminal.app — push latest server + app updates to GitHub
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ Pushing NFG Word Games updates to Y666SUF/nfg-word-games"
echo ""

# Fix broken/partial .git (Cursor sandbox sometimes leaves an invalid repo)
if [ -d .git ] && ! git rev-parse --git-dir &>/dev/null; then
  echo "Removing broken .git folder..."
  rm -rf .git
fi

if [ ! -d .git ]; then
  echo "Initializing git repository..."
  # Use empty template to avoid hooks permission issues on some Mac setups
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
  git commit -m "$(cat <<'EOF'
Add leaderboard server, username login, and crossword level fixes.

Includes profanity-filtered player login, per-game and overall leaderboards,
tighter crossword placement rules, and Windows run-server helper.
EOF
)"
fi

echo ""
echo "Pushing to origin main..."
git push -u origin main

echo ""
echo "Done. On Windows, paste docs/WINDOWS_PULL_AND_RUN_SERVER.txt into Cursor."
echo "Or run: git pull origin main && windows\\run-server.bat"
