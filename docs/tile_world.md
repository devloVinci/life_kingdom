# Tile world branch (`feat/tile-world`)

Experimental branch off `feat/foundation`, never merged into `main`. The home
screen becomes a pixel-art tile world built from a real asset pack. It starts
as a tiny clearing around an old well and opens up as the player makes
progress in real life.

## Assets: EPIC RPG World – Grass Land 2.0 (free demo)

- Author: Rafael Matos — https://rafaelmatos.itch.io/epic-rpg-world-free-demograss-land-20
- 32×32 tiles, made for the free Tiled map editor (`.tmx` / `.tsx`).
- Licence: free for personal and commercial use in a project; the files may
  **not** be repackaged or redistributed. This repo is public, so the pack is
  **not committed**. `assets/world/*` is git-ignored.
- Import on each machine before running:

  ```powershell
  powershell -ExecutionPolicy Bypass -File tools/tiles/import_pack.ps1 `
    "D:\Downloads\Programs\EPIC RPG World Pack-[FREE Demo]Grass Land 2.0"
  ```

  This writes `assets/world/grassland.tmx`, `grassland_tiles.tsx` and
  `grassland_tiles.png`. If the repo is made private, the ignore lines in
  `.gitignore` can be removed and the files committed.
- The demo has only terrain: grass, dirt, cliff edges, one tree, bushes, tall
  grass, rocks, a bridge and a well. No buildings, water or characters; those
  come from the full packs.

## How it works

| Piece | File |
|---|---|
| Tiled reader (orthogonal, CSV layers, one external tileset) | `lib/core/world/tile_map.dart` |
| Land milestones and growth rules (pure logic) | `lib/core/game/world_growth.dart` |
| Renderer: one `drawAtlas` call for tiles, y-sorted props, swaying grass, fireflies, stepped fog | `lib/features/kingdom/tile_world/world_painter.dart` |
| Prop sprites and their placement | `lib/features/kingdom/tile_world/world_props.dart` |
| Home view: pan/zoom, reveal animation, camera glide, "New land" banner, tap the well | `lib/features/kingdom/tile_world/tile_world_view.dart` |
| Next-land card and Land Journal sheet | `lib/features/kingdom/tile_world/land_journal.dart` |
| Python preview of any growth step (no Flutter needed) | `tools/tiles/preview_world.py` |

No new packages. Plain Flutter `CustomPainter` with `FilterQuality.none`
keeps the pixels crisp and runs on Flutter Web/Safari. Flame (+ `flame_tiled`)
is the planned upgrade once there are walking characters and animated tiles.

### Growth rules

The world opens one ring per milestone reached, in any order:

| # | Land | Real-life goal |
|---|---|---|
| 0 | The Clearing | start |
| 1 | The Old Well | complete your first habit |
| 2 | Plateau Steps | finish a one-off task |
| 3 | Mossy Rocks | reach level 2 |
| 4 | Shaded Grove | hold a 3-day streak |
| 5 | Lone Oak | complete 10 habits |
| 6 | Stone Ring | reach level 4 |
| 7 | Eastern Woods | hold a 7-day streak |
| 8 | Dirt Road | finish 10 tasks |
| 9 | Western Meadow | complete 30 habits |
| 10 | High Cliffs | reach level 7 |
| 11 | Northern Fields | hold a 14-day streak |
| 12 | The Whole Valley | reach level 10 |

- Radius in tiles: `3.2 + 1.45 × count`; at 12 the whole map is open.
- Streaks use the best streak ever, so breaking a streak never takes land away.
- Land the player has watched open is stored as `world_seen_<id>` flags in
  `GameState.settings`, so it never closes again (e.g. after clearing done
  tasks). The save schema is unchanged (v1).
- New land plays a 2-second reveal with a camera glide and a banner. The
  first time an existing save opens this branch, all the land it has already
  earned is revealed at once.

## Next steps (not built yet)

1. More packs (village buildings, water, characters) → buildings unlocked by
   level, the player's hero walking between them (Flame).
2. Author a bigger map in Tiled with named regions as object layers instead of
   rings.
3. Building growth stages per level.
