#!/bin/bash
# Run in Terminal.app when push is rejected (remote has different history)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ NFG Word Games — fetch, merge remote, push"
echo ""

git fetch origin main

echo ""
echo "Commits on GitHub you don't have locally:"
git log --oneline HEAD..origin/main 2>/dev/null || true

echo ""
echo "Commits on your Mac not on GitHub yet:"
git log --oneline origin/main..HEAD 2>/dev/null || true

echo ""
echo "Merging origin/main (allows unrelated histories if needed)..."
git pull origin main --no-rebase --allow-unrelated-histories -m "Merge GitHub main with standalone NFG Word Games"

# If merge left conflicts, prefer Mac standalone server files
if git diff --name-only --diff-filter=U | grep -q .; then
  echo ""
  echo "Resolving conflicts — keeping Mac versions of core server files..."
  for f in server.py profanity.py requirements.txt windows/run-server.bat; do
    if git diff --name-only --diff-filter=U | grep -qx "$f"; then
      git checkout --ours "$f"
      git add "$f"
    fi
  done
  git add -A
  git commit -m "Merge remote main; keep standalone NFG Word Games server" || true
fi

echo ""
echo "Pushing to origin main..."
git push origin main

echo ""
echo "Done. Latest commit:"
git log -1 --oneline
echo ""
echo "On Windows: git pull origin main"
