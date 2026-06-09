#!/usr/bin/env python3
"""Generate NFG Words app icon — puzzle tiles spelling NFG WORDS, no wheel."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "NFGWords" / "Assets.xcassets"
APP_ICON = ROOT / "AppIcon.appiconset" / "AppIcon-1024.png"
BRAND_LOGO = ROOT / "BrandLogo.imageset" / "BrandLogo.png"
FONT_ROUNDED = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"

BG = (10, 6, 22)
BG_TOP = (18, 10, 38)
BG_BOTTOM = (14, 8, 30)
PANEL = (22, 14, 42)
PANEL2 = (16, 10, 32)
TEXT = (244, 240, 255)
PURPLE = (139, 92, 246)
PURPLE_LIGHT = (167, 139, 250)
PURPLE_DARK = (91, 33, 182)
VIOLET = (124, 58, 237)
LAVENDER = (196, 181, 253)
PINK = (192, 132, 252)

# Two separate rows — not connected
ROWS = [
    ("NFG", 0),
    ("WORDS", 1),
]

WORD_GRADIENTS = [
    (PURPLE_LIGHT, PURPLE),
    (LAVENDER, VIOLET),
]


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def mix(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def draw_background(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            ty = y / max(size - 1, 1)
            px[x, y] = mix(mix(BG_TOP, BG, ty * 0.6), BG_BOTTOM, ty)
    return img


def draw_radial_glow(img: Image.Image, cx: float, cy: float, radius: float, color: tuple[int, int, int], peak: float) -> None:
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px = overlay.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            d = math.hypot(x - cx, y - cy) / radius
            if d >= 1:
                continue
            alpha = int(255 * peak * (1 - d) ** 1.8)
            px[x, y] = (*color, alpha)
    img.paste(Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB"))


def tile_colors(word_index: int) -> tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]:
    c1, c2 = WORD_GRADIENTS[word_index % len(WORD_GRADIENTS)]
    top = mix(c1, PANEL, 0.2)
    bottom = mix(c2, PANEL, 0.4)
    stroke = mix(c1, LAVENDER, 0.45)
    return top, bottom, stroke


def draw_letter_tile(
    img: Image.Image,
    x: float,
    y: float,
    size: float,
    letter: str,
    word_index: int,
) -> None:
    top, bottom, stroke = tile_colors(word_index)
    radius = size * 0.22
    isize = int(size)

    tile = Image.new("RGBA", (isize, isize), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    for py in range(isize):
        t = py / max(isize - 1, 1)
        td.line([(0, py), (isize, py)], fill=(*mix(top, bottom, t), 255))
    td.rounded_rectangle(
        [0, 0, isize - 1, isize - 1],
        radius=radius,
        outline=(*stroke, 255),
        width=max(2, int(size * 0.04)),
    )

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        [x + 3, y + 5, x + size + 3, y + size + 5],
        radius=radius,
        fill=(0, 0, 0, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.08))
    base = Image.alpha_composite(img.convert("RGBA"), shadow)
    base.paste(tile, (int(x), int(y)), tile)
    img.paste(base.convert("RGB"))

    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(FONT_ROUNDED, int(size * 0.46))
    bb = draw.textbbox((0, 0), letter, font=font)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    draw.text(
        (x + (size - tw) / 2 - bb[0], y + (size - th) / 2 - bb[1]),
        letter,
        font=font,
        fill=TEXT,
    )


def draw_tile_logo(img: Image.Image, cx: float, cy: float, cell_size: float) -> None:
    col_gap = cell_size * 0.12
    row_gap = cell_size * 0.38

    row_widths = [len(word) * cell_size + (len(word) - 1) * col_gap for word, _ in ROWS]
    max_w = max(row_widths)
    total_h = len(ROWS) * cell_size + (len(ROWS) - 1) * row_gap

    origin_y = cy - total_h / 2
    for row_idx, (word, word_index) in enumerate(ROWS):
        row_w = row_widths[row_idx]
        origin_x = cx - row_w / 2
        y = origin_y + row_idx * (cell_size + row_gap)
        for col_idx, letter in enumerate(word):
            x = origin_x + col_idx * (cell_size + col_gap)
            draw_letter_tile(img, x, y, cell_size, letter, word_index)


def generate_app_icon() -> None:
    size = 1024
    img = draw_background(size)
    draw_radial_glow(img, size / 2, size / 2, size * 0.55, PURPLE, 0.24)

    cell = size * 0.14
    draw_tile_logo(img, size / 2, size / 2, cell)

    vignette = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for i in range(24):
        inset = i * size * 0.014
        vd.rectangle([inset, inset, size - inset, size - inset], outline=(0, 0, 0, int(i * 2.2)))
    img = Image.alpha_composite(img.convert("RGBA"), vignette).convert("RGB")

    APP_ICON.parent.mkdir(parents=True, exist_ok=True)
    img.save(APP_ICON, "PNG")
    print(f"Wrote {APP_ICON}")


def generate_brand_logo() -> None:
    w, h = 1024, 640
    img = draw_background(max(w, h)).crop((0, 0, w, h))
    draw_radial_glow(img, w / 2, h / 2, w * 0.5, PURPLE, 0.22)

    cell = h * 0.22
    draw_tile_logo(img, w / 2, h / 2, cell)

    BRAND_LOGO.parent.mkdir(parents=True, exist_ok=True)
    img.save(BRAND_LOGO, "PNG")
    print(f"Wrote {BRAND_LOGO}")


if __name__ == "__main__":
    generate_app_icon()
    generate_brand_logo()
