# Kingdom Revamp (experimental branch `feat/kingdom-revamp`)

Branched from `feat/character-pipeline` (PR #2). Everything here is an experiment;
`main` and `feat/foundation` stay untouched until a result is approved.

## Goals
1. **Characters** — new 12-hero roster (painted 2D, ink outlines, cel-shading):
   UI portrait + 3/4 top-down 4-frame combat sheet per hero.
   Specs: `tools/character_pipeline/specs/roster/` (`roster.json` + one `.prompt.txt` each).
2. **Buildings** — redesign village buildings in the same painted style, with
   upgrade tiers that visibly change the silhouette (level 1 → 3 → 5).
3. **Living village** — idle animations on buildings (smoke, flags, glow),
   heroes walking/patrolling on the home map; the dragon «هَيّاب» roams the map after purchase.
4. **Reward system** — make rewards feel worth chasing: chests with reveal animation,
   hero collection/unlock flow, streak milestone rewards, building upgrades as rewards.

## Roster
| # | Slug | Name | Notes |
|---|------|------|-------|
| 1 | juggernaut | ذو القُرَيْن | heavy armour, greatsword spin |
| 2 | dragon_hayyab | هَيّاب | premium; roams the map after purchase |
| 3 | firecrest_warrior | ضَرّام | broadsword lunge |
| 4 | emerald_archer | قَنّاص الزُّمُرُّد | triple-arrow volley |
| 5 | stone_giant | جَلْمَد | ground-slam |
| 6 | bomb_runner | وَثّاب | bomb toss |
| 7 | purple_mage | مُضِرّ | flame-orb |
| 8 | boar_rider | نَزّال | hammer slam |
| 9 | axe_berserker | عَاصِف | whirling axe |
| 10 | night_summoner | طَيْفِيّ | spectral wisps |
| 11 | boulder_thrower | رَجّاف | bouncing boulder |
| 12 | cannon_cart | مِقْذاف | twin-shot |

## Pipeline per hero
generate sheet → key background → slice portrait + 4 frames → rig (`rigkit.py`) or
frame animation → asset in `assets/heroes/<slug>/` → hook into catalog + shop.

## Open decisions
- Frame-sheet animation (4 painted frames) vs skeletal rig (smoother, more work) per hero.
- Which buildings first and how many upgrade tiers.
- Reward economy changes (chest odds, hero prices) — must keep `docs/game_rules.md` balance.
