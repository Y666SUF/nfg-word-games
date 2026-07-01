#!/usr/bin/env python3
"""Remove green/white backgrounds from journey stone pad → transparent PNG."""
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ios" / "NFGWords" / "Resources" / "ChapterMaps" / "journey-stone-pad.png"
SRCS = [
    Path.home() / ".cursor/projects/Users-y666suf-Documents-nfg-word-games/assets/journey-stone-pad.png",
    OUT,
]


def load_src() -> Image.Image:
    for p in SRCS:
        if p.exists():
            return Image.open(p)
    raise FileNotFoundError("journey-stone-pad.png not found")


def make_transparent(img: Image.Image) -> Image.Image:
    img = ImageOps.exif_transpose(img).convert("RGBA")
    arr = np.array(img)

    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]

    # Dark forest-green backdrop from AI
    green_bg = (g > r + 8) & (g > b + 8) & (g > 35) & (r < 120)
    # Near-white letterbox
    white_bg = (r > 225) & (g > 225) & (b > 225)
    # Very dark outer vignette
    dark_bg = (r < 25) & (g < 40) & (b < 30)

    transparent = green_bg | white_bg | dark_bg

    # Feather edges for smooth blend on map
    from PIL import ImageFilter

    mask = Image.fromarray((~transparent).astype(np.uint8) * 255, mode="L")
    mask = mask.filter(ImageFilter.GaussianBlur(radius=1.5))
    arr[:, :, 3] = np.array(mask)

    result = Image.fromarray(arr, mode="RGBA")
    bbox = result.getbbox()
    if bbox:
        result = result.crop(bbox)

    # Square pad centred on stone
    side = max(result.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - result.width) // 2
    oy = (side - result.height) // 2
    square.paste(result, (ox, oy), result)
    return square.resize((512, 512), Image.Resampling.LANCZOS)


def main() -> None:
    img = make_transparent(load_src())
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print(f"✅ Transparent stone pad → {OUT} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
