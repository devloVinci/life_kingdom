#!/usr/bin/env python3
"""2D cutout (skeletal) rig for Life Kingdom heroes.

A hero is a set of painted pieces (head, torso, upper/lower arms and legs,
weapon...) attached to a bone hierarchy. Clips key bone rotation (deg,
clockwise), translation (px, in parent space) and scale over time, with
smooth interpolation, so motion is continuous at any frame rate.

  python cutout.py preview RIG_DIR OUT_DIR [--scale 0.4] [--fps 30]
      renders every clip to a GIF + a bind-pose PNG (same math as the app)

rig.json
  bones:  [{name, parent, x, y, z?}]       x,y = joint position in parent space
  pieces: [{file, bone, px, py, z}]          px,py = bone joint inside the image
  clips:  {name: {dur, loop, keys: {bone: {rot|x|y|sx|sy: [[t, v, ease?], ...]}},
                  fx?: [{type, t0, t1, ...}]}}
"""
import argparse
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def ease_fn(name):
    if name == "linear":
        return lambda u: u
    if name == "in":
        return lambda u: u * u * u
    if name == "out":
        return lambda u: 1 - (1 - u) ** 3
    if name == "back":  # overshoot, for snappy hits
        c = 1.9
        return lambda u: 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2
    return lambda u: u * u * (3 - 2 * u)  # smooth


def sample(track, t, loop, dur):
    if not track:
        return None
    if len(track) == 1:
        return track[0][1]
    if t <= track[0][0]:
        if not loop:
            return track[0][1]
    for i in range(len(track) - 1):
        t0, v0 = track[i][0], track[i][1]
        t1, v1 = track[i + 1][0], track[i + 1][1]
        if t0 <= t <= t1:
            e = track[i + 1][2] if len(track[i + 1]) > 2 else "smooth"
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return v0 + (v1 - v0) * ease_fn(e)(u)
    return track[-1][1]


def pose(rig, clip, t):
    """World 3x3 matrix per bone."""
    keys = clip.get("keys", {}) if clip else {}
    loop = clip.get("loop", True) if clip else True
    dur = clip.get("dur", 1) if clip else 1
    if clip and loop:
        t = t % dur
    mats = {}
    for b in rig["bones"]:
        k = keys.get(b["name"], {})
        def g(ch, d):
            v = sample(k.get(ch), t, loop, dur)
            return d if v is None else v
        rot = math.radians(g("rot", 0))
        tx, ty = b["x"] + g("x", 0), b["y"] + g("y", 0)
        sx, sy = g("sx", 1), g("sy", 1)
        c, s = math.cos(rot), math.sin(rot)
        local = np.array([[c * sx, -s * sy, tx], [s * sx, c * sy, ty], [0, 0, 1]])
        p = b.get("parent")
        mats[b["name"]] = local if p is None else mats[p] @ local
    return mats, t


def render(rig, images, clip, t, size, origin, scale):
    mats, tt = pose(rig, clip, t)
    W, H = size
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    view = np.array([[scale, 0, origin[0]], [0, scale, origin[1]], [0, 0, 1]])
    for p in sorted(rig["pieces"], key=lambda p: p["z"]):
        img = images[p["file"]]
        m = view @ mats[p["bone"]] @ np.array([[1, 0, -p["px"]], [0, 1, -p["py"]], [0, 0, 1]])
        inv = np.linalg.inv(m)
        tile = img.transform((W, H), Image.AFFINE, tuple(inv[:2].flatten()),
                             resample=Image.BICUBIC)
        canvas.alpha_composite(tile)
    for f in (clip or {}).get("fx", []):
        _fx(canvas, f, tt, mats, view)
    return canvas


def _fx(canvas, f, t, mats, view):
    if not (f["t0"] <= t <= f["t1"]):
        return
    u = (t - f["t0"]) / (f["t1"] - f["t0"])
    if f["type"] == "arc":  # slash smear around a bone
        m = view @ mats[f["bone"]]
        cx, cy = m[0, 2], m[1, 2]
        r = f["r"] * view[0, 0]
        layer = Image.new("RGBA", canvas.size)
        d = ImageDraw.Draw(layer)
        a0 = f["a0"] + (f["a1"] - f["a0"]) * max(0, u - 0.35)
        a1 = f["a0"] + (f["a1"] - f["a0"]) * min(1, u * 1.6)
        alpha = int(255 * (1 - u) ** 0.6)
        for i, (w, col) in enumerate([(26, (150, 70, 255)), (14, (210, 160, 255)), (5, (255, 255, 255))]):
            d.arc([cx - r, cy - r * f.get("squash", 0.5), cx + r, cy + r * f.get("squash", 0.5)],
                  a0, a1, fill=col + (alpha,), width=max(1, int(w * view[0, 0] * 2.2)))
        canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.2)))
    elif f["type"] == "dust":
        m = view @ mats[f["bone"]]
        cx, cy = m[0, 2], m[1, 2] + f.get("dy", 0) * view[0, 0]
        d = ImageDraw.Draw(canvas)
        for i in range(10):
            ang = i / 10 * 2 * math.pi
            rr = (20 + 120 * u) * view[0, 0] * 2.2
            x, y = cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.35
            s = (14 * (1 - u) + 3) * view[0, 0] * 2.2
            d.ellipse([x - s, y - s * 0.7, x + s, y + s * 0.7], fill=(205, 190, 160, int(200 * (1 - u))))


def load(rig_dir):
    rig = json.load(open(os.path.join(rig_dir, "rig.json")))
    images = {p["file"]: Image.open(os.path.join(rig_dir, p["file"])).convert("RGBA")
              for p in rig["pieces"]}
    return rig, images


def preview(rig_dir, out, scale, fps, bg):
    os.makedirs(out, exist_ok=True)
    rig, images = load(rig_dir)
    W, H = rig["preview"]["size"]
    W, H = int(W * scale), int(H * scale)
    org = (rig["preview"]["origin"][0] * scale, rig["preview"]["origin"][1] * scale)
    render(rig, images, None, 0, (W, H), org, scale).save(os.path.join(out, "bind.png"))
    for name, clip in rig["clips"].items():
        n = max(2, int(round(clip["dur"] * fps)))
        frames = []
        for i in range(n):
            t = i / fps
            fr = render(rig, images, clip, t, (W, H), org, scale)
            back = Image.new("RGBA", (W, H), bg)
            sh = ImageDraw.Draw(back)
            sh.ellipse([org[0] - 110 * scale * 2.2, org[1] + 380 * scale - 18, org[0] + 110 * scale * 2.2,
                        org[1] + 380 * scale + 18], fill=(0, 0, 0, 70))
            back.alpha_composite(fr)
            frames.append(back.convert("RGB"))
        frames[0].save(os.path.join(out, f"{name}.gif"), save_all=True, append_images=frames[1:],
                       duration=int(1000 / fps), loop=0)
        print(name, n, "frames")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["preview"])
    ap.add_argument("rig_dir")
    ap.add_argument("out")
    ap.add_argument("--scale", type=float, default=0.4)
    ap.add_argument("--fps", type=int, default=30)
    a = ap.parse_args()
    preview(a.rig_dir, a.out, a.scale, a.fps, (104, 168, 72, 255))
