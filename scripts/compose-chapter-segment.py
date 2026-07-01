#!/usr/bin/env python3
"""Compose portrait chapter-map segments with pixel-perfect pad alignment."""
from __future__ import annotations

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
ASSETS = Path.home() / ".cursor/projects/Users-y666suf-Documents-nfg-word-games/assets"
PATH_SPEC = MAPS / "chapter-01-path.json"

W, H = 1024, 3584


def load_spec() -> list[tuple[float, float]]:
    data = json.loads(PATH_SPEC.read_text())
    return [(p["x"], p["y"]) for p in data["padPositions"]]


def forest_palette(chapter: int, segment: int) -> tuple[tuple[int, int, int], ...]:
    """Letter Grove greens + purple mist; shift hue per segment."""
    shift = segment * 0.04
    return (
        (int(18 + shift * 20), int(42 + segment * 3), int(28 + segment * 2)),
        (int(32 + segment * 4), int(78 + segment * 5), int(48 + segment * 3)),
        (int(55 + segment * 6), int(120 + segment * 4), int(72 + segment * 2)),
        (int(90 + segment * 3), int(55 + segment * 8), int(130 + segment * 5)),
        (int(140 + segment * 2), int(95 + segment * 6), int(180 + segment * 4)),
    )


def paint_forest_base(chapter: int, segment: int) -> Image.Image:
    rng = random.Random(chapter * 100 + segment)
    colors = forest_palette(chapter, segment)
    img = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(img)

    for y in range(H):
        t = y / H
        c1, c2, c3 = colors[0], colors[2], colors[4]
        r = int(c1[0] * (1 - t) + c2[0] * t * 0.6 + c3[0] * t * 0.4)
        g = int(c1[1] * (1 - t) + c2[1] * t * 0.7 + c3[1] * t * 0.3)
        b = int(c1[2] * (1 - t) + c2[2] * t * 0.5 + c3[2] * t * 0.5)
        draw.line([(0, y), (W, y)], fill=(r, g, b))

    # Mist bands
    mist = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for _ in range(8):
        my = rng.randint(0, H)
        mh = rng.randint(120, 280)
        mx = rng.randint(-100, W // 2)
        mw = rng.randint(W // 2, W + 100)
        md.ellipse([mx, my, mx + mw, my + mh], fill=(colors[4][0], colors[4][1], colors[4][2], 35))
    img = Image.alpha_composite(img.convert("RGBA"), mist)

    # Trees silhouettes
    td = ImageDraw.Draw(img)
    for _ in range(55):
        tx = rng.randint(-40, W + 40)
        ty = rng.randint(0, H)
        th = rng.randint(180, 520)
        tw = rng.randint(60, 160)
        trunk = (int(colors[0][0] * 0.7), int(colors[0][1] * 0.7), int(colors[0][2] * 0.7))
        td.rectangle([tx - 8, ty, tx + 8, ty + th], fill=trunk)
        td.ellipse([tx - tw, ty - th // 2, tx + tw, ty + th // 3], fill=(colors[1][0], colors[1][1], colors[1][2], 200))

    # Fireflies
    fd = ImageDraw.Draw(img)
    for _ in range(120):
        fx, fy = rng.randint(0, W), rng.randint(0, H)
        fr = rng.randint(2, 5)
        fd.ellipse([fx - fr, fy - fr, fx + fr, fy + fr], fill=(255, 240, 120, rng.randint(80, 180)))

    return img.convert("RGBA")


def blend_ai_texture(base: Image.Image, chapter: int, segment: int) -> Image.Image:
    """Layer rotated AI art as texture if available."""
    name = f"chapter-{chapter:02d}-seg-{segment:02d}.png"
    src = ASSETS / name
    if not src.exists():
        src = MAPS / name
    if not src.exists():
        return base

    art = Image.open(src).convert("RGBA")
    art = ImageOps.exif_transpose(art)
    if art.width > art.height:
        art = art.rotate(90, expand=True)

    # Tile / scale art to fill portrait canvas
    scale = max(W / art.width, H / art.height) * 1.15
    nw, nh = int(art.width * scale), int(art.height * scale)
    art = art.resize((nw, nh), Image.Resampling.LANCZOS)
    ox = (W - nw) // 2
    oy = (H - nh) // 2 + (segment - 1) * 80
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.paste(art, (ox, oy))
    layer = layer.filter(ImageFilter.GaussianBlur(radius=1))
    return Image.blend(base, layer, alpha=0.72)


def draw_path(img: Image.Image, pads: list[tuple[float, float]]) -> None:
    draw = ImageDraw.Draw(img)
    pts = [(int(x * W), int(y * H)) for x, y in pads]

    # Cobblestone path
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        steps = max(abs(x1 - x0), abs(y1 - y0)) // 8 + 1
        for s in range(steps + 1):
            t = s / steps
            px = int(x0 + (x1 - x0) * t)
            py = int(y0 + (y1 - y0) * t)
            wobble = math.sin(t * math.pi * 4) * 6
            draw.ellipse([px - 18 + wobble, py - 12, px + 18 + wobble, py + 12], fill=(110, 100, 88, 200))
    draw.line(pts, fill=(85, 78, 68, 230), width=28, joint="curve")

    # Stone pads (empty — level nodes sit here)
    for x, y in pts:
        cx, cy = int(x), int(y)
        draw.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], fill=(145, 138, 125, 240))
        draw.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], fill=(175, 168, 152, 255))
        draw.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(195, 188, 172, 255))
        draw.ellipse([cx - 34, cy - 34, cx + 34, cy + 34], outline=(90, 82, 70, 255), width=3)


def compose(chapter: int, segment: int) -> Path:
    pads = load_spec()
    img = paint_forest_base(chapter, segment)
    img = blend_ai_texture(img, chapter, segment)
    draw_path(img, pads)

    # Vignette
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    vd.ellipse([-W * 0.2, -H * 0.05, W * 1.2, H * 1.05], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(radius=180))
    dark = Image.new("RGBA", (W, H), (8, 6, 18, 0))
    dark.putalpha(ImageOps.invert(vig).point(lambda p: int(p * 0.35)))
    img = Image.alpha_composite(img, dark)

    out = MAPS / f"chapter-{chapter:02d}-seg-{segment:02d}.png"
    img.convert("RGB").save(out, "PNG", optimize=True)
    print(f"  ✅ composed {out.name} ({W}×{H})")
    return out


def main() -> None:
    print("\n🎨 Composing Chapter 01 portrait segments with aligned path pads\n")
    for seg in range(1, 6):
        compose(1, seg)

    progress = MAPS / "PROGRESS.json"
    if progress.exists():
        data = json.loads(progress.read_text())
        data["currentTask"] = "Chapter 1 recomposed — portrait + path-aligned pads"
        data["completedSegments"] = 5
        progress.write_text(json.dumps(data, indent=2) + "\n")
    print("\nDone.\n")


if __name__ == "__main__":
    main()
