#!/usr/bin/env python3
"""Draw a themed journey path onto chapter scroll PNGs at level pad positions."""
from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
THEMES = MAPS / "chapter-themes.json"

W = 1024
H = 20_480
LEVELS = 50
TOP, BOTTOM = 0.025, 0.025
X_PATTERN = [0.50, 0.72, 0.50, 0.28, 0.50, 0.72, 0.50, 0.28, 0.50, 0.72]


@dataclass
class PathStyle:
    shadow_width: int = 88
    edge_width: int = 68
    body_width: int = 50
    rim_width: int = 52
    highlight_width: int = 16
    cobble_step: int = 22
    cobble_rx: tuple[int, int] = (14, 19)
    cobble_ry: tuple[int, int] = (9, 13)
    wobble: float = 8.0
    blur: float = 0.6
    edge_alpha: int = 165
    body_alpha: int = 215
    use_tiles: bool = False
    use_planks: bool = False
    use_glow: bool = False
    use_sand_grain: bool = False
    tint_blend: float = 1.0


def pad_positions() -> list[tuple[float, float]]:
    span = 1.0 - TOP - BOTTOM
    steps = LEVELS - 1
    return [(X_PATTERN[i % len(X_PATTERN)], TOP + (i / steps) * span) for i in range(LEVELS)]


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def darken(rgb: tuple[int, int, int], factor: float = 0.55) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def lighten(rgb: tuple[int, int, int], factor: float = 1.18) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(c * factor))) for c in rgb)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(3))


def theme_for(chapter: int) -> dict:
    data = json.loads(THEMES.read_text())
    for entry in data["chapters"]:
        if entry["id"] == chapter:
            return entry
    raise KeyError(f"No theme for chapter {chapter}")


def style_for_theme(theme: dict) -> PathStyle:
    path = theme.get("path", "").lower()
    scene = theme.get("scene", "").lower()
    text = f"{path} {scene}"

    if any(k in text for k in ("sand", "shore", "beach", "desert", "dune")):
        return PathStyle(
            cobble_step=18,
            cobble_rx=(10, 16),
            cobble_ry=(6, 10),
            wobble=12.0,
            blur=0.8,
            use_sand_grain=True,
            tint_blend=0.85,
        )
    if any(k in text for k in ("crystal", "ice", "frost", "diamond", "snow", "pearl")):
        return PathStyle(
            edge_width=62,
            body_width=44,
            cobble_step=26,
            cobble_rx=(8, 14),
            cobble_ry=(8, 14),
            wobble=4.0,
            blur=0.4,
            use_glow=True,
            body_alpha=190,
            tint_blend=0.7,
        )
    if any(k in text for k in ("moon", "star", "twilight", "glow", "ethereal", "cloud")):
        return PathStyle(
            edge_width=72,
            body_width=42,
            cobble_step=24,
            wobble=6.0,
            blur=1.0,
            use_glow=True,
            edge_alpha=140,
            body_alpha=175,
            tint_blend=0.75,
        )
    if any(k in text for k in ("golden", "amber", "legendary", "treasure", "sunset", "sunrise")):
        return PathStyle(
            edge_width=70,
            body_width=48,
            cobble_step=20,
            cobble_rx=(15, 20),
            cobble_ry=(10, 14),
            wobble=5.0,
            blur=0.5,
            use_glow=True,
            tint_blend=0.9,
        )
    if any(k in text for k in ("garden", "zen", "tile", "hedge", "topiary")):
        return PathStyle(
            edge_width=64,
            body_width=46,
            cobble_step=28,
            wobble=2.0,
            blur=0.3,
            use_tiles=True,
            tint_blend=0.88,
        )
    if any(k in text for k in ("boardwalk", "wood", "harbour", "forge")):
        return PathStyle(
            edge_width=66,
            body_width=44,
            cobble_step=30,
            wobble=3.0,
            blur=0.4,
            use_planks=True,
            tint_blend=0.92,
        )
    if any(k in text for k in ("lava", "ruby", "volcanic", "storm", "forge")):
        return PathStyle(
            edge_width=70,
            body_width=46,
            cobble_step=20,
            cobble_rx=(14, 18),
            wobble=7.0,
            blur=0.55,
            tint_blend=0.95,
        )
    if any(k in text for k in ("river", "creek", "stepping", "ocean", "coastal", "rainbow")):
        return PathStyle(
            cobble_step=24,
            cobble_rx=(12, 18),
            cobble_ry=(10, 15),
            wobble=10.0,
            blur=0.65,
            tint_blend=0.82,
        )
    if any(k in text for k in ("granite", "mountain", "canyon", "castle", "cobble", "flagstone", "courtyard")):
        return PathStyle(
            cobble_step=22,
            cobble_rx=(15, 20),
            cobble_ry=(10, 14),
            wobble=7.0,
            blur=0.55,
            tint_blend=1.0,
        )
    return PathStyle()


def draw_cobbles(
    draw: ImageDraw.ImageDraw,
    pts: list[tuple[int, int]],
    main: tuple[int, int, int],
    style: PathStyle,
    seed: int = 0,
) -> int:
    rng = seed
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        length = math.hypot(x1 - x0, y1 - y0)
        steps = max(3, int(length / style.cobble_step))
        for s in range(steps + 1):
            t = s / steps
            px = x0 + (x1 - x0) * t
            py = y0 + (y1 - y0) * t
            wobble = math.sin(t * math.pi * 5 + i * 0.7) * style.wobble
            rng += 1
            rx = style.cobble_rx[0] + (rng % (style.cobble_rx[1] - style.cobble_rx[0] + 1))
            ry = style.cobble_ry[0] + (rng % (style.cobble_ry[1] - style.cobble_ry[0] + 1))
            tone = lighten(main, 0.9 + (rng % 7) * 0.025)
            draw.ellipse(
                [px - rx + wobble, py - ry, px + rx + wobble, py + ry],
                fill=(*tone, 175 if not style.use_sand_grain else 140),
            )
    return rng


def draw_tiles(draw: ImageDraw.ImageDraw, pts: list[tuple[int, int]], main: tuple[int, int, int]) -> None:
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        length = math.hypot(x1 - x0, y1 - y0)
        steps = max(2, int(length / 34))
        for s in range(steps):
            t0, t1 = s / steps, (s + 1) / steps
            px0 = x0 + (x1 - x0) * t0
            py0 = y0 + (y1 - y0) * t0
            px1 = x0 + (x1 - x0) * t1
            py1 = y0 + (y1 - y0) * t1
            mx, my = (px0 + px1) / 2, (py0 + py1) / 2
            tone = lighten(main, 1.05 if s % 2 == 0 else 0.95)
            draw.rectangle([mx - 14, my - 10, mx + 14, my + 10], fill=(*tone, 200))


def draw_planks(draw: ImageDraw.ImageDraw, pts: list[tuple[int, int]], main: tuple[int, int, int]) -> None:
    for i in range(len(pts) - 1):
        x0, y0 = pts[i]
        x1, y1 = pts[i + 1]
        length = math.hypot(x1 - x0, y1 - y0)
        steps = max(2, int(length / 38))
        for s in range(steps):
            t0, t1 = s / steps, (s + 1) / steps
            px0 = x0 + (x1 - x0) * t0
            py0 = y0 + (y1 - y0) * t0
            px1 = x0 + (x1 - x0) * t1
            py1 = y0 + (y1 - y0) * t1
            mx, my = (px0 + px1) / 2, (py0 + py1) / 2
            tone = mix(main, (120, 90, 60), 0.25 if s % 2 == 0 else 0.15)
            draw.rounded_rectangle([mx - 18, my - 8, mx + 18, my + 8], radius=3, fill=(*tone, 205))


def draw_path_overlay(
    size: tuple[int, int],
    pads: list[tuple[float, float]],
    tint: tuple[int, int, int],
    moss: tuple[int, int, int],
    rim: tuple[int, int, int],
    style: PathStyle,
) -> Image.Image:
    w, h = size
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    pts = [(int(x * w), int(y * h)) for x, y in pads]

    main = mix(tint, rim, 1.0 - style.tint_blend)
    edge = mix(moss, rim, 0.35)
    shadow = darken(rim, 0.35)
    highlight = lighten(tint, 1.25 if style.use_glow else 1.18)

    draw.line(pts, fill=(*shadow, 110), width=style.shadow_width, joint="curve")
    draw.line(pts, fill=(*edge, style.edge_alpha), width=style.edge_width, joint="curve")
    draw.line(pts, fill=(*main, style.body_alpha), width=style.body_width, joint="curve")

    if style.use_planks:
        draw_planks(draw, pts, main)
    elif style.use_tiles:
        draw_tiles(draw, pts, main)
    else:
        draw_cobbles(draw, pts, main, style)

    if style.use_glow:
        glow = Image.new("RGBA", size, (0, 0, 0, 0))
        gdraw = ImageDraw.Draw(glow)
        glow_color = lighten(main, 1.35)
        gdraw.line(pts, fill=(*glow_color, 70), width=style.body_width + 18, joint="curve")
        glow = glow.filter(ImageFilter.GaussianBlur(radius=6))
        overlay = Image.alpha_composite(overlay, glow)
        draw = ImageDraw.Draw(overlay)

    draw.line(pts, fill=(*rim, 190), width=style.rim_width, joint="curve")
    draw.line(pts, fill=(*main, 225), width=max(28, style.body_width - 8), joint="curve")
    draw.line(pts, fill=(*highlight, 100 if style.use_glow else 85), width=style.highlight_width, joint="curve")

    return overlay.filter(ImageFilter.GaussianBlur(radius=style.blur))


def bake(chapter: int, *, in_place: bool = True) -> Path:
    src = MAPS / f"chapter-{chapter:02d}-full.png"
    if not src.is_file():
        raise FileNotFoundError(src)

    theme = theme_for(chapter)
    pad = theme["pad"]
    tint = hex_rgb(pad["tint"])
    moss = hex_rgb(pad["moss"])
    rim = hex_rgb(pad["rim"])
    style = style_for_theme(theme)

    base = Image.open(src).convert("RGBA")
    if base.size != (W, H):
        base = base.resize((W, H), Image.Resampling.LANCZOS)

    overlay = draw_path_overlay(base.size, pad_positions(), tint, moss, rim, style)
    merged = Image.alpha_composite(base, overlay).convert("RGB")

    out = src if in_place else MAPS / f"chapter-{chapter:02d}-full-pathed.png"
    merged.save(out, "PNG", compress_level=3)
    mb = out.stat().st_size / (1024 * 1024)
    print(f"  ✅ Ch{chapter:02d} {theme['path']} → {out.name} ({mb:.1f} MB)")
    return out


def all_chapters_with_full() -> list[int]:
    chapters: list[int] = []
    for path in sorted(MAPS.glob("chapter-*-full.png")):
        try:
            chapters.append(int(path.stem.split("-")[1]))
        except (IndexError, ValueError):
            continue
    return chapters


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "all":
        chapters = all_chapters_with_full()
    else:
        chapters = [int(sys.argv[1])] if len(sys.argv) > 1 else all_chapters_with_full()

    print(f"\n🛤  Baking themed journey paths onto {len(chapters)} chapter scroll(s)\n")
    for ch in chapters:
        try:
            bake(ch)
        except FileNotFoundError as exc:
            print(f"  ⬜ Ch{ch:02d} skipped — {exc}")
    print()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
