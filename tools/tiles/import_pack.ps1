# Copies the EPIC RPG World "Grass Land 2.0" free demo into assets/world/.
# The pack's licence does not allow redistributing its files, so they are
# not stored in git; run this once on each machine you build from.
#
#   powershell -ExecutionPolicy Bypass -File tools/tiles/import_pack.ps1 `
#     "D:\Downloads\Programs\EPIC RPG World Pack-[FREE Demo]Grass Land 2.0"
param(
  [string]$Pack = "D:\Downloads\Programs\EPIC RPG World Pack-[FREE Demo]Grass Land 2.0"
)
$ErrorActionPreference = "Stop"
$root = Join-Path $Pack "EPIC RPG World Pack - [FREE Demo]Grass Land 2.0-REWORK"
if (-not (Test-Path -LiteralPath $root)) { $root = $Pack }
$out = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "assets\world"
New-Item -ItemType Directory -Force -Path $out | Out-Null

Copy-Item -LiteralPath (Join-Path $root "Tilesets and props\Tilesets and props Demo.png") `
  -Destination (Join-Path $out "grassland_tiles.png") -Force

$tsx = Get-Content -LiteralPath (Join-Path $root "TiledMap Editor\Tilesets\Tilesets and props Demo.tsx") -Raw
$tsx = $tsx.Replace('source="../../Tilesets and props/Tilesets and props Demo.png"', 'source="grassland_tiles.png"')
$tsx = $tsx.Replace('name="Tilesets and props Demo"', 'name="grassland_tiles"')
Set-Content -LiteralPath (Join-Path $out "grassland_tiles.tsx") -Value $tsx -NoNewline -Encoding UTF8

$tmx = Get-Content -LiteralPath (Join-Path $root "TiledMap Editor\sample map demo.tmx") -Raw
$tmx = $tmx.Replace('source="Tilesets/Tilesets and props Demo.tsx"', 'source="grassland_tiles.tsx"')
Set-Content -LiteralPath (Join-Path $out "grassland.tmx") -Value $tmx -NoNewline -Encoding UTF8

Write-Host "Imported Grass Land into $out"
