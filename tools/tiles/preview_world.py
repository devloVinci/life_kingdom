"""Render the tile-world home map at a given growth step, without Flutter.

Needs the pack imported into assets/world (tools/tiles/import_pack.ps1).
Mirrors lib/features/kingdom/tile_world/world_painter.dart (tile layers,
y-sorted props from world_props.dart, stepped pixel fog) so the layout can be
checked quickly.

    python3 tools/tiles/preview_world.py <count> [out.png]

<count> = land milestones reached (0..12).
"""
import math
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORLD = ROOT / "assets" / "world"
PROPS = ROOT / "lib" / "features" / "kingdom" / "tile_world" / "world_props.dart"
N_MILESTONES = 12
FOG = (11, 15, 26)
CELL = 16


def radius_for(count):
    return 26.0 if count >= N_MILESTONES else 3.2 + count * 1.45


def cell_noise(x, y):
    return (((x * 73856093) ^ (y * 19349663)) & 0xFFFF) / 65535.0


def fog_alpha(cx, cy, home, r):
    d = math.hypot(cx / 32 - home[0] / 32, cy / 32 - home[1] / 32)
    d += (cell_noise(int(cx // CELL), int(cy // CELL)) - 0.5) * 1.1
    v = max(0.0, min(1.0, (r - d) / 1.6))
    a = 1.0 - v
    return math.ceil(a * 4) / 4  # four pixel-art steps


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    out = sys.argv[2] if len(sys.argv) > 2 else f"world_{count}.png"
    tmx = (WORLD / "grassland.tmx").read_text()
    tiles = Image.open(WORLD / "grassland_tiles.png").convert("RGBA")
    w = int(re.search(r'<map[^>]*\bwidth="(\d+)"', tmx).group(1))
    h = int(re.search(r'<map[^>]*\bheight="(\d+)"', tmx).group(1))
    cols = tiles.width // 32
    img = Image.new("RGBA", (w * 32, h * 32), FOG + (255,))
    for m in re.finditer(r'<data encoding="csv">(.*?)</data>', tmx, re.S):
        gids = [int(v) & 0x1FFFFFFF for v in m.group(1).replace("\n", "").split(",") if v.strip()]
        for i, g in enumerate(gids):
            if not g:
                continue
            t = g - 1
            sx, sy = (t % cols) * 32, (t // cols) * 32
            img.alpha_composite(tiles.crop((sx, sy, sx + 32, sy + 32)), ((i % w) * 32, (i // w) * 32))

    src = PROPS.read_text()
    sprites = {}
    for m in re.finditer(r"static const (\w+) = PropSprite\(Rect\.fromLTWH\(([\d, .]+)\)(?:,\s*shadow: Rect\.fromLTWH\(([\d, .]+)\))?", src):
        rect = [float(v) for v in m.group(2).split(",")]
        shadow = [float(v) for v in m.group(3).split(",")] if m.group(3) else None
        sprites[m.group(1)] = (rect, shadow)
    home = [float(v) for v in re.search(r"home = Offset\(([\d.]+), ([\d.]+)\)", src).groups()]
    props = []
    for m in re.finditer(r"WorldProp\('(\w+)', Sprites\.(\w+), Offset\(([\d.]+), ([\d.]+)\)", src):
        props.append((float(m.group(4)), float(m.group(3)), sprites[m.group(2)]))
    for fy, fx, (rect, shadow) in sorted(props):
        if shadow:
            sh = tiles.crop((int(shadow[0]), int(shadow[1]), int(shadow[0] + shadow[2]), int(shadow[1] + shadow[3])))
            img.alpha_composite(sh, (int(fx - shadow[2] / 2), int(fy - shadow[3] + 6)))
        sp = tiles.crop((int(rect[0]), int(rect[1]), int(rect[0] + rect[2]), int(rect[1] + rect[3])))
        img.alpha_composite(sp, (int(fx - rect[2] / 2), int(fy - rect[3])))

    r = radius_for(count)
    fog = Image.new("RGBA", img.size, (0, 0, 0, 0))
    px = fog.load()
    for cy in range(0, h * 32, CELL):
        for cx in range(0, w * 32, CELL):
            a = fog_alpha(cx + CELL / 2, cy + CELL / 2, home, r)
            if a <= 0:
                continue
            col = FOG + (int(a * 0.95 * 255),)
            for yy in range(cy, cy + CELL):
                for xx in range(cx, cx + CELL):
                    px[xx, yy] = col
    img.alpha_composite(fog)
    img.save(out)
    print(out, "radius", r)


if __name__ == "__main__":
    main()
