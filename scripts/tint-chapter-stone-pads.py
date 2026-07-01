#!/usr/bin/env python3
"""Tint base stone pad for each chapter theme → journey-stone-pad-NN.png"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
THEMES = MAPS / "chapter-themes.json"
BASE = MAPS / "journey-stone-pad.png"


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def tint_pad(base: Image.Image, tint: str, moss: str) -> Image.Image:
    img = base.convert("RGBA")
    arr = np.array(img, dtype=np.float32)
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    stone = a > 40

    tr, tg, tb = hex_rgb(tint)
    mr, mg, mb = hex_rgb(moss)

    # Warm stone body toward chapter tint
    for ch, tv in enumerate((tr, tg, tb)):
        plane = arr[:, :, ch]
        mean = plane[stone].mean() if stone.any() else plane.mean()
        arr[:, :, ch] = np.where(stone, plane * 0.55 + tv * 0.45, plane)

    # Moss fringe — lower portion of stone
    h = arr.shape[0]
    moss_mask = stone & (np.indices((h, arr.shape[1]))[0] > h * 0.62)
    for ch, mv in enumerate((mr, mg, mb)):
        arr[:, :, ch] = np.where(moss_mask, arr[:, :, ch] * 0.4 + mv * 0.6, arr[:, :, ch])

    out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    out = ImageEnhance.Contrast(out).enhance(1.06)
    out = out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=2))
    return out


def main() -> None:
    base = Image.open(BASE)
    themes = json.loads(THEMES.read_text())["chapters"]
    print(f"\n🪨 Tinting stone pads for {len(themes)} chapters\n")
    for ch in themes:
        cid = ch["id"]
        pad = tint_pad(base, ch["pad"]["tint"], ch["pad"]["moss"])
        out = MAPS / f"journey-stone-pad-{cid:02d}.png"
        pad.save(out, "PNG")
        print(f"  ✅ chapter {cid:02d} — {ch['name']}")
    print("\nDone.\n")


if __name__ == "__main__":
    main()
