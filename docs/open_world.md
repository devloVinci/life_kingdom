# Open World branch (`feat/open-world`)

Experimental, branched from `feat/foundation`, never merged into `main`.
Full plan (Arabic): the project doc `claude/open-world-plan.md`.

## Idea
Real life sets how much power you have; the game decides how you use it.
A task is a task whatever its topic; only its difficulty matters.

## Setup (once per machine)
```
powershell -ExecutionPolicy Bypass -File tools/openworld/import_pack.ps1
flutter run -d chrome
```
The ClashOpenWorld pack is git-ignored (public repo). Without it the app
runs with placeholders.

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

## Numbers
All in `WorldConfig` (`lib/core/game/world_engine.dart`).

## Asset names
`lib/game/atlas/catalog.dart`. Unit direction groups (set01..08) are
first guesses: check them in Diwan -> asset gallery and fix there.

## Not yet
Army, marches with supplies, bosses, freed villages, decree, merchant,
herald, chronicle, seasons, focus siege, return quest, Arabic settings.
