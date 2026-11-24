#!/usr/bin/env python3
"""Step 2 of the character pipeline: turn an AI render on a flat chroma
background (default magenta #FF00FF) into a clean transparent PNG.

  python tools/character_pipeline/key_background.py raw.png out.png [--height 900]

- soft alpha from the colour distance to the background (no hard jaggies)
- de-spill: removes the magenta fringe on the outline
- crops to the character and adds a small transparent margin
"""
import argparse

import numpy as np
from PIL import Image


def key(img, bg=(1.0, 0.0, 1.0), lo=0.18, hi=0.42):
    rgb = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    bg = np.array(bg, np.float32)
    dist = np.linalg.norm(rgb - bg, axis=2)
    a = np.clip((dist - lo) / (hi - lo), 0, 1)
    a = a * a * (3 - 2 * a)  # smoothstep
    # de-spill: magenta = red & blue above green
    spill = np.clip(np.minimum(rgb[..., 0], rgb[..., 2]) - rgb[..., 1], 0, 1)
    edge = 1.0 - a
    k = np.clip(spill * (0.35 + 0.65 * edge), 0, 1)
    rgb[..., 0] -= k * 0.9
    rgb[..., 2] -= k * 0.9
    rgb = np.clip(rgb, 0, 1)
    out = np.dstack([rgb, a])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


def crop(img, margin=0.04):
    a = np.asarray(img)[..., 3]
    ys, xs = np.where(a > 8)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    m = int(max(x1 - x0, y1 - y0) * margin)
    return img.crop((max(0, x0 - m), max(0, y0 - m),
                     min(img.width, x1 + m), min(img.height, y1 + m)))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("dst")
    p.add_argument("--height", type=int, default=900)
    a = p.parse_args()
    img = crop(key(Image.open(a.src)))
    if img.height > a.height:
        w = round(img.width * a.height / img.height)
        img = img.resize((w, a.height), Image.LANCZOS)
    img.save(a.dst, optimize=True)
    print(f"{a.dst}: {img.width}x{img.height}")


if __name__ == "__main__":
    main()
