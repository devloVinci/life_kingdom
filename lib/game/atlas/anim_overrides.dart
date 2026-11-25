import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The few characters used in v0.2 and their animation slots.
class CharacterSlots {
  CharacterSlots._();

  /// slot key -> (atlas id, default animation, label)
  static const slots = <String, (String, String, String)>{
    'knight.idle': ('knight', 'knight_set01_r1', 'الفارس · وقوف'),
    'knight.walk': ('knight', 'knight_set02_r3', 'الفارس · مشي'),
    'barbarian.idle':
        ('barbarian_v2_idle_move', 'barbarian_v2_idle_move_set01_r1', 'المحارب · وقوف'),
    'barbarian.walk':
        ('barbarian_v2_idle_move', 'barbarian_v2_idle_move_set03_r3', 'المحارب · مشي'),
    'archer.idle': ('archer_actions', 'archer_set01_r1', 'الرامية · وقوف'),
    'archer.walk': ('archer_actions', 'archer_set02_r3', 'الرامية · مشي'),
    'builder.work': ('builder', 'building_r1', 'البنّاء · عمل'),
    'builder.idle': ('builder', 'idle_r1', 'البنّاء · وقوف'),
    'goblin.idle': ('goblin', 'goblin_idle_r1', 'الغول · وقوف'),
  };
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
