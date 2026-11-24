#!/usr/bin/env python3
"""Life Kingdom character rig kit (step 3 + 4 of the pipeline).

  build:   python tools/character_pipeline/rigkit.py build SPEC.json ART.png OUT_DIR
           -> OUT_DIR/<slug>.png + OUT_DIR/rig.json (mesh, bone weights, clips)
  preview: python tools/character_pipeline/rigkit.py preview OUT_DIR/rig.json PREVIEW_DIR
           -> one GIF per clip + a contact sheet, rendered with exactly the same
              math as the Flutter runtime (lib/core/characters/skinned/).

Rig model (same as Spine/Rive "mesh + bones"): the painted character is
covered by a triangle mesh; every vertex is weighted to up to 4 bones.
An animation clip keys per-bone rot (deg, clockwise), tx/ty (px), sx/sy.
Bone skin matrix:  M_b = M_parent * T(head + t) * R(rot) * S(sx, sy) * T(-head)
Vertex:            v' = sum_i w_i * M_i * v
"""
import json
import math
import os
import shutil
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

MAX_INF = 4

# ---------------------------------------------------------------- build ----


def _assign_regions(pts, regions, bone_index):
    """Bone index per point: last containing region wins, else nearest."""
    out = np.full(len(pts), -1, np.int32)
    best = np.full(len(pts), -1e9)
    polys = [(bone_index[name], np.array(poly, np.float32).reshape(-1, 1, 2))
             for name, poly in regions]
    for i, (x, y) in enumerate(pts):
        inside = -1
        for b, poly in polys:
            d = cv2.pointPolygonTest(poly, (float(x), float(y)), True)
            if d >= 0:
                inside = b
            elif inside < 0 and d > best[i]:
                best[i] = d
                out[i] = b
        if inside >= 0:
            out[i] = inside
    return out


def _layer_mask(spec_layer, rgba):
    H, W = rgba.shape[:2]
    m = np.zeros((H, W), np.uint8)
    if "polygon" in spec_layer:
        cv2.fillPoly(m, [np.array(spec_layer["polygon"], np.int32)], 255, cv2.LINE_AA)
    else:
        e = spec_layer["ellipse"]
        cv2.ellipse(m, tuple(e["c"]), tuple(e["r"]), 0, 0, 360, 255, -1, cv2.LINE_AA)
    if spec_layer.get("colorKeep") == "metal":
        hsv = cv2.cvtColor(rgba[..., :3], cv2.COLOR_RGB2HSV).astype(np.int32)
        h, sat, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
        steel = (sat < 70) & (v > 120)
        gold = (h >= 12) & (h <= 32) & (sat > 110) & (v > 140)
        keep = (steel | gold).astype(np.uint8) * 255
        keep = cv2.morphologyEx(keep, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        keep = cv2.dilate(keep, np.ones((3, 3), np.uint8))
        m = cv2.min(m, keep)
        # keep only the largest connected piece
        n, lab, stats, _ = cv2.connectedComponentsWithStats((m > 127).astype(np.uint8))
        if n > 1:
            big = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
            m[lab != big] = 0
    return cv2.GaussianBlur(m, (3, 3), 0)


def _grid_mesh(alpha, x0, y0, x1, y1, cell):
    """Grid vertices covering visible pixels of alpha inside the box."""
    xs = list(range(x0, x1, cell)) + [x1]
    ys = list(range(y0, y1, cell)) + [y1]
    occ = np.zeros((len(ys) - 1, len(xs) - 1), np.uint8)
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            occ[j, i] = alpha[ys[j]:ys[j + 1] + 1, xs[i]:xs[i + 1] + 1].max() > 0
    occ = cv2.dilate(occ, np.ones((3, 3), np.uint8)) > 0
    return xs, ys, occ


def _mesh(xs, ys, occ, weight_fn):
    vid = {}
    positions, weights, tris = [], [], []

    def vert(i, j):
        if (i, j) not in vid:
            vid[(i, j)] = len(positions)
            positions.append((float(xs[i]), float(ys[j])))
            weights.append(weight_fn(i, j))
        return vid[(i, j)]

    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            if occ[j, i]:
                a, b, c, d = vert(i, j), vert(i + 1, j), vert(i + 1, j + 1), vert(i, j + 1)
                tris += [a, b, c, a, c, d]
    flat_w = []
    for inf in weights:
        inf = (inf + [(0, 0.0)] * MAX_INF)[:MAX_INF]
        for b, w in inf:
            flat_w += [int(b), round(float(w), 4)]
    return {"positions": [round(v, 1) for p in positions for v in p],
            "triangles": tris, "influences": MAX_INF, "weights": flat_w}


def build(spec_path, art_path, out_dir):
    spec = json.load(open(spec_path))
    art = np.asarray(Image.open(art_path).convert("RGBA")).copy()
    H, W = art.shape[:2]
    cell = spec.get("cell", 14)
    bones = spec["bones"]
    bidx = {b["name"]: i for i, b in enumerate(bones)}
    slug = spec["slug"]
    os.makedirs(out_dir, exist_ok=True)

    # 1) cut rigid props into their own layers; fill the body behind them
    body = art.astype(np.float32)
    body[..., :3] *= body[..., 3:4] / 255  # premultiplied for clean inpainting
    hole = np.zeros((H, W), np.uint8)
    prop_layers = []
    for L in spec.get("layers", []):
        m = _layer_mask(L, art).astype(np.float32) / 255
        piece = art.copy()
        piece[..., 3] = (art[..., 3] * m).astype(np.uint8)
        ys_, xs_ = np.nonzero(piece[..., 3] > 4)
        x0, y0 = max(0, xs_.min() - 2), max(0, ys_.min() - 2)
        x1, y1 = min(W, xs_.max() + 3), min(H, ys_.max() + 3)
        fname = f"{slug}_{L['name']}.png"
        Image.fromarray(piece[y0:y1, x0:x1], "RGBA").save(os.path.join(out_dir, fname), optimize=True)
        hole = cv2.max(hole, (m > 0.02).astype(np.uint8) * 255)
        prop_layers.append((L, fname, (x0, y0, x1, y1), piece[..., 3]))
    if prop_layers:
        hole = cv2.dilate(hole, np.ones((9, 9), np.uint8))
        # fill the hidden area by extending the nearest visible pixels
        # (sharp, plausible continuation instead of a blurry smear)
        _, labels = cv2.distanceTransformWithLabels(
            (hole == 0).astype(np.uint8) ^ 1, cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
        src = np.zeros(labels.max() + 1, np.int64)
        oy, ox = np.nonzero(hole == 0)
        src[labels[oy, ox]] = oy * W + ox
        flat = body.reshape(-1, 4)
        hy, hx = np.nonzero(hole > 0)
        filled = body.copy()
        filled[hy, hx] = flat[src[labels[hy, hx]]]
        soft = cv2.GaussianBlur(filled, (0, 0), 2.0)
        filled[hy, hx] = soft[hy, hx]
        rgb, a = filled[..., :3], filled[..., 3]
        af = a.astype(np.float32)[..., None] / 255
        unp = np.where(af > 0.01, rgb.astype(np.float32) / np.maximum(af, 0.01), 0)
        body = np.dstack([np.clip(unp, 0, 255), a]).astype(np.uint8)
    else:
        body = art
    body_name = f"{slug}_body.png"
    Image.fromarray(body, "RGBA").save(os.path.join(out_dir, body_name), optimize=True)

    # 2) body mesh with smooth (blurred) bone weights
    xs, ys, occ = _grid_mesh(body[..., 3], 0, 0, W, H, cell)
    grid_pts = [(x, y) for y in ys for x in xs]
    owner = _assign_regions(grid_pts, spec["regions"], bidx).reshape(len(ys), len(xs))
    wgrid = np.stack([cv2.GaussianBlur((owner == b).astype(np.float32), (0, 0), sigmaX=0.85)
                      for b in range(len(bones))])

    def body_w(i, j):
        w = wgrid[:, j, i]
        top = np.argsort(-w)[:MAX_INF]
        tw = w[top] / max(w[top].sum(), 1e-6)
        return [(b, x) for b, x in zip(top, tw)]

    layers = [{"name": "body", "image": body_name, "offset": [0, 0],
               "mesh": _mesh(xs, ys, occ, body_w)}]
    order = spec.get("drawOrder")
    for L, fname, (x0, y0, x1, y1), alpha in prop_layers:
        lxs, lys, locc = _grid_mesh(alpha, x0, y0, x1, y1, cell * 2)
        b = bidx[L["bone"]]
        layers.append({"name": L["name"], "image": fname, "offset": [int(x0), int(y0)],
                       "mesh": _mesh(lxs, lys, locc, lambda i, j, b=b: [(b, 1.0)])})
    if order:
        layers.sort(key=lambda l: order.index(l["name"]))

    lx, ly = spec["lidSample"]
    patch = art[ly - 2:ly + 3, lx - 2:lx + 3, :3].reshape(-1, 3)
    lid = np.median(patch, axis=0).astype(int)

    rig = {
        "format": "life-kingdom-skinned-rig",
        "version": 1,
        "name": spec["name"],
        "slug": slug,
        "width": W,
        "height": H,
        "ground": spec["ground"],
        "bones": [{"name": b["name"],
                   "parent": bidx[b["parent"]] if b["parent"] else -1,
                   "head": b["head"]} for b in bones],
        "layers": layers,
        "eyes": [{"c": e["c"], "r": e["r"], "bone": bidx[e["bone"]]} for e in spec["eyes"]],
        "lidColor": "#%02x%02x%02x" % tuple(lid),
        "clips": spec["clips"],
    }
    with open(os.path.join(out_dir, "rig.json"), "w") as f:
        json.dump(rig, f, separators=(",", ":"))
    nv = sum(len(l["mesh"]["positions"]) // 2 for l in layers)
    nt = sum(len(l["mesh"]["triangles"]) // 3 for l in layers)
    print(f"rig: {len(layers)} layers, {nv} vertices, {nt} triangles, "
          f"{len(bones)} bones, {len(spec['clips'])} clips -> {out_dir}")


# -------------------------------------------------------------- runtime ----


def ease(u):
    return u * u * (3 - 2 * u)


def sample(keys, t, default):
    if not keys:
        return default
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            u = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            return v0 + (v1 - v0) * ease(u)
    return keys[-1][1]


def clip_time(clip, t):
    d = clip["duration"]
    return (t % d) if clip.get("loop") else min(t, d)


def bone_matrices(rig, clip, t):
    tracks = clip["tracks"]
    mats = []
    for b in rig["bones"]:
        tr = tracks.get(b["name"], {})
        hx, hy = b["head"]
        rot = math.radians(sample(tr.get("rot"), t, 0.0))
        tx, ty = sample(tr.get("tx"), t, 0.0), sample(tr.get("ty"), t, 0.0)
        sx, sy = sample(tr.get("sx"), t, 1.0), sample(tr.get("sy"), t, 1.0)
        c, s = math.cos(rot), math.sin(rot)
        # T(h+t) R S T(-h)
        a, bb, cc, d = c * sx, -s * sy, s * sx, c * sy
        e = hx + tx - (a * hx + bb * hy)
        f = hy + ty - (cc * hx + d * hy)
        local = np.array([[a, bb, e], [cc, d, f], [0, 0, 1]])
        p = b["parent"]
        mats.append(local if p < 0 else mats[p] @ local)
    return mats


def fx(clip, t):
    return {k: sample(v, t, 0.0) for k, v in clip["tracks"].get("fx", {}).items()}


def blink_amount(clip, t_abs, period=3.4, dur=0.16):
    if not clip.get("blink"):
        return 0.0
    p = (t_abs % period) / dur
    return max(0.0, 1 - abs(p * 2 - 1)) if p < 1 else 0.0


def skin(m, mats):
    pos = np.array(m["positions"], np.float64).reshape(-1, 2)
    w = np.array(m["weights"], np.float64).reshape(-1, m["influences"], 2)
    hom = np.c_[pos, np.ones(len(pos))]
    out = np.zeros_like(pos)
    M = np.stack(mats)[:, :2, :]
    for k in range(m["influences"]):
        bi = w[:, k, 0].astype(int)
        wk = w[:, k, 1:2]
        out += wk * np.einsum("nij,nj->ni", M[bi], hom)
    return out


# -------------------------------------------------------------- preview ----


def render_mesh(tex, uv, xy, tris, size, off):
    """Seamless mesh render: rasterise triangle ids, then one remap."""
    Wc, Hc = size
    ids = np.full((Hc, Wc), -1, np.int32)
    T = np.array(tris).reshape(-1, 3)
    dst = xy + off
    inv = np.zeros((len(T), 2, 3))
    for k, (a, b, c) in enumerate(T):
        d = dst[[a, b, c]].astype(np.float32)
        s = uv[[a, b, c]].astype(np.float32)
        e1, e2 = d[1] - d[0], d[2] - d[0]
        if abs(e1[0] * e2[1] - e1[1] * e2[0]) < 1e-6:
            continue
        inv[k] = cv2.getAffineTransform(d, s)
        cv2.fillConvexPoly(ids, np.round(d * 16).astype(np.int32), k, cv2.LINE_8, 4)
    ys, xs = np.nonzero(ids >= 0)
    A = inv[ids[ys, xs]]
    mx = np.full((Hc, Wc), -10, np.float32)
    my = np.full((Hc, Wc), -10, np.float32)
    mx[ys, xs] = A[:, 0, 0] * xs + A[:, 0, 1] * ys + A[:, 0, 2]
    my[ys, xs] = A[:, 1, 0] * xs + A[:, 1, 1] * ys + A[:, 1, 2]
    return cv2.remap(tex, mx, my, cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0)


def render_frame(rig, texs, clip, t, t_abs, pad=(70, 110), bg=(14, 18, 40)):
    W, H = rig["width"], rig["height"]
    size = (W + 2 * pad[0], H + pad[1] + 30)
    tc = clip_time(clip, t)
    mats = bone_matrices(rig, clip, tc)
    f = fx(clip, tc)
    shake = f.get("shake", 0) * 7 * math.sin(t_abs * 95)
    off = np.array([pad[0] + shake, pad[1]])
    rgb = np.zeros((size[1], size[0], 3), np.float32)
    a = np.zeros((size[1], size[0], 1), np.float32)
    for L, tex in zip(rig["layers"], texs):  # premultiplied "over"
        m = L["mesh"]
        xy = skin(m, mats)
        uv = np.array(m["positions"]).reshape(-1, 2) - np.array(L["offset"])
        lay = render_mesh(tex, uv, xy, m["triangles"], size, off).astype(np.float32)
        la = lay[..., 3:4] / 255
        rgb = lay[..., :3] + rgb * (1 - la)
        a = la + a * (1 - la)

    # blink lids
    bl = blink_amount(clip, t_abs)
    if bl > 0.02:
        lid = tuple(int(rig["lidColor"][i:i + 2], 16) for i in (1, 3, 5))
        lidimg = Image.new("RGBA", size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(lidimg)
        for e in rig["eyes"]:
            M = mats[e["bone"]]
            cx, cy = (M @ np.array([*e["c"], 1]))[:2] + off
            rx, ry = e["r"]
            h = ry * bl
            dr.ellipse([cx - rx, cy - ry, cx + rx, cy - ry + 2 * h], fill=lid + (255,))
            dr.arc([cx - rx, cy - ry, cx + rx, cy - ry + 2 * h], 20, 160, fill=(60, 30, 20, 255), width=2)
        L = np.asarray(lidimg).astype(np.float32)
        la = L[..., 3:4] / 255 * a
        rgb = rgb * (1 - la) + L[..., :3] * la

    # tints on the character
    if f.get("hurt", 0) > 0:
        h = f["hurt"]
        rgb = rgb * (1 - 0.45 * h) + np.array([255, 40, 40]) * a * 0.45 * h
    if f.get("flash", 0) > 0:
        rgb = rgb + (255 * a - rgb) * f["flash"]

    base = Image.new("RGBA", size, bg + (255,))
    gx, gy = rig["ground"]
    root_ty = (mats[0] @ np.array([gx, gy, 1]))[1] - gy
    dr = ImageDraw.Draw(base)
    sc = max(0.45, 1 + root_ty / 160)
    sw, sh = 170 * sc, 26 * sc
    dr.ellipse([gx + off[0] - sw, gy + pad[1] - sh, gx + off[0] + sw, gy + pad[1] + sh], fill=(5, 7, 18, 255))

    alpha_img = Image.fromarray((a[..., 0] * 255).astype(np.uint8))
    for key, col in (("aura", (255, 200, 60)), ("glow", (255, 215, 90)), ("charge", (90, 180, 255))):
        v = f.get(key, 0)
        if v > 0.01:
            g = alpha_img.filter(ImageFilter.GaussianBlur(18)).point(lambda p: min(255, int(p * 2.2 * v)))
            base.paste(Image.new("RGBA", size, col + (255,)), (0, 0), g)
    if f.get("aura", 0) > 0.01:
        v = f["aura"]
        cx, cy = gx + off[0], gy + pad[1]
        for k in range(3):
            r = (90 + 70 * k) * v
            dr.ellipse([cx - r * 1.6, cy - r * 0.35, cx + r * 1.6, cy + r * 0.35], outline=(255, 210, 80, 255), width=4)

    char = np.dstack([np.clip(rgb, 0, 255), a * 255]).astype(np.uint8)
    # un-premultiply for PIL compositing
    cu = char.astype(np.float32)
    cu[..., :3] = np.where(a > 0, cu[..., :3] / np.maximum(a, 1e-3), 0)
    base.alpha_composite(Image.fromarray(np.clip(cu, 0, 255).astype(np.uint8), "RGBA"))

    dr = ImageDraw.Draw(base)
    rng = np.random.default_rng(7)
    if f.get("particles", 0) > 0.01 or f.get("sparkle", 0) > 0.01:
        n = 26
        for i in range(n):
            x0 = rng.uniform(60, W + 80) + pad[0] - 70
            ph = rng.uniform(0, 1)
            if f.get("particles", 0) > 0.01:
                y = (gy + pad[1]) - ((t_abs * 220 + ph * 900) % 900)
                r = 3 + 4 * rng.uniform()
                dr.ellipse([x0 - r, y - r, x0 + r, y + r], fill=(255, 225, 120, int(255 * f["particles"])))
            if f.get("sparkle", 0) > 0.01:
                y = rng.uniform(80, H) + pad[1] - 60
                tw = (math.sin(t_abs * 9 + ph * 6.28) + 1) / 2 * f["sparkle"]
                r = 4 + 12 * tw
                dr.line([x0 - r, y, x0 + r, y], fill=(255, 245, 190, 255), width=3)
                dr.line([x0, y - r, x0, y + r], fill=(255, 245, 190, 255), width=3)
    return base.convert("RGB")


def load_textures(rig, folder):
    out = []
    for L in rig["layers"]:
        t = np.asarray(Image.open(os.path.join(folder, L["image"])).convert("RGBA")).astype(np.float32)
        t[..., :3] *= t[..., 3:4] / 255  # premultiply
        out.append(t.astype(np.uint8))
    return out


def preview(rig_path, out_dir, scale=0.5, fps=20):
    rig = json.load(open(rig_path))
    tex = load_textures(rig, os.path.dirname(rig_path))
    os.makedirs(out_dir, exist_ok=True)
    sheet = []
    for name, clip in rig["clips"].items():
        dur = clip["duration"] * (2 if clip.get("loop") and clip["duration"] < 3 else 1)
        if name == "idle":
            dur = 3.6  # include a blink
        frames = []
        n = int(dur * fps)
        for i in range(n):
            ta = i / fps
            im = render_frame(rig, tex, clip, ta, ta)
            frames.append(im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS))
        frames[0].save(os.path.join(out_dir, f"{name}.gif"), save_all=True,
                       append_images=frames[1:], duration=int(1000 / fps), loop=0)
        picks = [frames[int(k * (n - 1) / 4)] for k in range(5)]
        sheet.append((name, picks))
        print(f"{name}: {n} frames")
    fw, fh = sheet[0][1][0].size
    s = 0.5
    cs = Image.new("RGB", (int(fw * s) * 5, int(fh * s) * len(sheet)), (14, 18, 40))
    for r, (name, picks) in enumerate(sheet):
        for c, im in enumerate(picks):
            cs.paste(im.resize((int(fw * s), int(fh * s))), (c * int(fw * s), r * int(fh * s)))
        ImageDraw.Draw(cs).text((6, r * int(fh * s) + 4), name, fill=(255, 255, 255))
    cs.save(os.path.join(out_dir, "contact_sheet.png"))


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "build":
        build(*sys.argv[2:5])
    elif cmd == "preview":
        preview(*sys.argv[2:4])
    else:
        sys.exit(__doc__)
