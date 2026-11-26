# Open World branch (`feat/open-world`)

Experimental, branched from `feat/foundation`, never merged into `main`.
Full plan (Arabic): the project doc `claude/open-world-plan.md`.

## Idea
Real life sets how much power you have; the game decides how you use it.
A task is a task whatever its topic; only its difficulty matters.

## Setup (once per machine)
```
pip install pillow
python tools/openworld/import_pack.py "%USERPROFILE%\Downloads\ready_use_word"
flutter run -d chrome
```
The `ready_use_word` pack (v3) is git-ignored (public repo). Without it the
app runs with placeholders. The script copies only the sheets the app uses
(`--all` for everything), writes TexturePacker-style JSON next to each,
builds `characters.json`, and:
- shrinks big art once to a fixed height (herald 112, chest 80, record
  tower 150, merchant 80, UI 48-96) so nothing is resampled at run time;
- cuts terrain tiles to 64x64 (removes the 1px grid line of the cells).
`--fixture` writes names-only metadata to `test/fixtures/` (committed) so CI
can check the catalog against the real pack without the art.

## What v0.1 has
- Arabic RTL app, 4 tabs: Kingdom, World, Tasks, Diwan (+ old settings,
  calendar, and an asset gallery).
- Kingdom scene from the pack: town hall (45 looks from player level),
  gold mine (64 looks from lifetime work), record tower (8 floors from the
  best week), builder (works on days with work), knight, daily chest,
  walls (from fortifications held), forest, goblin.
- Harvest: each finished item puts gold above the mine; tap to collect.
- Supplies: new resource from every finished item (daily cap 40).
- Foundation stone: star one task a day; finishing it gives a stone.
- Daily chest: fills with today's work, pays out the next day.
- Weekly scout report (Diwan): last week's stats + chest tier, claim once.
- Fortifications: +1 per 7 kept days (max 3); spend one for a rest day
  (streak kept, max 2 in a row). Auto-use is an opt-in setting.
- Light penalty: a missed day lets a goblin take 30% of the uncollected
  harvest (and 10% supplies); after doing any work that day you can chase
  him and win half back.
- World map: black beyond the radius your level reveals; rings grass ->
  snow -> volcanic -> shadow.
- Tasks now count toward the streak.

## v0.2
- Few characters on purpose: knight (hero), warrior (`barbarian_v2`),
  archer, builder, goblin.
- Army: barracks in the kingdom trains warriors (30 gold + 5 supplies,
  power 1) and archers (60 + 10, power 2); camp size 8 + level/2 (max 40);
  soldiers stroll around the camp.
- World: 18 fixed landmarks; tap one inside the light -> march costs
  supplies, needs army power, gives gold (+gems far out) and a banner.
- Sandbox (Diwan -> sandbox, or the red badge): separate save
  (`life_kingdom_sandbox`), start from a copy of real progress or empty;
  level slider, resources, fake tasks, +1/+7 days (time jump), goblin,
  record tower, soldiers, reset conquests; no notifications; real save
  restored on exit.
- Animation picker (in the sandbox): choose which pack animation each
  character uses; saved on the device (`ow_anim_overrides`).

## Character animations
`assets/openworld/characters.json` is built from the pack's `index.json`:
`characters -> <char> -> animations -> <anim> -> directions -> <dir>`.
`CharacterLibrary` (`lib/game/atlas/character_anims.dart`) resolves a
direction: exact, then alternate takes (`down_alt`, `right_b`), then the
other side flipped, then `side` (drawn facing right). Slots in
`anim_overrides.dart` pick a named animation per use. The knight now has
a walk on all four sides; `barbarian_v2` idles only front/back, so its slot
uses `combat_idle`; goblin and builder profile art faces right (flipped for
left).

## Numbers
All in `WorldConfig` (`lib/core/game/world_engine.dart`).

## Asset names
`lib/game/atlas/catalog.dart` uses the pack's row names (e.g.
`gold_mine_wood_row0..3`). Which tileset row is snow or shadow, and the
build order of the town hall blocks, are first guesses: check them in
Diwan -> asset gallery. `test/pack_catalog_test.dart` fails if a name does
not exist in the pack.

## Not yet
Bosses, freed villages, decree, merchant,
herald, chronicle, seasons, focus siege, return quest, Arabic settings.
