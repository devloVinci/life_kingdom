#!/usr/bin/env python3
"""Imports the `ready_use_word` sprite pack into assets/openworld/.

Usage (from the repository root):
    pip install pillow
    python tools/openworld/import_pack.py [PACK_DIR] [--all] [--fixture]

PACK_DIR defaults to ~/Downloads/ready_use_word.

For every selected asset it writes
    assets/openworld/<id>.png    spritesheet (re-packed when scaled)
    assets/openworld/<id>.json   TexturePacker-style hash the Dart AtlasData reads
and, for characters, assets/openworld/characters.json (named animations with
directions) which CharacterLibrary reads. Big art (herald, chest, record tower,
merchant, UI) is shrunk here, once, to a fixed on-screen height so it never
has to be resampled at run time; terrain tiles are cut to 64x64 which also
removes the 1px grid line the source cells carry.

`--fixture` additionally writes metadata-only files under test/fixtures/ (no
art) so CI can check names against the pack without the pack.
"""
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "openworld")
FIXTURES = os.path.join(ROOT, "test", "fixtures")

# Assets used by the app so far. `--all` imports the whole pack.
PHASE1 = [
    # units
    "knight", "barbarian_v2", "archer", "builder", "goblin", "hero_warlord_commander",
    "berserker", "heavy_knight", "lancer", "wizard", "cleric", "giant", "pekka", "dragon",
    "scout_reporter", "royal_monthly_herald",
    "wandering_merchant_walk", "wandering_merchant_actions", "wandering_merchant_trading",
    "forest_guardian", "frost_lord",
    # kingdom
    "town_hall_idle_upgrade", "town_hall_damage", "storages_townhall_builder",
    "resource_extractors", "builder_hut_idle_repair", "military_buildings",
    "army_camp_idle_fire", "record_tower", "daily_chest", "merchant_stall",
    "walls", "gates_and_wall_damage", "defensive_towers",
    # world
    "terrain_grass_dirt_mud", "terrain_paths_water_cliffs", "terrain_snow_ice_shadow",
    "terrain_volcanic_lava", "roads_bridges", "flora_rocks_resources",
    "world_landmarks", "battlefield_scars",
    # siege and effects
    "battering_ram", "catapult", "ballista", "siege_tower", "mobile_cannon",
    "spells_explosions_vfx", "arrows_impact_fx", "command_fx",
    # interface
    "hud_icons", "ui_elements", "ui_letters_maps", "ui_books_stationery",
    "ui_cards_badges", "ui_name_plates",
]

# Output frame height (px) for art that is much bigger than the 68px units.
TARGET_HEIGHT = {
    "royal_monthly_herald": 112,
    "wandering_merchant_walk": 80,
    "wandering_merchant_actions": 80,
    "wandering_merchant_trading": 80,
    "merchant_stall": 80,
    "daily_chest": 80,
    "record_tower": 150,
    "ui_letters_maps": 96,
    "ui_books_stationery": 96,
    "ui_cards_badges": 96,
    "ui_name_plates": 48,
    "mobile_cannon": 80,
}

TILE = 64
MOVEMENT = ("idle", "walk", "run", "ride", "fly", "hover", "sneak", "loot_dash")


def category(anim):
    return "movement" if any(anim.startswith(m) for m in MOVEMENT) else (
        "other" if anim.startswith(("steal", "build", "repair", "read", "announce", "deliver"))
        else "combat")


def split_key(key, directions):
    """`walk_down_alt` -> ('walk', 'down_alt') using the asset's own direction list."""
    best = None
    for d in directions:
        if d != "none" and key.endswith("_" + d) and (best is None or len(d) > len(best)):
            best = d
    if best is None:
        return key, "none"
    return key[: -len(best) - 1], best


def build_characters(assets):
    """assets: iterable of dicts with id, kind, directions, animations{key:{fps,loop}}."""
    chars = {}
    for a in assets:
        if a.get("kind") != "character" and a.get("kind") != "boss":
            continue
        dirs = a.get("directions") or []
        anims = {}
        for key, v in a["animations"].items():
            name, d = split_key(key, dirs)
            e = anims.setdefault(name, {
                "category": category(name),
                "fps": v.get("fps", 8),
                "loop": bool(v.get("loop", True)),
                "directions": {},
            })
            e["directions"][d] = {"atlas_json": a["id"] + ".json", "animation_key": key}
        chars[a["id"]] = {"animations": anims}
    return {"characters": chars}


def load_index(pack):
    with open(os.path.join(pack, "index.json"), encoding="utf-8") as f:
        return json.load(f)


def atlas_json(frames, anims, meta, tile=False):
    out_frames = {}
    for name, fr in frames.items():
        w, h = fr["w"], fr["h"]
        px, py = fr["pivot"]
        out_frames[name] = {
            "frame": {"x": fr["x"], "y": fr["y"], "w": w, "h": h},
            "sourceSize": {"w": w, "h": h},
            "spriteSourceSize": {"x": 0, "y": 0, "w": w, "h": h},
            "pivot": {"x": 0.0, "y": 0.0} if tile else {"x": round(px / w, 4), "y": round(py / h, 4)},
        }
    return {"meta": meta, "frames": out_frames, "animations": anims}


def convert(pack, entry, Image):
    asset_json = os.path.join(pack, entry["json"])
    with open(asset_json, encoding="utf-8") as f:
        data = json.load(f)
    sheet_path = os.path.join(os.path.dirname(asset_json), data["spritesheet"])
    sheet = Image.open(sheet_path).convert("RGBA")
    aid = data["id"]
    tile = data.get("kind") == "tile" or entry.get("kind") == "tile"

    # Order frames as the animations list them, then any leftovers.
    ordered = []
    seen = set()
    for a in data["animations"].values():
        for n in a["frames"]:
            if n in data["frames"] and n not in seen:
                ordered.append(n)
                seen.add(n)
    for n in data["frames"]:
        if n not in seen:
            ordered.append(n)

    fh = data["frame_size"][1]
    scale = TARGET_HEIGHT.get(aid, fh) / fh if aid in TARGET_HEIGHT else 1.0

    crops = {}
    for n in ordered:
        fr = data["frames"][n]
        r = fr["sheet_rect"]
        img = sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"]))
        pv = fr.get("pivot") or [r["w"] / 2, r["h"] - 1]
        if tile:
            cx, cy = (img.width - TILE) // 2, (img.height - TILE) // 2
            img = img.crop((cx, cy, cx + TILE, cy + TILE))
            pv = [0, 0]
        elif scale != 1.0:
            nw, nh = max(1, round(img.width * scale)), max(1, round(img.height * scale))
            img = img.resize((nw, nh), Image.LANCZOS)
            pv = [pv[0] * nw / r["w"], pv[1] * nh / r["h"]]
        crops[n] = (img, pv)

    unchanged = not tile and scale == 1.0
    frames = {}
    if unchanged:
        out_sheet = sheet
        for n in ordered:
            r = data["frames"][n]["sheet_rect"]
            frames[n] = {"x": r["x"], "y": r["y"], "w": r["w"], "h": r["h"],
                         "pivot": data["frames"][n].get("pivot") or [r["w"] / 2, r["h"] - 1]}
    else:
        cw = max(c[0].width for c in crops.values())
        ch = max(c[0].height for c in crops.values())
        cols = max(1, min(len(crops), 2048 // cw))
        rows = math.ceil(len(crops) / cols)
        out_sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
        for i, n in enumerate(ordered):
            img, pv = crops[n]
            x, y = (i % cols) * cw, (i // cols) * ch
            out_sheet.paste(img, (x, y))
            frames[n] = {"x": x, "y": y, "w": img.width, "h": img.height, "pivot": pv}

    anims = {k: list(a["frames"]) for k, a in data["animations"].items()}
    meta = {"id": aid, "kind": data.get("kind", entry.get("kind")), "scale": round(scale, 4),
            "tile": tile, "frame_size": [frames[ordered[0]]["w"], frames[ordered[0]]["h"]]}
    os.makedirs(OUT, exist_ok=True)
    out_sheet.save(os.path.join(OUT, aid + ".png"), optimize=True)
    with open(os.path.join(OUT, aid + ".json"), "w", encoding="utf-8") as f:
        json.dump(atlas_json(frames, anims, meta, tile), f, separators=(",", ":"))
    return meta, out_sheet.size


def fixture_assets(index):
    out = []
    for e in index["assets"]:
        out.append({
            "id": e["id"], "kind": e["kind"], "frame_size": e.get("frame_size"),
            "directions": e.get("directions") or [],
            "animations": {k: {"frames": v["frames"], "fps": v.get("fps", 8), "loop": v.get("loop", True)}
                           for k, v in e["animations"].items()},
        })
    return out


def main(argv):
    args = [a for a in argv[1:] if not a.startswith("--")]
    flags = {a for a in argv[1:] if a.startswith("--")}
    pack = args[0] if args else os.path.join(os.path.expanduser("~"), "Downloads", "ready_use_word")
    if not os.path.exists(os.path.join(pack, "index.json")):
        print("index.json not found in", pack)
        return 1
    index = load_index(pack)
    assets = fixture_assets(index)

    if "--fixture" in flags:
        os.makedirs(FIXTURES, exist_ok=True)
        with open(os.path.join(FIXTURES, "pack_index.json"), "w", encoding="utf-8") as f:
            json.dump({"assets": assets}, f, separators=(",", ":"))
        with open(os.path.join(FIXTURES, "characters.json"), "w", encoding="utf-8") as f:
            json.dump(build_characters(assets), f, separators=(",", ":"))
        print("fixtures written:", len(assets), "assets")
        if "--fixture-only" in flags:
            return 0

    try:
        from PIL import Image
    except ImportError:
        print("pip install pillow")
        return 1

    wanted = {e["id"] for e in index["assets"]} if "--all" in flags else set(PHASE1)
    by_id = {e["id"]: e for e in index["assets"]}
    missing = sorted(wanted - set(by_id))
    if missing:
        print("not in this pack:", ", ".join(missing))
    manifest = []
    total = 0
    for aid in sorted(wanted & set(by_id)):
        try:
            meta, size = convert(pack, by_id[aid], Image)
        except FileNotFoundError as e:
            print("skip %-34s (%s)" % (aid, os.path.basename(str(e.filename))))
            continue
        manifest.append(meta)
        total += os.path.getsize(os.path.join(OUT, aid + ".png"))
        print("ok  %-34s %4dx%-4d x%.3f" % (aid, size[0], size[1], meta["scale"]))
    chars = build_characters([a for a in assets if a["id"] in wanted])
    with open(os.path.join(OUT, "characters.json"), "w", encoding="utf-8") as f:
        json.dump(chars, f, separators=(",", ":"))
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"assets": manifest}, f, separators=(",", ":"))
    print("imported %d assets, %.1f MB of PNG, %d characters" % (len(manifest), total / 1e6, len(chars["characters"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
