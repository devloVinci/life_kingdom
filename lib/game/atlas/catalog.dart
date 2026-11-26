import 'sprite_atlas.dart';

/// Semantic names for pack frames, so screens never hard-code file names.
/// Group names are the row names of the pack's `index.json` (the pack JSON
/// describes each row, e.g. `gold_mine_wood_row0..3`). Rows whose meaning
/// is a guess are marked; check them in the asset gallery (Diwan ->
/// asset gallery) and adjust here.
class Catalog {
  Catalog._();

  // ---- Buildings ----

  /// Style blocks of `town_hall_idle_upgrade` in build order: plain house,
  /// then scaffold and stone stages, then the gilded one. Block 1 (lit
  /// windows) is an ambient variant and is skipped. (order is a first guess)
  static const townHallBlocks = [0, 2, 3, 4, 5, 6, 7];

  /// Town hall frame for a stage 0..44, spread over the build-up frames.
  static String? townHall(FrameNames a, int stage) {
    final frames = <String>[
      for (final b in townHallBlocks) ...a.group('town_hall_style$b'),
    ];
    if (frames.isEmpty) return null;
    final i = (stage.clamp(0, 44) * (frames.length - 1) / 44).round();
    return frames[i];
  }

  static const goldMineGroups = [
    'gold_mine_wood',
    'gold_mine_stone',
    'gold_mine_reinforced',
    'gold_mine_golden',
  ];

  /// Gold mine frame for a stage 0..63.
  static String? goldMine(FrameNames a, int stage) {
    final g = a.group(goldMineGroups[(stage ~/ 16).clamp(0, 3)]);
    if (g.isEmpty) return null;
    return g[(stage % 16).clamp(0, g.length - 1)];
  }

  /// Record tower for level 1..8 (the pack draws exactly eight).
  static String? recordTower(FrameNames a, int level) {
    final l = a.anim('levels');
    if (l.isEmpty) return null;
    return l[(level - 1).clamp(0, l.length - 1)];
  }

  static String? recordFx(FrameNames a, int i) {
    final l = a.anim('star_sparkle');
    return l.isEmpty ? null : l[i % l.length];
  }

  static String? recordBanner(FrameNames a, int i) {
    final l = a.anim('banner_wave');
    return l.isEmpty ? null : l[i % l.length];
  }

  /// Daily chest: 0 empty ... 6 overflowing, 7 glowing (ready to claim).
  static String? dailyChest(FrameNames a, int frame) {
    final l = a.anim('fill_stages');
    return l.isEmpty ? null : l[frame.clamp(0, l.length - 1)];
  }

  /// Wall look by fortifications held: palisade, stone, gold trim.
  static const wallGroups = [
    'palisade_pieces',
    'stone_wall_pieces',
    'gold_wall_pieces',
  ];

  // ---- Ground / nature ----

  /// Terrain tile rows: tileset0 is plain grass, tileset1 tufted grass.
  static const grassGroups = ['tileset0_variants', 'tileset1_variants'];

  /// Snow and shadow come from `terrain_snow_ice_shadow`, lava from
  /// `terrain_volcanic_lava` (row choices are first guesses).
  static const snowGroup = 'tileset0_variants';
  static const volcanicGroup = 'tileset0_variants';
  static const shadowGroup = 'tileset4_variants';
  static const treeGroups = ['trees_deciduous', 'trees_pine'];
  static const rockGroup = 'rocks';
  static const bushGroup = 'bushes_plants';

  /// Indexed by `Landmark.group` in the army engine.
  static const landmarkGroups = [
    'watchtowers_signal',
    'ancient_ruins',
    'rest_camps',
    'mining_sites',
    'abandoned_ruins_tombs',
    'open_quarries',
  ];

  // ---- UI ----

  static String? coinIcon(FrameNames a) {
    final g = a.group('resource_icons');
    return g.isEmpty ? null : g.first;
  }
}
