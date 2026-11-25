#!/usr/bin/env python3
"""Build a Life Kingdom skeletal hero from painted parts + a placement layout.

  python build_rig.py HERO.json OUT_DIR

HERO.json holds: parts folder, layout.json (part -> 2x3 matrix into the
reference image, from position_parts.py / pins), bones (joints in reference
pixels, y down), slot draw order, leg chains, clips. Writes OUT_DIR/rig.json
(runtime format used by the web preview and the Flutter runtime) and
OUT_DIR/parts/*.png (downscaled), plus OUT_DIR/<name>.spine.json, a Spine 4.2
skeleton of the same rig for anyone who wants to open it in the Spine editor.
"""
import json, os, sys
import numpy as np
from PIL import Image


def main(spec_path, out):
    spec = json.load(open(spec_path))
    base = os.path.dirname(os.path.abspath(spec_path))
    lay = json.load(open(os.path.join(base, spec["layout"])))["parts"]
    k = spec.get("texScale", 0.5)
    os.makedirs(os.path.join(out, "parts"), exist_ok=True)
    joints = {b["name"]: b["at"] for b in spec["bones"]}
    parent = {b["name"]: b.get("parent") for b in spec["bones"]}
    bones = []
    for b in spec["bones"]:
        p = b.get("parent")
        x, y = b["at"]
        px, py = joints[p] if p else (0, 0)
        bones.append({"name": b["name"], "parent": p, "x": round(x - px, 2), "y": round(y - py, 2)})
    slots = []
    for s in spec["slots"]:
        name, bone = s["part"], s["bone"]
        img = Image.open(os.path.join(base, spec["parts"], name + ".png")).convert("RGBA")
        small = img.resize((max(1, round(img.width * k)), max(1, round(img.height * k))), Image.LANCZOS)
        small.save(os.path.join(out, "parts", name + ".png"), optimize=True)
        M = np.array(lay[name]["M"], np.float64)  # part px -> ref
        jx, jy = joints[bone]
        # attachment transform: texture px (downscaled) -> bone space
        A = np.array([[M[0, 0] / k, M[0, 1] / k, M[0, 2] - jx], [M[1, 0] / k, M[1, 1] / k, M[1, 2] - jy]])
        slots.append({"name": name, "bone": bone, "image": f"parts/{name}.png",
                      "w": small.width, "h": small.height,
                      "m": [round(v, 5) for v in A.flatten().tolist()]})
    rig = {"name": spec["name"], "ground": spec["ground"], "bones": bones, "slots": slots,
           "legs": spec.get("legs", []), "fx": spec.get("fx", {}), "clips": spec["clips"]}
    json.dump(rig, open(os.path.join(out, "rig.json"), "w"), indent=1)
    write_spine(rig, spec, os.path.join(out, spec["slug"] + ".spine.json"))
    print("rig:", len(bones), "bones,", len(slots), "slots,", len(rig["clips"]), "clips ->", out)


def write_spine(rig, spec, path):
    """Spine 4.2 setup pose (y up, origin at the ground point)."""
    gx, gy = rig["ground"]
    world = {}
    sb = []
    for b in rig["bones"]:
        p = b["parent"]
        wx = (world[p][0] if p else gx) + b["x"] if p else b["x"]
        wy = (world[p][1] if p else gy) + b["y"] if p else b["y"]
        world[b["name"]] = (wx, wy)
        e = {"name": b["name"]}
        if p:
            e.update(parent=p, x=round(b["x"], 2), y=round(-b["y"], 2))
        else:
            e.update(x=round(b["x"] - gx, 2), y=round(gy - b["y"], 2))
        sb.append(e)
    att = {}
    for s in rig["slots"]:
        a, b_, c, d, e, f = s["m"]
        cx, cy = s["w"] / 2, s["h"] / 2
        x = a * cx + b_ * cy + c
        y = d * cx + e * cy + f
        sx = (a * a + d * d) ** 0.5
        rot = -np.degrees(np.arctan2(d, a))
        att[s["name"]] = {s["name"]: {"x": round(x, 2), "y": round(-y, 2), "rotation": round(float(rot), 2),
                                      "scaleX": round(sx, 4), "scaleY": round(sx, 4),
                                      "width": s["w"], "height": s["h"]}}
    out = {"skeleton": {"spine": "4.2.0", "images": "./parts/"}, "bones": sb,
           "slots": [{"name": s["name"], "bone": s["bone"], "attachment": s["name"]} for s in rig["slots"]],
           "skins": [{"name": "default", "attachments": att}], "animations": {}}
    json.dump(out, open(path, "w"), indent=1)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
