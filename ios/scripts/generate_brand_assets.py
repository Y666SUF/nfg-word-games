#!/usr/bin/env python3
"""Generate NFG Words app icon and brand logo with purple wheel theme."""

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# NFGTheme colors (RGB)
BG = (10, 6, 22)
BG_TOP = (18, 10, 38)
BG_BOTTOM = (14, 8, 30)
PANEL2 = (16, 10, 32)
PANEL = (22, 14, 42)
TEXT = (244, 240, 255)
PURPLE = (139, 92, 246)
PURPLE_LIGHT = (167, 139, 250)
PURPLE_DARK = (91, 33, 182)
VIOLET = (124, 58, 237)
LAVENDER = (196, 181, 253)
PINK = (192, 132, 252)
CENTER_TEXT = (4, 16, 24)

OUTER_COLORS = [PURPLE_LIGHT, PURPLE, VIOLET, LAVENDER, PINK, PURPLE_LIGHT]
OUTER_LETTERS = ["N", "F", "G", "R", "D", "O"]
CENTER_LETTER = "W"

ROOT = Path(__file__).resolve().parents[1]
APP_ICON = ROOT / "NFGWords/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
BRAND_LOGO = ROOT / "NFGWords/Assets.xcassets/BrandLogo.imageset/BrandLogo.png"


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def make_background(width: int, height=None) -> Image.Image:
    height = height or width
    img = Image.new("RGB", (width, height))
    px = img.load()
    for y in range(height):
        for x in range(width):
            tx = x / max(width - 1, 1)
            ty = y / max(height - 1, 1)
            top = lerp_color(BG_TOP, BG, ty)
            bottom = lerp_color(BG, BG_BOTTOM, ty)
            base = lerp_color(top, bottom, ty)
            # diagonal depth
            base = lerp_color(base, PURPLE_DARK, (tx * 0.12 + ty * 0.08) * 0.35)
            px[x, y] = base

    # radial glow from upper-center
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gpx = glow.load()
    cx, cy = width * 0.5, height * 0.28
    max_r = max(width, height) * 0.72
    for y in range(height):
        for x in range(width):
            d = math.hypot(x - cx, y - cy) / max_r
            if d > 1:
                continue
            t = 1 - d
            alpha = int(255 * (t ** 1.6) * 0.42)
            gpx[x, y] = (PURPLE[0], PURPLE[1], PURPLE[2], alpha)

    img = Image.alpha_composite(img.convert("RGBA"), glow)

    # secondary violet bloom at wheel center area
    glow2 = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    g2px = glow2.load()
    cx2, cy2 = width * 0.5, height * 0.58
    max_r2 = min(width, height) * 0.46
    for y in range(height):
        for x in range(width):
            d = math.hypot(x - cx2, y - cy2) / max_r2
            if d > 1:
                continue
            t = 1 - d
            alpha = int(255 * (t ** 2.2) * 0.28)
            g2px[x, y] = (VIOLET[0], VIOLET[1], VIOLET[2], alpha)

    img = Image.alpha_composite(img, glow2)
    return img.convert("RGB")


def load_font(size: int, bold: bool = True):
    candidates = [
        "/System/Library/Fonts/SFCompactRounded.ttf",
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    for path in candidates:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def draw_gradient_circle(
    draw: ImageDraw.ImageDraw,
    center: tuple[float, float],
    radius: float,
    colors: list[tuple[int, int, int]],
) -> None:
    cx, cy = center
    steps = max(2, int(radius * 2))
    for i in range(steps, 0, -1):
        r = radius * i / steps
        t = i / steps
        c = lerp_color(colors[0], colors[1], 1 - t)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=c)


def draw_angular_ring(
    img: Image.Image,
    center: tuple[float, float],
    radius: float,
    width: int,
    colors: list[tuple[int, int, int]],
) -> None:
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0))
    rdraw = ImageDraw.Draw(ring)
    cx, cy = center
    segments = 180
    for i in range(segments):
        a0 = (i / segments) * 2 * math.pi
        a1 = ((i + 1) / segments) * 2 * math.pi
        color = colors[i % len(colors)]
        pts = []
        for a in (a0, a1):
            pts.extend([
                cx + math.cos(a) * (radius - width / 2),
                cy + math.sin(a) * (radius - width / 2),
                cx + math.cos(a) * (radius + width / 2),
                cy + math.sin(a) * (radius + width / 2),
            ])
        rdraw.polygon(pts, fill=(*color, 190))

    img.paste(Image.alpha_composite(img.convert("RGBA"), ring).convert("RGB"))


def draw_wheel(
    img: Image.Image,
    center: tuple[float, float],
    outer_radius: float,
    *,
    show_connectors: bool = False,
) -> None:
    draw = ImageDraw.Draw(img)
    cx, cy = center

    # soft wheel glow disk
    glow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow_layer)
    glow_r = outer_radius * 1.08
    for i in range(int(glow_r), 0, -2):
        t = i / glow_r
        alpha = int(70 * (1 - t) ** 2)
        gdraw.ellipse(
            (cx - i, cy - i, cx + i, cy + i),
            fill=(PURPLE[0], PURPLE[1], PURPLE[2], alpha),
        )
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow_layer).convert("RGB"))
    draw = ImageDraw.Draw(img)

    ring_radius = outer_radius * 0.97
    draw_angular_ring(
        img,
        center,
        ring_radius,
        max(4, int(outer_radius * 0.018)),
        [PURPLE_LIGHT, PURPLE, VIOLET, PURPLE_DARK, PURPLE_LIGHT],
    )
    draw = ImageDraw.Draw(img)

    letter_orbit = outer_radius * 0.68
    outer_circle_r = outer_radius * 0.135
    center_circle_r = outer_radius * 0.175

    if show_connectors:
        for i in range(len(OUTER_LETTERS)):
            angle = (i / len(OUTER_LETTERS)) * 2 * math.pi - math.pi / 2
            ox = cx + math.cos(angle) * letter_orbit
            oy = cy + math.sin(angle) * letter_orbit
            draw.line((cx, cy, ox, oy), fill=(*PURPLE_LIGHT, 80), width=max(2, int(outer_radius * 0.012)))

    # outer letter tiles
    for i, letter in enumerate(OUTER_LETTERS):
        angle = (i / len(OUTER_LETTERS)) * 2 * math.pi - math.pi / 2
        ox = cx + math.cos(angle) * letter_orbit
        oy = cy + math.sin(angle) * letter_orbit
        accent = OUTER_COLORS[i % len(OUTER_COLORS)]

        tile = Image.new("RGBA", img.size, (0, 0, 0, 0))
        tdraw = ImageDraw.Draw(tile)
        tdraw.ellipse(
            (ox - outer_circle_r, oy - outer_circle_r, ox + outer_circle_r, oy + outer_circle_r),
            fill=(*PANEL2, 255),
        )
        tdraw.ellipse(
            (ox - outer_circle_r, oy - outer_circle_r, ox + outer_circle_r, oy + outer_circle_r),
            outline=(*accent, 220),
            width=max(3, int(outer_radius * 0.014)),
        )
        img.paste(Image.alpha_composite(img.convert("RGBA"), tile).convert("RGB"))
        draw = ImageDraw.Draw(img)

        font = load_font(int(outer_circle_r * 1.15))
        bbox = draw.textbbox((0, 0), letter, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(
            (ox - tw / 2, oy - th / 2 - outer_circle_r * 0.08),
            letter,
            fill=TEXT,
            font=font,
        )

    # center tile with gradient
    center_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    cdraw = ImageDraw.Draw(center_layer)
    steps = int(center_circle_r * 2)
    for i in range(steps, 0, -1):
        r = center_circle_r * i / steps
        t = i / steps
        c = lerp_color(PURPLE_LIGHT, PURPLE, 1 - t)
        cdraw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*c, 255))
    cdraw.ellipse(
        (cx - center_circle_r, cy - center_circle_r, cx + center_circle_r, cy + center_circle_r),
        outline=(*LAVENDER, 255),
        width=max(4, int(outer_radius * 0.016)),
    )
    img.paste(Image.alpha_composite(img.convert("RGBA"), center_layer).convert("RGB"))
    draw = ImageDraw.Draw(img)

    font = load_font(int(center_circle_r * 1.05))
    bbox = draw.textbbox((0, 0), CENTER_LETTER, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(
        (cx - tw / 2, cy - th / 2 - center_circle_r * 0.06),
        CENTER_LETTER,
        fill=CENTER_TEXT,
        font=font,
    )


def draw_nfg_wordmark(draw: ImageDraw.ImageDraw, width: int, y: int, scale: float = 1.0) -> None:
    nfg_font = load_font(int(118 * scale))
    words_font = load_font(int(34 * scale))

    nfg = "NFG"
    bbox = draw.textbbox((0, 0), nfg, font=nfg_font)
    tw = bbox[2] - bbox[0]
    x = (width - tw) / 2

    # subtle gradient effect via layered text
    for i, color in enumerate([PURPLE_LIGHT, TEXT]):
        offset = i * 0
        draw.text((x, y + offset), nfg, fill=color if i else PURPLE_LIGHT, font=nfg_font)
    draw.text((x, y), nfg, fill=TEXT, font=nfg_font)

    words = "WORDS"
    wbbox = draw.textbbox((0, 0), words, font=words_font)
    ww = wbbox[2] - wbbox[0]
    wx = (width - ww) / 2
    wy = y + int(108 * scale)
    draw.text((wx, wy), words, fill=PURPLE_LIGHT, font=words_font)

    line_y = wy + int(38 * scale)
    line_w = int(52 * scale)
    gap = int(14 * scale)
    mid = width / 2
    lw = max(2, int(2 * scale))
    draw.line((mid - gap - line_w, line_y, mid - gap, line_y), fill=LAVENDER, width=lw)
    draw.line((mid + gap, line_y, mid + gap + line_w, line_y), fill=LAVENDER, width=lw)
    dot_r = max(3, int(4 * scale))
    for dx in (-gap, gap):
        draw.ellipse((mid + dx - dot_r, line_y - dot_r, mid + dx + dot_r, line_y + dot_r), fill=LAVENDER)


def generate_app_icon() -> None:
    size = 1024
    img = make_background(size, size)
    draw = ImageDraw.Draw(img)

    # compact wordmark at top
    draw_nfg_wordmark(draw, size, y=72, scale=0.95)

    # dominant full-bleed wheel
    draw_wheel(img, center=(size / 2, size * 0.58), outer_radius=size * 0.41, show_connectors=False)

    img.save(APP_ICON, "PNG", optimize=True)
    print(f"Wrote {APP_ICON}")


def generate_brand_logo() -> None:
    # portrait brand asset for in-app use
    w, h = 1024, 1536
    img = make_background(w, h)

    draw = ImageDraw.Draw(img)
    draw_nfg_wordmark(draw, w, y=120, scale=1.35)
    draw_wheel(img, center=(w / 2, h * 0.58), outer_radius=w * 0.38, show_connectors=True)

    img.save(BRAND_LOGO, "PNG", optimize=True)
    print(f"Wrote {BRAND_LOGO}")


if __name__ == "__main__":
    generate_app_icon()
    generate_brand_logo()
