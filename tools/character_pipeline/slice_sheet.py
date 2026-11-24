#!/usr/bin/env python3
"""Turn an AI pose sheet (several poses of one character on a flat chroma
background) into aligned, transparent animation frames for the app.

  python tools/character_pipeline/slice_sheet.py sheet.png out_dir \
      --names idle,windup,attack,victory [--bg 00ff00] [--height 360] [--align feet|body]

  python tools/character_pipeline/slice_sheet.py portrait.png out_dir --portrait

What it does
- keys the background (soft alpha + de-spill, any chroma colour)
- finds the N biggest pose clusters (effects such as slash arcs, flames and
  embers that float near a pose are merged into it) in reading order
- aligns all frames on one anchor so swapping frames does not jump:
    feet: bottom of the pose + horizontal centre of its lowest band (ground poses)
    body: phase correlation of the masks against frame 0 (flying poses)
- writes <name>.png per frame on a shared canvas, plus frames.json with the
  anchor (fraction of the canvas) used by the Flutter SpriteHero widget.
"""
import argparse
import json
import os

import cv2
import numpy as np
from PIL import Image


def key(img, bg, lo=0.20, hi=0.45):
    rgb = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    bg = np.array(bg, np.float32)
    dist = np.linalg.norm(rgb - bg, axis=2)
    a = np.clip((dist - lo) / (hi - lo), 0, 1)
    a = a * a * (3 - 2 * a)
    # de-spill: push the dominant background channel(s) down near the edge
    hot = bg > 0.5
    cold = ~hot
    other = rgb[..., cold].max(axis=2) if cold.any() else np.zeros(rgb.shape[:2])
    spill = np.clip(rgb[..., hot].min(axis=2) - other, 0, 1)
    k = np.clip(spill * (0.35 + 0.65 * (1 - a)), 0, 1)
    for c in np.where(hot)[0]:
        rgb[..., c] -= k * 0.9
    rgb = np.clip(rgb, 0, 1)
    # painted ground shadows come out as a darker tint of the background:
    # turn them into neutral black with matching translucency
    orig = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    if cold.any():
        tint = orig[..., hot].min(axis=2) - orig[..., cold].max(axis=2)
        shade = tint > 0.12
        lum = orig[..., hot].min(axis=2) / max(1e-3, float(bg[hot].min()))
        sa = np.clip(1.0 - lum, 0, 1) * 0.85
        rgb[shade] = 0.04
        a = np.where(shade, np.minimum(sa, 0.6), a)
    out = np.dstack([rgb, a])
    return (out * 255 + 0.5).astype(np.uint8)


def clusters(alpha, n, merge_px):
    mask = (alpha > 20).astype(np.uint8)
    grown = cv2.dilate(mask, np.ones((merge_px, merge_px), np.uint8))
    count, labels, stats, _ = cv2.connectedComponentsWithStats(grown)
    order = sorted(range(1, count), key=lambda i: -stats[i, cv2.CC_STAT_AREA])[:n]
    boxes = []
    for i in order:
        x, y, w, h = stats[i, :4]
        sub = (labels[y:y + h, x:x + w] == i) & (mask[y:y + h, x:x + w] > 0)
        boxes.append((x, y, w, h, sub))
    # reading order: rows (by vertical centre), then left to right
    boxes.sort(key=lambda b: (round((b[1] + b[3] / 2) / (alpha.shape[0] / 3)), b[0]))
    return boxes


def feet_anchor(a):
    ys, xs = np.where(a > 40)
    bottom = ys.max()
    band = ys > bottom - (ys.max() - ys.min()) * 0.12
    return float(np.median(xs[band])), float(bottom)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("src")
    p.add_argument("out")
    p.add_argument("--names", default="idle,windup,attack,victory")
    p.add_argument("--bg", default="00ff00")
    p.add_argument("--height", type=int, default=360, help="height of the tallest frame")
    p.add_argument("--align", choices=["feet", "body"], default="feet")
    p.add_argument("--merge", type=int, default=31, help="px gap still counted as one pose")
    p.add_argument("--portrait", action="store_true")
    p.add_argument("--nudge", default="", help="per-frame x,y px fixes: attack=-12:0,victory=4:0")
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    bg = [int(a.bg[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    rgba = key(Image.open(a.src), bg)

    if a.portrait:
        ys, xs = np.where(rgba[..., 3] > 8)
        img = Image.fromarray(rgba).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
        side = max(img.size)
        canvas = Image.new("RGBA", (side, side))
        canvas.paste(img, ((side - img.width) // 2, side - img.height))
        canvas = canvas.resize((512, 512), Image.LANCZOS)
        canvas.save(os.path.join(a.out, "portrait.png"), optimize=True)
        print("portrait.png 512x512")
        return

    names = a.names.split(",")
    boxes = clusters(rgba[..., 3], len(names), a.merge)
    if len(boxes) != len(names):
        raise SystemExit(f"found {len(boxes)} poses, expected {len(names)}")
    frames = []
    for x, y, w, h, sub in boxes:
        f = rgba[y:y + h, x:x + w].copy()
        f[..., 3] = np.where(sub, f[..., 3], 0)
        frames.append(f)

    nudges = {}
    for item in filter(None, a.nudge.split(",")):
        k, v = item.split("=")
        dx, dy = v.split(":")
        nudges[k] = (float(dx), float(dy))

    anchors = []
    if a.align == "feet":
        anchors = [feet_anchor(f[..., 3]) for f in frames]
    else:
        ref = frames[0][..., 3].astype(np.float32)
        for f in frames:
            m = f[..., 3].astype(np.float32)
            H, W = max(ref.shape[0], m.shape[0]), max(ref.shape[1], m.shape[1])
            r = np.zeros((H, W), np.float32); r[:ref.shape[0], :ref.shape[1]] = ref
            q = np.zeros((H, W), np.float32); q[:m.shape[0], :m.shape[1]] = m
            (dx, dy), _ = cv2.phaseCorrelate(r, q)
            anchors.append((ref.shape[1] / 2 + dx, ref.shape[0] / 2 + dy))
    anchors = [(ax + nudges.get(n, (0, 0))[0], ay + nudges.get(n, (0, 0))[1])
               for (ax, ay), n in zip(anchors, names)]

    left = max(ax for ax, _ in anchors)
    right = max(f.shape[1] - ax for f, (ax, _) in zip(frames, anchors))
    up = max(ay for _, ay in anchors)
    down = max(f.shape[0] - ay for f, (_, ay) in zip(frames, anchors))
    W, H = int(np.ceil(left + right)), int(np.ceil(up + down))
    scale = min(1.0, a.height / H)
    out_w, out_h = max(1, round(W * scale)), max(1, round(H * scale))
    for f, (ax, ay), name in zip(frames, anchors, names):
        canvas = Image.new("RGBA", (W, H))
        canvas.paste(Image.fromarray(f), (int(round(left - ax)), int(round(up - ay))))
        canvas.resize((out_w, out_h), Image.LANCZOS).save(
            os.path.join(a.out, f"{name}.png"), optimize=True)
    meta = {"frames": names, "size": [out_w, out_h],
            "anchor": [round(left / W, 4), round(up / H, 4)]}
    with open(os.path.join(a.out, "frames.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
    print(json.dumps(meta))


if __name__ == "__main__":
    main()
