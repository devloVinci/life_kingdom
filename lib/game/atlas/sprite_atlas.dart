import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One frame of a TexturePacker "JSON hash" atlas from the
/// ClashOpenWorld pack (pivot is a fraction of the source size).
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

/// Parsed atlas data without the image (testable without Flutter's engine).
class AtlasData {
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

  /// Frames of a group in reading order (`<group>_r1_f1` ... `_r4_f4`).
  List<String> group(String name) {
    final out = <String>[];
    for (var r = 1; r <= 4; r++) {
      out.addAll(animations['${name}_r$r'] ?? const []);
    }
    return out;
  }
}

class SpriteAtlas {
  SpriteAtlas(this.id, this.image, this.data);

  final String id;
  final ui.Image image;
  final AtlasData data;

  AtlasFrame? frame(String name) => data.frames[name];
  List<String> anim(String name) => data.animations[name] ?? const [];
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
/// been imported (see tools/openworld/import_pack.ps1), so screens can fall
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

/// Atlases used by the open-world screens.
class Atlases {
  Atlases._();

  static const kingdom = [
    'grass_dirt_mud',
    'storages_townhall_builder',
    'resource_extractors',
    'record_tower',
    'builder',
    'knight',
    'goblin',
    'daily_chest',
    'flora_rocks_resources',
    'walls_corners',
    'ui_elements_a',
  ];
  static const world = [
    'grass_dirt_mud',
    'snow_ice_shadow',
    'volcanic_lava_transitions',
    'flora_rocks_resources',
    'landmarks_pois',
    'storages_townhall_builder',
    'knight',
  ];

  /// Everything the import script copies (also listed in the gallery).
  static const all = [
    'grass_dirt_mud',
    'paths_water_cliffs',
    'roads_bridges_crossings',
    'snow_ice_shadow',
    'volcanic_lava_transitions',
    'walls_corners',
    'gates_gatehouses_damage',
    'storages_townhall_builder',
    'resource_extractors',
    'army_barracks_spells_lab',
    'clan_castle_siege_props',
    'record_tower',
    'builder_hut_idle_repair',
    'army_camp_idle_fire',
    'defensive_towers',
    'builder',
    'knight',
    'goblin',
    'scout_reporter',
    'royal_herald_mounted',
    'barbarian_v2_idle_move',
    'archer_actions',
    'dragon',
    'merchant_movement',
    'merchant_actions',
    'merchant_stall',
    'forest_guardian_frost_lord',
    'daily_chest',
    'flora_rocks_resources',
    'landmarks_pois',
    'battlefield_scars',
    'spells_flashes_explosions',
    'command_movement_buff_fx',
    'ui_elements_a',
    'ui_elements_b',
    'atlas_A_royal_archive',
    'atlas_B_scout_reports',
    'atlas_C_quest_board',
    'atlas_D_challenge_buttons',
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
