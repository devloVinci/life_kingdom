# Character art & animation pipeline

Figma stays responsible for the UI. Characters come from a separate pipeline
that turns AI-painted artwork into animated, mesh-skinned characters that the
Flutter app plays with **no extra packages** (works on Flutter Web/Safari,
Android and iOS).

```
describe character ──► AI painting (Figma MCP: generate_image, gpt-image)
                    ──► key_background.py   transparent PNG, cropped
                    ──► specs/<slug>.json   bones, body regions, props, eyes, clips
                    ──► rigkit.py build     layers + mesh + bone weights -> assets/heroes/<slug>/
                    ──► rigkit.py preview   GIFs + contact sheet (same math as the app)
                    ──► SkinnedCharacter    Flutter widget (lib/core/characters/skinned/)
```

## 1. Research summary (Nov 2026)

| Tool | How Claude can drive it | Cost | Flutter | Verdict |
|---|---|---|---|---|
| **Rive – official MCP** (rive.app/docs/editor/ai/mcp) | Built into the Rive desktop editor (Windows/macOS); editor must be open; `claude mcp add --transport http rive http://127.0.0.1:9791/mcp`. Can create bones and weights, keyframes, state machines, view models. Raster-image import via MCP is not documented. | Editor free; Free-plan `.riv` exports show a Rive splash; Cadet $9/seat/month removes it | `rive` package (MIT) | Best **upgrade path** for interactive state machines; needs the desktop app on your PC |
| **rive-mcp** (ODU33104, npm `rive-mcp-server`, third-party) | Builds `.riv` from JSON, embeds PNGs, bones/meshes, `riv_rig_character`, renders GIF/APNG | Free, but closed-source freeware (no modification/redistribution) | `rive` package | Promising; could not be installed in Claude's cloud sandbox (blocked by policy). You can install it locally: `claude mcp add --scope user rive -- npx -y rive-mcp-server` (Node 20+, Chrome) |
| **Spine** (esotericsoftware.com) | No MCP; full CLI export (`Spine -i x.spine -o out -e export.json`) | Essential $69 (no meshes), Professional $369; runtime use requires a license | `spine_flutter` (official) | Industry standard, but paid and the editor is manual |
| **Live2D Cubism** | No MCP | Editor PRO paid; SDK release licence depends on revenue | community `flutter_live2d`: Android/iOS only | Rejected: no web support (the app runs as Flutter Web on iPhone) |
| **DragonBones** | – | Free | – | Rejected: discontinued |
| **Blender MCP** (ahujasid/blender-mcp, MIT) | Full Blender Python control | Free | via rendered sprites only | Rejected for now: 3D workflow, heavy, not painted 2D |
| **Krita MCPs** (KritaPilot, krita-codex-mcp, …) | Paint strokes / layers in a running Krita | Free (community) | PNG export | Not an animation tool; optional for touch-ups |
| **PixelLab MCP** (pixellab.ai) | Generate + animate characters | API key, paid credits | sprite sheets | Rejected: pixel-art style only |
| **AI painting via Figma MCP** (`generate_image`) | Already connected; Claude generates and downloads the art | Uses Figma AI credits on the Dragon plan | PNG | **Chosen** for artwork (no new account) |

**Decision.** Professional painted art from an image model, then a
Spine-style "mesh + bones" rig produced by our own free script, rendered by a
small Flutter runtime. It is fully automatable by Claude (no GUI editor), costs
nothing per export, keeps the app free of native dependencies, and the rig
format maps 1:1 onto Spine/Rive concepts if you later move to Rive.

## 2. Adding or replacing a character

1. **Paint.** Ask Claude for a character; it calls Figma `generate_image` with a
   prompt like the one in `specs/hero_knight.prompt.txt` (Supercell-style,
   full body, neutral pose, arms slightly away from the body, flat `#FF00FF`
   background).
2. **Key the background:**
   `python tools/character_pipeline/key_background.py raw.png hero.png --height 900`
3. **Write the spec** (`tools/character_pipeline/specs/<slug>.json`): bone pivots,
   body-region polygons, props that should be separate rigid layers
   (sword, shield, staff…), eye positions for blinking, and the animation clips.
4. **Build:** `python tools/character_pipeline/rigkit.py build specs/<slug>.json hero.png assets/heroes/<slug>`
5. **Verify:** `python tools/character_pipeline/rigkit.py preview assets/heroes/<slug>/rig.json out/`
   and look at the GIFs / contact sheet.
6. **Register** the folder under `flutter: assets:` in `pubspec.yaml` and use
   `SkinnedCharacter(folder: 'assets/heroes/<slug>')`.

Requirements: Python 3 with `numpy`, `pillow`, `opencv-python`.

## 3. Using the character in the app

```dart
final hero = CharacterAnimController();          // idle loop by default
SkinnedCharacter(controller: hero);              // any size, keeps aspect
hero.play('levelUp');                            // one-shot, returns to idle
hero.setLoop('walk');                            // change the loop
SkinnedCharacter(animate: false);                // still frame for lists
```

Clips in `hero_knight`: `idle` (breathing, sway, blinking), `walk`,
`victory`, `levelUp` (golden aura + particles), `hit` (red flash + shake),
`skill` (blue charge + thrust). Clips live in `rig.json`, so they can be tuned
without touching Dart. `Settings → Character Lab (preview)` shows all clips and
the hero reused at dashboard, profile, level-up, achievement and list sizes.

## 4. Known limits

- A single painting has no hidden areas. Props are cut into their own layers
  and the area behind them is filled automatically, but very large motions
  (e.g. raising the sword arm overhead) would stretch the art. Bigger poses
  need extra painted parts (an AI "parts sheet") or a dedicated Rive/Spine rig.
- Walking is an in-place march suitable for UI, not a side-view walk cycle.
