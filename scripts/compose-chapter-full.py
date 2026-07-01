#!/usr/bin/env python3
"""Entry point: stitch HQ AI strips into seamless chapter scroll (preferred)."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
stitch = ROOT / "scripts" / "stitch-chapter-full.py"
chapter = sys.argv[1] if len(sys.argv) > 1 else "1"
subprocess.check_call([sys.executable, str(stitch), chapter] + sys.argv[2:])
