import 'dart:convert';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'character_anims.dart';
import 'sprite_atlas.dart';

/// The few characters used in the app and their animation slots. Names
/// come from the pack's index.json (via assets/openworld/characters.json).
class CharacterSlots {
  CharacterSlots._();

  /// slot -> (character, default animation, label, still frame)
  static const slots = <String, (String, String, String, bool)>{
    'knight.idle': ('knight', 'idle', 'الفارس · وقوف', false),
    'knight.walk': ('knight', 'walk', 'الفارس · مشي', false),
    // barbarian_v2 idles only front and back; combat_idle has all four sides.
    'barbarian.idle': ('barbarian_v2', 'combat_idle', 'المحارب · وقوف', false),
    'barbarian.walk': ('barbarian_v2', 'walk', 'المحارب · مشي', false),
    'archer.idle': ('archer', 'idle', 'الرامية · وقوف', false),
    'archer.walk': ('archer', 'walk', 'الرامية · مشي', false),
    'builder.work': ('builder', 'building', 'البنّاء · عمل', false),
    'builder.idle': ('builder', 'idle', 'البنّاء · وقوف', false),
    'goblin.idle': ('goblin', 'idle', 'الغول · وقوف', false),
  };

  static String character(String slot) => slots[slot]!.$1;
  static bool still(String slot) => slots[slot]!.$4;
}

/// Chosen animation per slot (saved on the device, shared by real and
/// sandbox modes). Missing keys fall back to the defaults above.
class AnimOverrides extends Notifier<Map<String, String>> {
  static const _key = 'ow_anim_overrides';

  @override
  Map<String, String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        state = Map<String, String>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {
      // No storage (tests): keep defaults.
    }
  }

  Future<void> set(String slot, String anim) async {
    state = {...state, slot: anim};
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(state));
    } catch (_) {}
  }

  Future<void> reset() async {
    state = const {};
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }
}

final animOverridesProvider =
    NotifierProvider<AnimOverrides, Map<String, String>>(AnimOverrides.new);

/// Animation name for a slot, with the user's choice applied.
String animFor(Map<String, String> overrides, String slot) =>
    overrides[slot] ?? CharacterSlots.slots[slot]!.$2;

/// Draws the animation chosen for [slot] (falls back to the default name if
/// a saved choice no longer exists in the library).
bool drawSlot(
  Canvas canvas, {
  required CharacterLibrary? lib,
  required Map<String, SpriteAtlas> atlases,
  required Map<String, String> overrides,
  required String slot,
  required String direction,
  required Offset at,
  required double t,
  double scale = 1,
}) {
  final char = CharacterSlots.character(slot);
  var anim = animFor(overrides, slot);
  if (lib != null && !lib.has(char, anim)) anim = CharacterSlots.slots[slot]!.$2;
  return drawCharacter(canvas,
      lib: lib,
      atlases: atlases,
      character: char,
      animation: anim,
      direction: direction,
      at: at,
      t: t,
      scale: scale,
      still: CharacterSlots.still(slot) && overrides[slot] == null);
}
