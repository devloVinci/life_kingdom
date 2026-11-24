#!/usr/bin/env python3
"""Split a Figma-exported character SVG into one SVG per part + rig.json.

Usage:
  python tools/split_character.py path/to/Char_Builder.svg [--slug builder] [--out assets/characters]

Export from Figma: select the Char/<Name> component -> Export -> SVG,
with "Include id attribute" ENABLED (so layer names survive).
Every top-level layer of the component becomes a part. All parts keep the
same canvas (viewBox), so the app can stack them without offsets.
"""
import argparse
import copy
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

SVG_NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", SVG_NS)
ET.register_namespace("xlink", "http://www.w3.org/1999/xlink")


def tag(el):
    return el.tag.split("}")[-1]


def slugify(name):
    s = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    return s or "part"


# ---------- roles ----------
ROLE_RULES = [
    ("shadow", r"shadow"),
    ("legL", r"(leg|foot|boot)[ _-]*l\b"),
    ("legR", r"(leg|foot|boot)[ _-]*r\b"),
    ("armL", r"(arm|hand|fist|wing|shield)[ _-]*l\b|shield"),
    ("armR", r"(arm|hand|fist|wing)[ _-]*r\b|mallet|sword|bow|axe|hammer|lance|staff|wand|orb|book|spear|blade|club|weapon"),
    ("head", r"head|hair|hat|helmet|hood|beard|horn|ear|crown|neck|eye|mouth|brow|face|mask|halo"),
]


def role_of(name):
    n = name.lower()
    for role, pat in ROLE_RULES:
        if re.search(pat, n):
            return role
    return "body"


# ---------- bbox ----------
NUM = r"-?\d*\.?\d+(?:e[-+]?\d+)?"


def f(el, key, default=0.0):
    try:
        return float(el.get(key, default))
    except ValueError:
        return default


def path_points(d):
    toks = re.findall(r"[MLHVCSQTAZmlhvcsqtaz]|" + NUM, d)
    pts, i, cmd, cx, cy = [], 0, None, 0.0, 0.0
    counts = {"M": 2, "L": 2, "T": 2, "C": 6, "S": 4, "Q": 4}
    while i < len(toks):
        if re.match(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                continue
        if cmd is None:
            break
        c = cmd.upper()
        rel = cmd.islower()
        if c == "H":
            x = float(toks[i]); i += 1
            cx = cx + x if rel else x
            pts.append((cx, cy))
        elif c == "V":
            y = float(toks[i]); i += 1
            cy = cy + y if rel else y
            pts.append((cx, cy))
        elif c == "A":
            x, y = float(toks[i + 5]), float(toks[i + 6]); i += 7
            cx, cy = (cx + x, cy + y) if rel else (x, y)
            pts.append((cx, cy))
        elif c in counts:
            n = counts[c]
            vals = [float(v) for v in toks[i:i + n]]; i += n
            for k in range(0, n, 2):
                px, py = vals[k], vals[k + 1]
                if rel:
                    px, py = cx + px, cy + py
                pts.append((px, py))
            cx, cy = pts[-1]
        else:
            i += 1
    return pts


def bbox_of(el):
    pts = []
    for e in el.iter():
        t = tag(e)
        if t == "rect":
            x, y, w, h = f(e, "x"), f(e, "y"), f(e, "width"), f(e, "height")
            pts += [(x, y), (x + w, y + h)]
        elif t == "circle":
            cx, cy, r = f(e, "cx"), f(e, "cy"), f(e, "r")
            pts += [(cx - r, cy - r), (cx + r, cy + r)]
        elif t == "ellipse":
            cx, cy, rx, ry = f(e, "cx"), f(e, "cy"), f(e, "rx"), f(e, "ry")
            pts += [(cx - rx, cy - ry), (cx + rx, cy + ry)]
        elif t == "path" and e.get("d"):
            pts += path_points(e.get("d"))
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return [min(xs), min(ys), max(xs) - min(xs), max(ys) - min(ys)]


def union(boxes):
    boxes = [b for b in boxes if b]
    if not boxes:
        return None
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[0] + b[2] for b in boxes); y1 = max(b[1] + b[3] for b in boxes)
    return [x0, y0, x1 - x0, y1 - y0]


# ---------- masks ----------
def flatten_masks(parent):
    """Figma exports 'outside' strokes as a doubled stroke clipped by a mask.
    Many SVG renderers handle masks poorly, so draw the doubled stroke
    BEFORE the fill instead: the fill hides the inner half, leaving exactly
    the outside half visible, with no mask needed."""
    for ch in list(parent):
        flatten_masks(ch)
    new = []
    for ch in list(parent):
        if tag(ch) == "mask":
            continue
        if "mask" in ch.attrib:
            del ch.attrib["mask"]
            # insert before the last shape (the fill it belongs to)
            if new and tag(new[-1]) in ("rect", "circle", "ellipse", "path", "use"):
                new.insert(len(new) - 1, ch)
            else:
                new.append(ch)
        else:
            new.append(ch)
    parent[:] = new


def whole_character(root, a, slug_hint=None):
    """Fallback for flat exports: ground shadow + one whole-body layer."""
    base = os.path.splitext(os.path.basename(a.svg))[0]
    name = re.sub(r"^Char[_ ]+", "", base)
    slug = slug_hint or slugify(name)
    width = float(re.sub(r"[^0-9.]", "", root.get("width", "120")))
    height = float(re.sub(r"[^0-9.]", "", root.get("height", "140")))
    out_dir = os.path.join(a.out, slug)
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".svg") or old == "rig.json":
            os.remove(os.path.join(out_dir, old))
    body = copy.deepcopy(root)
    flatten_masks(body)
    shadow = None
    for k in list(body):
        if tag(k) in ("defs", "title", "desc"):
            continue
        if (tag(k) == "ellipse" and "1A331A" in k.get("fill", "").upper()):
            shadow = k
            body.remove(k)
        break
    def write(el_root, fname):
        ET.ElementTree(el_root).write(os.path.join(out_dir, fname),
                                      encoding="utf-8", xml_declaration=False)
    write(body, "whole.svg")
    parts, pivots = [], {}
    cy = height - 8
    if shadow is not None:
        sh = ET.Element(f"{{{SVG_NS}}}svg", dict(root.attrib))
        sh.append(shadow)
        write(sh, "ground_shadow.svg")
        parts.append({"name": "Ground Shadow", "file": "ground_shadow.svg",
                      "role": "shadow", "bbox": bbox_of(shadow)})
        cy = float(shadow.get("cy", cy))
        pivots["shadow"] = [float(shadow.get("cx", width / 2)), cy]
    parts.append({"name": "Whole", "file": "whole.svg", "role": "whole",
                  "bbox": [0, 0, width, height]})
    pivots["whole"] = [width / 2, cy - 4]
    pivots["root"] = pivots["whole"]
    rig = {"name": name, "slug": slug, "mode": "whole", "width": width,
           "height": height, "parts": parts, "pivots": pivots}
    with open(os.path.join(out_dir, "rig.json"), "w") as fh:
        json.dump(rig, fh, indent=1)
    print(f"{name}: whole-body rig -> {out_dir}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("svg")
    ap.add_argument("--slug")
    ap.add_argument("--out", default="assets/characters")
    ap.add_argument("--parts", action="store_true",
                    help="force part splitting even if no layer ids exist")
    a = ap.parse_args()

    root = ET.parse(a.svg).getroot()
    kids = [k for k in root if tag(k) not in ("defs", "title", "desc")]
    comp = kids[0] if len(kids) == 1 and tag(kids[0]) == "g" else root
    comp_id = comp.get("id", "") if comp is not root else ""
    name = comp_id.split("/")[-1] if comp_id else os.path.splitext(os.path.basename(a.svg))[0]
    slug = a.slug or slugify(name)
    parts_src = [k for k in comp if tag(k) not in ("defs", "title", "desc")]
    if not parts_src:
        sys.exit("No parts found in SVG")
    # Figma drops layer names unless "Include id attribute" was on (or the
    # layers were not grouped): then there is nothing to split by.
    named = [k for k in parts_src if tag(k) != "mask" and k.get("id")]
    if not named and not a.parts:
        return whole_character(root, a, slug_hint=a.slug)

    width = float(re.sub(r"[^0-9.]", "", root.get("width", "120")))
    height = float(re.sub(r"[^0-9.]", "", root.get("height", "140")))
    out_dir = os.path.join(a.out, slug)
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".svg") or old == "rig.json":
            os.remove(os.path.join(out_dir, old))

    used, parts = set(), []
    for el in parts_src:
        pname = el.get("id") or tag(el)
        fname = slugify(pname)
        base, n = fname, 2
        while fname in used:
            fname = f"{base}_{n}"; n += 1
        used.add(fname)
        el = copy.deepcopy(el)
        flatten_masks(el)
        svg = ET.Element(f"{{{SVG_NS}}}svg", {
            "width": str(int(width)), "height": str(int(height)),
            "viewBox": f"0 0 {int(width)} {int(height)}", "fill": "none"})
        svg.append(el)
        ET.ElementTree(svg).write(os.path.join(out_dir, fname + ".svg"),
                                  encoding="utf-8", xml_declaration=False)
        parts.append({"name": pname, "file": fname + ".svg",
                      "role": role_of(pname), "bbox": bbox_of(el)})

    def named(role, pattern):
        for p in parts:
            if p["role"] == role and re.search(pattern, p["name"].lower()):
                return p["bbox"]
        return union([p["bbox"] for p in parts if p["role"] == role])

    def of_role(role):
        return union([p["bbox"] for p in parts if p["role"] == role])

    center = [width / 2, height / 2]
    pivots = {"root": [width / 2, (of_role("shadow") or [0, height - 12, 0, 12])[1]
                       + (of_role("shadow") or [0, 0, 0, 12])[3] / 2]}
    for role in ("legL", "legR"):
        b = of_role(role)
        pivots[role] = [b[0] + b[2] / 2, b[1]] if b else center
    for role in ("armL", "armR"):
        b = named(role, r"arm|wing")
        pivots[role] = [b[0] + b[2] / 2, b[1] + 8] if b else center
    hb = named("head", r"^head")
    pivots["head"] = [hb[0] + hb[2] / 2, hb[1] + hb[3] - 4] if hb else center
    bb = named("body", r"^(body|torso)")
    pivots["body"] = [bb[0] + bb[2] / 2, bb[1] + bb[3]] if bb else center
    sb = of_role("shadow")
    pivots["shadow"] = [sb[0] + sb[2] / 2, sb[1] + sb[3] / 2] if sb else center

    rig = {"name": name, "slug": slug, "width": width, "height": height,
           "parts": parts, "pivots": pivots}
    with open(os.path.join(out_dir, "rig.json"), "w") as fh:
        json.dump(rig, fh, indent=1)
    print(f"{name}: {len(parts)} parts -> {out_dir}")
    print("Roles:", {p['name']: p['role'] for p in parts})
    print(f"Add to pubspec.yaml assets:  - {out_dir}/")


if __name__ == "__main__":
    main()
