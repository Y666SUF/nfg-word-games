#!/bin/bash
# One command to finish — run in Terminal.app if Cursor cannot reach GitHub
set -euo pipefail
cd "$(dirname "$0")/.."
echo "Pushing to GitHub..."
git push --force origin main
echo ""
git log -2 --oneline
echo ""
echo "Done. On Windows run:"
echo "  git fetch origin main"
echo "  git reset --hard origin/main"
echo "  windows\\run-server.bat"
