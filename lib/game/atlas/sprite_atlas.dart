import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One frame of a TexturePacker-style "JSON hash" atlas written by
/// tools/openworld/import_pack.py from the `ready_use_word` pack (pivot is a
/// fraction of the source size).
class AtlasFrame {
  const AtlasFrame({
    required this.src,
    required this.sourceSize,
    required this.trimOffset,
    required this.pivot,
  });

  final Rect src;
  final Size sourceSize;
  final Offset trimOffset;
  final Offset pivot;

  factory AtlasFrame.fromJson(Map<String, dynamic> j) {
    final f = j['frame'] as Map;
    final ss = j['sourceSize'] as Map;
    final sss = (j['spriteSourceSize'] as Map?) ?? const {'x': 0, 'y': 0};
    final p = (j['pivot'] as Map?) ?? const {'x': 0.5, 'y': 1.0};
    return AtlasFrame(
      src: Rect.fromLTWH((f['x'] as num).toDouble(), (f['y'] as num).toDouble(),
          (f['w'] as num).toDouble(), (f['h'] as num).toDouble()),
      sourceSize:
          Size((ss['w'] as num).toDouble(), (ss['h'] as num).toDouble()),
      trimOffset:
          Offset((sss['x'] as num).toDouble(), (sss['y'] as num).toDouble()),
      pivot: Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()),
    );
  }

  /// Where this frame lands when its pivot is placed at [at] with [scale].
  Rect destRect(Offset at, double scale) {
    final left = at.dx - pivot.dx * sourceSize.width * scale;
    final top = at.dy - pivot.dy * sourceSize.height * scale;
    return Rect.fromLTWH(left + trimOffset.dx * scale,
        top + trimOffset.dy * scale, src.width * scale, src.height * scale);
  }

  /// Bounding box of the untrimmed frame (used for tap targets).
  Rect bounds(Offset at, double scale) => Rect.fromLTWH(
      at.dx - pivot.dx * sourceSize.width * scale,
      at.dy - pivot.dy * sourceSize.height * scale,
      sourceSize.width * scale,
      sourceSize.height * scale);
}

/// Frame names by group or animation; what the catalog needs, so it can be
/// tested without an image.
abstract interface class FrameNames {
  List<String> group(String name);
  List<String> anim(String name);
}

/// Parsed atlas data without the image (testable without Flutter's engine).
class AtlasData implements FrameNames {
  AtlasData(this.frames, this.animations);

  final Map<String, AtlasFrame> frames;

  /// Animation name -> ordered frame names (e.g. `idle_r1`).
  final Map<String, List<String>> animations;

  factory AtlasData.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final frames = <String, AtlasFrame>{};
    (j['frames'] as Map).forEach((k, v) {
      frames[k as String] =
          AtlasFrame.fromJson(Map<String, dynamic>.from(v as Map));
    });
    final anims = <String, List<String>>{};
    ((j['animations'] as Map?) ?? const {}).forEach((k, v) {
      anims[k as String] = (v as List).cast<String>();
    });
    return AtlasData(frames, anims);
  }

  @override
  List<String> anim(String name) => animations[name] ?? const [];

  static final _suffix = RegExp(r'^(_row|_anim|_r)?\d+$');

  /// Frames of a group in reading order: every animation named
  /// `<name>_row0`, `<name>_anim1`, `<name>_r2` or `<name>3`, in file order.
  @override
  List<String> group(String name) {
    final out = <String>[];
    animations.forEach((key, frames) {
      if (key.startsWith(name) && _suffix.hasMatch(key.substring(name.length))) {
        out.addAll(frames);
      }
    });
    return out;
  }
}

class SpriteAtlas implements FrameNames {
  SpriteAtlas(this.id, this.image, this.data);

  final String id;
  final ui.Image image;
  final AtlasData data;

  AtlasFrame? frame(String name) => data.frames[name];
  @override
  List<String> anim(String name) => data.anim(name);
  @override
  List<String> group(String name) => data.group(name);

  /// Frame of a looping animation at time [t] seconds.
  String? animFrame(String anim, double t, {double fps = 8}) {
    final l = this.anim(anim);
    if (l.isEmpty) return null;
    return l[(t * fps).floor() % l.length];
  }

  /// Draws [frameName] with its pivot at [at]. Returns the tap bounds.
  Rect? draw(Canvas canvas, String frameName, Offset at,
      {double scale = 1, double opacity = 1, bool flipX = false}) {
    final f = frame(frameName);
    if (f == null) return null;
    final dst = f.destRect(at, scale);
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    if (opacity < 1) {
      paint.color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
    }
    if (flipX) {
      canvas.save();
      canvas.translate(at.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-at.dx, 0);
      canvas.drawImageRect(image, f.src, dst, paint);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, f.src, dst, paint);
    }
    return f.bounds(at, scale);
  }
}

/// Loads `assets/openworld/<id>.json` + `.png`. Null when the pack has not
/// been imported (see tools/openworld/import_pack.py), so screens can fall
/// back to placeholders instead of crashing.
Future<SpriteAtlas?> loadAtlas(String id, {AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  try {
    final json = await b.loadString('assets/openworld/$id.json');
    final bytes = await b.load('assets/openworld/$id.png');
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    return SpriteAtlas(id, image, AtlasData.parse(json));
  } catch (_) {
    return null;
  }
}

/// Atlases used by the open-world screens (ids from the pack's index.json).
class Atlases {
  Atlases._();

  static const kingdom = [
    'terrain_grass_dirt_mud',
    'town_hall_idle_upgrade',
    'resource_extractors',
    'record_tower',
    'builder',
    'knight',
    'goblin',
    'daily_chest',
    'flora_rocks_resources',
    'walls',
    'ui_elements',
    'military_buildings',
    'barbarian_v2',
    'archer',
  ];
  static const world = [
    'terrain_grass_dirt_mud',
    'terrain_snow_ice_shadow',
    'terrain_volcanic_lava',
    'flora_rocks_resources',
    'world_landmarks',
    'town_hall_idle_upgrade',
    'knight',
    'battlefield_scars',
    'barbarian_v2',
    'archer',
  ];

  /// Everything the import script copies (also listed in the gallery).
  static const all = [
    'knight',
    'barbarian_v2',
    'archer',
    'builder',
    'goblin',
    'hero_warlord_commander',
    'berserker',
    'heavy_knight',
    'lancer',
    'wizard',
    'cleric',
    'giant',
    'pekka',
    'dragon',
    'scout_reporter',
    'royal_monthly_herald',
    'wandering_merchant_walk',
    'wandering_merchant_actions',
    'wandering_merchant_trading',
    'forest_guardian',
    'frost_lord',
    'town_hall_idle_upgrade',
    'town_hall_damage',
    'storages_townhall_builder',
    'resource_extractors',
    'builder_hut_idle_repair',
    'military_buildings',
    'army_camp_idle_fire',
    'record_tower',
    'daily_chest',
    'merchant_stall',
    'walls',
    'gates_and_wall_damage',
    'defensive_towers',
    'terrain_grass_dirt_mud',
    'terrain_paths_water_cliffs',
    'terrain_snow_ice_shadow',
    'terrain_volcanic_lava',
    'roads_bridges',
    'flora_rocks_resources',
    'world_landmarks',
    'battlefield_scars',
    'battering_ram',
    'catapult',
    'ballista',
    'siege_tower',
    'mobile_cannon',
    'spells_explosions_vfx',
    'arrows_impact_fx',
    'command_fx',
    'hud_icons',
    'ui_elements',
    'ui_letters_maps',
    'ui_books_stationery',
    'ui_cards_badges',
    'ui_name_plates',
  ];
}

final atlasProvider =
    FutureProvider.family<SpriteAtlas?, String>((ref, id) => loadAtlas(id));

/// Loads a set of atlases; missing ones are simply absent from the map.
final atlasSetProvider = FutureProvider.family<Map<String, SpriteAtlas>, String>(
    (ref, key) async {
  final ids = key.split(',');
  final loaded = await Future.wait(ids.map((id) => ref.watch(atlasProvider(id).future)));
  return {
    for (var i = 0; i < ids.length; i++)
      if (loaded[i] != null) ids[i]: loaded[i]!,
  };
});
