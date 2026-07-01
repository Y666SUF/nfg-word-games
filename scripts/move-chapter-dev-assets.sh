#!/usr/bin/env bash
# Move dev-only chapter art out of the app bundle folder (not needed at runtime).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAPS="$ROOT/ios/NFGWords/Resources/ChapterMaps"
DEV="$ROOT/ios/ChapterMaps-dev"

mkdir -p "$DEV/strips" "$DEV/segments" "$DEV/paths" "$DEV/source-png"

if [[ -d "$MAPS/strips" ]]; then
  echo "==> Moving strips/ ($(du -sh "$MAPS/strips" | awk '{print $1}'))"
  rsync -a "$MAPS/strips/" "$DEV/strips/"
  rm -rf "$MAPS/strips"
fi

shopt -s nullglob
for f in "$MAPS"/chapter-*-seg-*.png; do
  echo "==> Moving $(basename "$f")"
  mv "$f" "$DEV/segments/"
done

for f in "$MAPS"/chapter-*-path.json; do
  echo "==> Moving $(basename "$f")"
  mv "$f" "$DEV/paths/"
done

for meta in PROGRESS.json README.md; do
  if [[ -f "$MAPS/$meta" ]]; then
    mv "$MAPS/$meta" "$DEV/$meta"
  fi
done

echo ""
echo "Dev assets now in: $DEV"
echo "Bundled ChapterMaps:"
du -sh "$MAPS" 2>/dev/null || true
