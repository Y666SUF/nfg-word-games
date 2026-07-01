#!/usr/bin/env python3
"""Stitch HQ AI strips into one seamless chapter scroll — overlap + white-trim."""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter, ImageOps
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps"
DEV = ROOT / "ios" / "ChapterMaps-dev"
ASSETS = Path.home() / ".cursor/projects/Users-y666suf-Documents-nfg-word-games/assets"
STRIPS = DEV / "strips"

W = 1024
STRIP_COUNT = 5
LEVELS = 50
TOP, BOTTOM = 0.025, 0.025
X_PATTERN = [0.50, 0.72, 0.50, 0.28, 0.50, 0.72, 0.50, 0.28, 0.50, 0.72]
SEAM_OVERLAP = 480
WHITE_TRIM = 248
WHITE_HEAL = 228


def match_overlap_colors(head: Image.Image, tail: Image.Image) -> Image.Image:
    """Shift incoming strip head colours to match previous strip tail."""
    h_arr = np.array(head.convert("RGB"), dtype=np.float32)
    t_arr = np.array(tail.convert("RGB"), dtype=np.float32)
    out = h_arr.copy()
    for ch in range(3):
        h_mean, h_std = h_arr[:, :, ch].mean(), h_arr[:, :, ch].std() + 1e-3
        t_mean, t_std = t_arr[:, :, ch].mean(), t_arr[:, :, ch].std() + 1e-3
        out[:, :, ch] = (h_arr[:, :, ch] - h_mean) * (t_std / h_std) + t_mean
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


def heal_white_regions(img: Image.Image, threshold: int = WHITE_HEAL) -> Image.Image:
    """Replace near-white letterbox pixels — column interpolate then neighbour fill."""
    arr = np.array(img.convert("RGB"), dtype=np.float32)
    h, w, _ = arr.shape
    white = (arr[:, :, 0] > threshold) & (arr[:, :, 1] > threshold) & (arr[:, :, 2] > threshold)
    if not white.any():
        return img

    # Vertical interpolation per column (fixes full-width white bands)
    idx = np.arange(h, dtype=np.float32)
    for x in range(w):
        col_white = white[:, x]
        if not col_white.any():
            continue
        valid = idx[~col_white]
        if valid.size == 0:
            continue
        for ch in range(3):
            arr[col_white, x, ch] = np.interp(idx[col_white], valid, arr[~col_white, x, ch])

    white = (arr[:, :, 0] > threshold) & (arr[:, :, 1] > threshold) & (arr[:, :, 2] > threshold)
    for _ in range(6):
        if not white.any():
            break
        new = arr.copy()
        ys, xs = np.where(white)
        for y, x in zip(ys, xs):
            nbs = []
            for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and not white[ny, nx]:
                    nbs.append(arr[ny, nx])
            if nbs:
                new[y, x] = np.mean(nbs, axis=0)
        arr = new
        white = (arr[:, :, 0] > threshold) & (arr[:, :, 1] > threshold) & (arr[:, :, 2] > threshold)

    return Image.fromarray(arr.astype(np.uint8))


def pad_positions() -> list[tuple[float, float]]:
    span = 1.0 - TOP - BOTTOM
    steps = LEVELS - 1
    return [(X_PATTERN[i % len(X_PATTERN)], TOP + (i / steps) * span) for i in range(LEVELS)]


def find_strip(chapter: int, index: int) -> Path | None:
    nn = f"{index:02d}"
    for p in (
        STRIPS / f"chapter-{chapter:02d}-strip-{nn}.png",
        STRIPS / f"chapter-{chapter:02d}" / f"chapter-{chapter:02d}-strip-{nn}.png",
        MAPS / f"chapter-{chapter:02d}-strip-{nn}.png",
        ASSETS / f"chapter-{chapter:02d}-strip-{nn}.png",
        ASSETS / f"chapter-{chapter:02d}-seg-{nn}.png",
        MAPS / f"chapter-{chapter:02d}-seg-{nn}.png",
    ):
        if p.exists():
            return p
    return None


def trim_near_white(img: Image.Image, threshold: int = WHITE_TRIM) -> Image.Image:
    """Crop letterbox / white borders from AI strips."""
    rgb = img.convert("RGB")
    bg = Image.new("RGB", rgb.size, (threshold, threshold, threshold))
    diff = ImageChops.difference(rgb, bg)
    bbox = diff.getbbox()
    if bbox:
        return rgb.crop(bbox)
    return rgb


def to_portrait_cover(img: Image.Image, tw: int, th: int) -> Image.Image:
    img = ImageOps.exif_transpose(img).convert("RGB")
    img = heal_white_regions(img)
    img = trim_near_white(img)
    if img.width > img.height:
        img = img.rotate(90, expand=True, resample=Image.Resampling.BICUBIC)
        img = heal_white_regions(img)
        img = trim_near_white(img)
    scale = max(tw / img.width, th / img.height) * 1.04
    nw, nh = int(img.width * scale), int(img.height * scale)
    img = img.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return img.crop((left, top, left + tw, top + th))


def crossfade_rows(top_strip: Image.Image, bot_strip: Image.Image, overlap: int) -> Image.Image:
    """Blend bottom overlap rows of top_strip with top overlap rows of bot_strip."""
    w = top_strip.width
    top_tail = top_strip.crop((0, top_strip.height - overlap, w, top_strip.height))
    bot_head = bot_strip.crop((0, 0, w, overlap))
    mask = Image.linear_gradient("L").resize((w, overlap))
    blended = Image.composite(bot_head, top_tail, mask)
    out = bot_strip.copy()
    out.paste(blended, (0, 0))
    return out


def harmonize_strip_top(strip: Image.Image, ref_tail: Image.Image, depth: int = 1400) -> Image.Image:
    """Gradually match top of incoming strip to previous strip's forest tones."""
    arr = np.array(strip.convert("RGB"), dtype=np.float32)
    ref = np.array(ref_tail.convert("RGB"), dtype=np.float32)
    ref_mean = ref.mean(axis=(0, 1))
    ref_std = ref.std(axis=(0, 1)) + 1e-3
    h = min(depth, arr.shape[0])
    for y in range(h):
        fade = (1.0 - y / h) ** 1.4
        row = arr[y]
        row_mean = row.mean(axis=0)
        row_std = row.std(axis=0) + 1e-3
        corrected = (row - row_mean) * (ref_std / row_std) + ref_mean
        arr[y] = row * (1 - fade) + corrected * fade
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))


def stitch(chapter: int) -> Path:
    total_h = 20_480
    sh = (total_h + (STRIP_COUNT - 1) * SEAM_OVERLAP) // STRIP_COUNT

    print(f"\n🧩 Stitching chapter-{chapter:02d}-full.png ({W}×{total_h}), overlap={SEAM_OVERLAP}px, stripH={sh}\n")

    strips: list[Image.Image] = []
    for i in range(1, STRIP_COUNT + 1):
        src = find_strip(chapter, i)
        if src is None:
            raise FileNotFoundError(f"Missing strip {i} for chapter {chapter}")
        print(f"  📎 strip {i}: {src.name} ({src.stat().st_size // 1024} KB)")
        strips.append(to_portrait_cover(Image.open(src), W, sh))

    canvas = Image.new("RGB", (W, total_h), (18, 32, 22))
    y = 0
    prev_strip: Image.Image | None = None
    for i, strip in enumerate(strips):
        if prev_strip is not None:
            ref = prev_strip.crop((0, sh - 600, W, sh))
            strip = harmonize_strip_top(strip, ref, depth=1400)
        if i == 0:
            canvas.paste(strip, (0, 0))
            y = sh - SEAM_OVERLAP
            prev_strip = strip
            continue
        tail = canvas.crop((0, y, W, y + SEAM_OVERLAP))
        head = strip.crop((0, 0, W, SEAM_OVERLAP))
        head = match_overlap_colors(head, tail)
        mask = Image.linear_gradient("L").resize((W, SEAM_OVERLAP))
        blended = Image.composite(head, tail, mask)
        canvas.paste(blended, (0, y))
        canvas.paste(strip.crop((0, SEAM_OVERLAP, W, sh)), (0, y + SEAM_OVERLAP))
        y += sh - SEAM_OVERLAP
        prev_strip = strip

    # Final pass: heal any remaining white specks in seam bands
    canvas = heal_white_regions(canvas)

    out = MAPS / f"chapter-{chapter:02d}-full.png"
    canvas.save(out, "PNG", compress_level=3)
    mb = out.stat().st_size / (1024 * 1024)
    print(f"\n  ✅ {out.name} — {mb:.1f} MB\n")

    # Bake visible path aligned to level pad positions
    bake_script = ROOT / "scripts" / "bake-chapter-path.py"
    import subprocess

    subprocess.run([sys.executable, str(bake_script), str(chapter)], check=True)

    spec = {
        "chapter": chapter,
        "width": W,
        "height": total_h,
        "levels": LEVELS,
        "stripCount": STRIP_COUNT,
        "seamOverlap": SEAM_OVERLAP,
        "padPositions": [
            {"level": i + 1, "x": x, "y": y_} for i, (x, y_) in enumerate(pad_positions())
        ],
    }
    (MAPS / f"chapter-{chapter:02d}-path.json").write_text(json.dumps(spec, indent=2) + "\n")

    progress = MAPS / "PROGRESS.json"
    data = json.loads(progress.read_text()) if progress.exists() else {}
    data["currentTask"] = f"Chapter {chapter} HQ scroll re-stitched (seamless)"
    progress.write_text(json.dumps(data, indent=2) + "\n")
    return out


def main() -> int:
    chapter = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    stitch(chapter)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
