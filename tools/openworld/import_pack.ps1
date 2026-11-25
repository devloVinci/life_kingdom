# Copies the ClashOpenWorld pack atlases into assets/openworld/ as
# <id>.png + <id>.json (the names the app loads). The pack is not stored in
# this public repo; run this once on every machine you build from, and again
# after you change the pack.
#
#   powershell -ExecutionPolicy Bypass -File tools/openworld/import_pack.ps1
#   powershell -ExecutionPolicy Bypass -File tools/openworld/import_pack.ps1 "D:\other\ClashOpenWorld_GameReady"
param(
  [string]$Pack = "$env:USERPROFILE\Downloads\ClashOpenWorld_GameReady"
)
$ErrorActionPreference = "Stop"
if (-not (Test-Path -LiteralPath $Pack)) { throw "Pack not found: $Pack" }
$out = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "assets\openworld"
New-Item -ItemType Directory -Force -Path $out | Out-Null

# id = folder inside the pack (the folder holds <name>_atlas.png/.json).
$sheets = [ordered]@{
  "grass_dirt_mud" = "01_Terrain\grass_dirt_mud"
  "paths_water_cliffs" = "01_Terrain\paths_water_cliffs"
  "roads_bridges_crossings" = "01_Terrain\roads_bridges_crossings"
  "snow_ice_shadow" = "01_Terrain\snow_ice_shadow"
  "volcanic_lava_transitions" = "01_Terrain\volcanic_lava_transitions"
  "walls_corners" = "02_Walls_and_Gates\walls_corners"
  "gates_gatehouses_damage" = "02_Walls_and_Gates\gates_gatehouses_damage"
  "storages_townhall_builder" = "03_Buildings\storages_townhall_builder"
  "resource_extractors" = "03_Buildings\resource_extractors"
  "army_barracks_spells_lab" = "03_Buildings\army_barracks_spells_lab"
  "clan_castle_siege_props" = "03_Buildings\clan_castle_siege_props"
  "record_tower" = "03_Buildings\record_tower\record_tower"
  "builder_hut_idle_repair" = "04_Building_Animations\builder_hut_idle_repair"
  "army_camp_idle_fire" = "04_Building_Animations\army_camp_idle_fire"
  "defensive_towers" = "05_Defenses_and_Traps\defensive_towers"
  "builder" = "06_Units\builder\builder"
  "knight" = "06_Units\knight_hero\knight"
  "goblin" = "06_Units\goblin\goblin"
  "scout_reporter" = "06_Units\scout_reporter\scout_reporter"
  "royal_herald_mounted" = "06_Units\royal_herald_mounted\royal_herald_mounted"
  "barbarian_v2_idle_move" = "06_Units\barbarian_v2\barbarian_v2_idle_move"
  "barbarian_v2_combat" = "06_Units\barbarian_v2\barbarian_v2_combat"
  "archer_actions" = "06_Units\archer\archer_actions"
  "dragon" = "06_Units\dragon\dragon"
  "merchant_movement" = "06_Units\wandering_merchant\merchant_movement"
  "merchant_actions" = "06_Units\wandering_merchant\merchant_actions"
  "merchant_stall" = "06_Units\wandering_merchant\merchant_stall"
  "forest_guardian_frost_lord" = "07_Bosses\forest_guardian_frost_lord"
  "daily_chest" = "09_World_Objects\daily_chest\daily_chest"
  "flora_rocks_resources" = "09_World_Objects\flora_rocks_resources"
  "landmarks_pois" = "09_World_Objects\landmarks_pois"
  "battlefield_scars" = "09_World_Objects\battlefield_scars"
  "spells_flashes_explosions" = "08_VFX\spells_flashes_explosions"
  "command_movement_buff_fx" = "08_VFX\command_movement_buff_fx"
  "ui_elements_a" = "10_UI\ui_elements_a"
  "ui_elements_b" = "10_UI\ui_elements_b"
  "atlas_A_royal_archive" = "10_UI\royal_quest_ui\atlas_A_royal_archive"
  "atlas_B_scout_reports" = "10_UI\royal_quest_ui\atlas_B_scout_reports"
  "atlas_C_quest_board" = "10_UI\royal_quest_ui\atlas_C_quest_board"
  "atlas_D_challenge_buttons" = "10_UI\royal_quest_ui\atlas_D_challenge_buttons"
}

$ok = 0; $missing = @()
foreach ($id in $sheets.Keys) {
  $dir = Join-Path $Pack $sheets[$id]
  $json = Get-ChildItem -LiteralPath $dir -Filter "*_atlas.json" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $json) { $missing += $id; continue }
  $png = Join-Path $dir ($json.Name -replace "\.json$", ".png")
  Copy-Item -LiteralPath $json.FullName -Destination (Join-Path $out "$id.json") -Force
  Copy-Item -LiteralPath $png -Destination (Join-Path $out "$id.png") -Force
  $ok++
}
$anims = Join-Path $Pack "character_animations.json"
if (Test-Path -LiteralPath $anims) {
  Copy-Item -LiteralPath $anims -Destination (Join-Path $out "characters.json") -Force
  Write-Host "Copied character_animations.json"
} else { Write-Warning "character_animations.json not found" }
Write-Host "Imported $ok atlases into $out"
if ($missing.Count -gt 0) { Write-Warning ("Missing: " + ($missing -join ", ")) }
