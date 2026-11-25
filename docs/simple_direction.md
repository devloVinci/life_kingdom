# Simple Direction (`feat/simple-direction`)

Branched from `feat/foundation` (2ec4f52). Never merged into `main`.
Goal: same habit/XP/quest core, a calmer modern UI, and a living world map.

## Audit summary

| Area | Today | Verdict |
|---|---|---|
| Architecture | Riverpod + go_router, pure engines in `lib/core/game` (game, economy, quest, task, companion, achievement, xp_curve) with tests | Keep as is |
| Persistence | Whole `GameState` as JSON in SharedPreferences (`life_kingdom_state_v1`), backup = same JSON | Keep; add new fields as optional |
| Theme | One hard-coded Clash palette (`AppColors`), Lilita One + Nunito, Material seed theme | Replace with token-based themes; keep the current look as the "Kingdom Classic" theme |
| World | `VillageMap`: fixed 390x844 canvas, buildings painted in code, trees sway, smoke, clouds, wanderers on fixed points | Reuse the layer and sprite code; put it in a pannable/zoomable world with data-driven layout |
| Characters | 15 flat SVGs (`whole.svg`), only the Builder is split into parts | Too cartoonish; redraw hero and dragon as part-based rigs |
| Shop | Characters, titles, background gradients; gold + gems, all earned | Extend to more cosmetic categories with previews |
| Random rewards | Chests from quests, levels, streaks (earned only, never bought) | Keep; never put chests up for sale |

### Data-compatibility risks
- `GameState.fromJson` rejects any `schemaVersion` other than 1, so bumping the version would make old saves and backups unreadable. Plan: keep v1 and only add **optional** fields with defaults (`uiTheme`, `worldSeason`, more `equipped` slots, `unlockedRegions`). Old saves load unchanged.
- `owned` / `equipped` already survive habit edits and streak breaks; new cosmetics use the same sets.
- Existing `bg_*` items stay valid as an "Atmosphere" category.

## Plan (in order, each step shippable)

1. **Theme tokens.** `UiTheme` (surfaces, text, accent, radius, typography) separate from `WorldTheme` (season pack). Themes: Obsidian (dark modern, default), Ivory (light modern), Kingdom Classic (today's look). Fonts: Cinzel for headings, Inter for body.
2. **Restyle shared widgets.** Panel, button, XP bar, rank badge, counters, nav bar on tokens; quieter colours, consistent 4/8 spacing, subtle motion.
3. **World map v2.** `InteractiveViewer` with clamped pan/zoom and an animated camera "fly to". Layout (locations, paths, regions, unlock level, waypoints) in `assets/world/kingdom.json`. Locked regions drawn in fog with a lock and the level needed.
4. **Season packs.** `assets/world/seasons/<id>.json`: palette, ground, tree style, particles (petals, pollen, leaves, snow), light tint, ambient loop. Painters read the pack, so the trees and ground change shape, not just colour. Adding a season = adding one JSON (+ optional sprites).
5. **Hero and dragon.** New, more serious part-based vector art (layered SVG). Procedural animation: idle breathing, walk cycle, tap reaction, smooth blends between states. Dragon: walks or flies between waypoints, idles, looks around, has unlockable skins (palette swaps plus a few unique parts).
6. **Cosmetic shop v2.** Categories: UI themes, seasons, decorations, dragon skins, hero outfits, atmosphere, effects, ambience. Each item has a live preview, name, description, price or unlock rule, owned state and an equip button. Earned currency only, no real money, no paid chests; buying something you already own is blocked (already enforced by `alreadyOwned`).
7. **Progress shows in the world.** Regions open with player level; buildings use their existing levels; streak milestones unlock decorations.

## Out of scope
Combat, pathfinding AI, a physics or game engine, real-money purchases.
