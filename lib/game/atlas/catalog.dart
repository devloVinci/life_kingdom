import 'sprite_atlas.dart';

/// Semantic names for pack frames, so screens never hard-code file names.
/// Directions of the 8 generic unit groups (set01..set08) are not labelled
/// in the pack; the values below are first guesses to check in the
/// in-app asset gallery (Diwan -> asset gallery) and adjust here.
class Catalog {
  Catalog._();

  // ---- Buildings ----

  static const townHallGroups = [
    'townhall_wood',
    'townhall_stone',
    'townhall_dark_fire',
  ];

  /// Town hall frame for a stage 0..44 (16 wood, 16 stone, 13 dark).
  static String? townHall(SpriteAtlas a, int stage) {
    var s = stage;
    for (final g in townHallGroups) {
      final frames = a.group(g);
      final usable = g == 'townhall_dark_fire' ? 13 : frames.length;
      if (s < usable && s < frames.length) return frames[s];
      s -= usable;
    }
    final last = a.group(townHallGroups.last);
    return last.isEmpty ? null : last[12.clamp(0, last.length - 1)];
  }

  static const goldMineGroups = [
    'gold_mine_t1_wood',
    'gold_mine_t2_stone',
    'gold_mine_t3_gilded',
    'gold_mine_t4_royal',
  ];

  /// Gold mine frame for a stage 0..63.
  static String? goldMine(SpriteAtlas a, int stage) {
    final g = a.group(goldMineGroups[(stage ~/ 16).clamp(0, 3)]);
    if (g.isEmpty) return null;
    return g[(stage % 16).clamp(0, g.length - 1)];
  }

  static String? recordTower(SpriteAtlas a, int level) {
    final l = a.anim('tower_levels');
    if (l.isEmpty) return null;
    return l[(level - 1).clamp(0, l.length - 1)];
  }

  static String? recordFx(SpriteAtlas a, int i) {
    final l = a.anim('record_markers_fx');
    return l.isEmpty ? null : l[i % l.length];
  }

  static String? dailyChest(SpriteAtlas a, int frame) {
    final l = a.anim('daily_chest_fill_and_ready');
    return l.isEmpty ? null : l[frame.clamp(0, l.length - 1)];
  }

  /// Wall look by fortifications held: palisade, stone, gold trim.
  static const wallGroups = ['wood_palisade', 'stone_wall', 'gold_trim_wall'];

  // ---- Units (animation names) ----

  static const knightIdle = 'knight_set01_r1';
  static const knightWalk = 'knight_set02_r3';
  static const builderWork = 'building_r1';
  static const builderIdle = 'idle_r1';
  static const builderWalk = 'walk_r3';
  static const goblinIdle = 'goblin_idle_r1';
  static const goblinDash = 'goblin_loot_dash_r3';

  // ---- Ground / nature ----

  static const grassGroups = ['grass_plain', 'grass_lush'];
  static const snowGroup = 'snow';
  static const volcanicGroup = 'volcanic_rock';
  static const shadowGroup = 'dark_cracked_ground';
  static const treeGroups = ['trees_deciduous', 'trees_pine'];
  static const rockGroup = 'rocks';
  static const bushGroup = 'bushes_plants';
  static const landmarkGroups = [
    'watchtowers_signal',
    'ancient_ruins',
    'rest_control_camps',
    'mining_sites',
    'abandoned_ruins_tombs',
    'stone_quarries',
  ];

  // ---- UI ----

  static String? coinIcon(SpriteAtlas a) {
    final g = a.group('resources_potions');
    return g.isEmpty ? null : g.first;
  }
}
