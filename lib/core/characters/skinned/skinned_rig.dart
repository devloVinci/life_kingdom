import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Data model for a painted, mesh-skinned character exported by
/// `tools/character_pipeline/rigkit.py` (format `life-kingdom-skinned-rig`).
///
/// A character folder (e.g. `assets/heroes/hero_knight/`) contains:
///   rig.json            bones, layer meshes + weights, animation clips
///   <slug>_body.png     painted body (props cut out)
///   <slug>_<prop>.png   rigid props drawn on their own layer (sword, shield)
///
/// Swapping the artwork = re-running the pipeline and replacing the folder;
/// no Dart code changes are needed.
class SkinnedRig {
  SkinnedRig({
    required this.name,
    required this.slug,
    required this.width,
    required this.height,
    required this.ground,
    required this.bones,
    required this.layers,
    required this.eyes,
    required this.lidColor,
    required this.clips,
  });

  final String name;
  final String slug;
  final double width;
  final double height;
  final ui.Offset ground;
  final List<RigBone> bones;
  final List<RigLayer> layers;
  final List<RigEye> eyes;
  final ui.Color lidColor;
  final Map<String, RigClip> clips;

  static const format = 'life-kingdom-skinned-rig';

  factory SkinnedRig.fromJson(Map<String, dynamic> j) {
    if (j['format'] != format) {
      throw FormatException('Not a $format file');
    }
    final g = j['ground'] as List;
    final hex = (j['lidColor'] as String).substring(1);
    return SkinnedRig(
      name: j['name'] as String,
      slug: j['slug'] as String,
      width: (j['width'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
      ground: ui.Offset((g[0] as num).toDouble(), (g[1] as num).toDouble()),
      bones: [
        for (final b in j['bones'] as List)
          RigBone(
            name: b['name'] as String,
            parent: b['parent'] as int,
            hx: ((b['head'] as List)[0] as num).toDouble(),
            hy: ((b['head'] as List)[1] as num).toDouble(),
          ),
      ],
      layers: [
        for (final l in j['layers'] as List)
          RigLayer.fromJson(l as Map<String, dynamic>)
      ],
      eyes: [
        for (final e in j['eyes'] as List)
          RigEye(
            cx: ((e['c'] as List)[0] as num).toDouble(),
            cy: ((e['c'] as List)[1] as num).toDouble(),
            rx: ((e['r'] as List)[0] as num).toDouble(),
            ry: ((e['r'] as List)[1] as num).toDouble(),
            bone: e['bone'] as int,
          ),
      ],
      lidColor: ui.Color(0xFF000000 | int.parse(hex, radix: 16)),
      clips: {
        for (final e in (j['clips'] as Map<String, dynamic>).entries)
          e.key: RigClip.fromJson(e.key, e.value as Map<String, dynamic>),
      },
    );
  }

  int boneIndex(String name) => bones.indexWhere((b) => b.name == name);
}

class RigBone {
  const RigBone({
    required this.name,
    required this.parent,
    required this.hx,
    required this.hy,
  });

  final String name;
  final int parent; // -1 for the root
  final double hx, hy; // rest-pose pivot in image pixels
}

class RigEye {
  const RigEye({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.bone,
  });

  final double cx, cy, rx, ry;
  final int bone;
}

/// One textured triangle mesh. Positions are in rig (canvas) pixels; the
/// texture coordinates are positions minus [offsetX]/[offsetY].
class RigLayer {
  RigLayer({
    required this.name,
    required this.image,
    required this.offsetX,
    required this.offsetY,
    required this.positions,
    required this.triangles,
    required this.influences,
    required this.boneIds,
    required this.boneWeights,
  }) : uvs = Float32List(positions.length) {
    for (var i = 0; i < positions.length; i += 2) {
      uvs[i] = positions[i] - offsetX;
      uvs[i + 1] = positions[i + 1] - offsetY;
    }
  }

  final String name;
  final String image;
  final double offsetX, offsetY;
  final Float32List positions;
  final Float32List uvs;
  final Uint16List triangles;
  final int influences;
  final Int32List boneIds;
  final Float32List boneWeights;

  int get vertexCount => positions.length ~/ 2;

  factory RigLayer.fromJson(Map<String, dynamic> j) {
    final m = j['mesh'] as Map<String, dynamic>;
    final w = m['weights'] as List;
    final n = w.length ~/ 2;
    final ids = Int32List(n);
    final ws = Float32List(n);
    for (var i = 0; i < n; i++) {
      ids[i] = (w[2 * i] as num).toInt();
      ws[i] = (w[2 * i + 1] as num).toDouble();
    }
    final off = j['offset'] as List;
    return RigLayer(
      name: j['name'] as String,
      image: j['image'] as String,
      offsetX: (off[0] as num).toDouble(),
      offsetY: (off[1] as num).toDouble(),
      positions: Float32List.fromList([
        for (final v in m['positions'] as List) (v as num).toDouble()
      ]),
      triangles: Uint16List.fromList([
        for (final v in m['triangles'] as List) (v as num).toInt()
      ]),
      influences: m['influences'] as int,
      boneIds: ids,
      boneWeights: ws,
    );
  }
}

/// A key is (time in seconds, value). Values between keys use smoothstep
/// easing, identical to rigkit.py.
class RigTrack {
  RigTrack(this.times, this.values);

  final List<double> times;
  final List<double> values;

  factory RigTrack.fromJson(List raw) => RigTrack(
        [for (final k in raw) ((k as List)[0] as num).toDouble()],
        [for (final k in raw) ((k as List)[1] as num).toDouble()],
      );

  double sample(double t) {
    if (t <= times.first) return values.first;
    for (var i = 1; i < times.length; i++) {
      if (t <= times[i]) {
        final t0 = times[i - 1], t1 = times[i];
        var u = t1 == t0 ? 0.0 : (t - t0) / (t1 - t0);
        u = u * u * (3 - 2 * u);
        return values[i - 1] + (values[i] - values[i - 1]) * u;
      }
    }
    return values.last;
  }
}

class RigClip {
  RigClip({
    required this.name,
    required this.duration,
    required this.loop,
    required this.blink,
    required this.tracks,
    required this.fx,
  });

  final String name;
  final double duration;
  final bool loop;
  final bool blink;

  /// bone name -> channel (rot, tx, ty, sx, sy) -> track
  final Map<String, Map<String, RigTrack>> tracks;

  /// effect name (flash, hurt, shake, aura, glow, particles, sparkle, charge)
  final Map<String, RigTrack> fx;

  factory RigClip.fromJson(String name, Map<String, dynamic> j) {
    final tracks = <String, Map<String, RigTrack>>{};
    final fx = <String, RigTrack>{};
    (j['tracks'] as Map<String, dynamic>).forEach((bone, channels) {
      final m = {
        for (final c in (channels as Map<String, dynamic>).entries)
          c.key: RigTrack.fromJson(c.value as List),
      };
      if (bone == 'fx') {
        fx.addAll(m);
      } else {
        tracks[bone] = m;
      }
    });
    return RigClip(
      name: name,
      duration: (j['duration'] as num).toDouble(),
      loop: j['loop'] as bool? ?? false,
      blink: j['blink'] as bool? ?? false,
      tracks: tracks,
      fx: fx,
    );
  }

  /// Local clip time for an elapsed time (wraps when looping, clamps otherwise).
  double localTime(double elapsed) =>
      loop ? elapsed % duration : math.min(elapsed, duration);

  bool isFinished(double elapsed) => !loop && elapsed >= duration;
}

/// Loads and caches rigs and their textures from the asset bundle.
class SkinnedRigLoader {
  SkinnedRigLoader._();

  static final Map<String, Future<LoadedRig>> _cache = {};

  /// [folder] e.g. `assets/heroes/hero_knight`.
  static Future<LoadedRig> load(String folder, {AssetBundle? bundle}) {
    return _cache.putIfAbsent(folder, () async {
      final b = bundle ?? rootBundle;
      final rig = SkinnedRig.fromJson(
          jsonDecode(await b.loadString('$folder/rig.json'))
              as Map<String, dynamic>);
      final images = <ui.Image>[];
      for (final layer in rig.layers) {
        final data = await b.load('$folder/${layer.image}');
        final codec =
            await ui.instantiateImageCodec(data.buffer.asUint8List());
        images.add((await codec.getNextFrame()).image);
      }
      return LoadedRig(rig, images);
    });
  }

  static void evict(String folder) => _cache.remove(folder);
}

class LoadedRig {
  LoadedRig(this.rig, this.textures);

  final SkinnedRig rig;
  final List<ui.Image> textures; // one per layer, same order
}
