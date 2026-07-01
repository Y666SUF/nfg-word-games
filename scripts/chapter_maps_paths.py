"""Shared paths for bundled chapter art vs dev-only pipeline assets."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios" / "ChapterMaps-dev"
STRIPS = DEV / "strips"
SEGMENTS = DEV / "segments"
PATHS = DEV / "paths"
SOURCE_PNG = DEV / "source-png"

JPEG_QUALITY = 92
EXPECTED_W, EXPECTED_H = 1024, 20480
