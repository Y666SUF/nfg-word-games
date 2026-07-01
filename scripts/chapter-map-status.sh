#!/usr/bin/env bash
# Live status + progress bar for all 40 chapter scroll backgrounds
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/chapter-map-progress.py"
