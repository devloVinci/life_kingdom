import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sprite_atlas.dart';

/// One playable direction of a named animation, resolved from
/// assets/openworld/characters.json (written by tools/openworld/import_pack.py
/// from the pack's index.json).
class AnimRef {
  const AnimRef({
    required this.atlasId,
    required this.key,
    required this.fps,
    required this.loop,
    this.flipX = false,
  });

  /// Atlas id as imported (`knight`, `barbarian_v2`, ...).
  final String atlasId;

  /// Animation key inside that atlas (`walk_left`).
  final String key;
  final double fps;
  final bool loop;
  final bool flipX;
}

class AnimInfo {
  const AnimInfo(this.name, this.category, this.directions);
  final String name;

  /// movement | combat | other
  final String category;
  final List<String> directions;
}

class CharacterLibrary {
  CharacterLibrary(this._chars);

  /// character -> animation -> json
  final Map<String, Map<String, dynamic>> _chars;

  factory CharacterLibrary.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    final chars = <String, Map<String, dynamic>>{};
    (j['characters'] as Map).forEach((k, v) {
      chars[k as String] =
          Map<String, dynamic>.from((v as Map)['animations'] as Map);
    });
    return CharacterLibrary(chars);
  }

  Iterable<String> get characters => _chars.keys;

  List<AnimInfo> animations(String character) {
    final a = _chars[character];
    if (a == null) return const [];
    return [
      for (final e in a.entries)
        AnimInfo(
          e.key,
          ((e.value as Map)['category'] as String?) ?? 'other',
          ((e.value as Map)['directions'] as Map).keys.cast<String>().toList(),
        ),
    ];
  }

  bool has(String character, String animation) =>
      _chars[character]?.containsKey(animation) ?? false;

  /// Resolves [direction] (down/up/left/right), following `mirror_of`, and
  /// falling back to the nearest drawn direction.
  AnimRef? resolve(String character, String animation, String direction) {
    final anim = _chars[character]?[animation] as Map?;
    if (anim == null) return null;
    final dirs = Map<String, dynamic>.from(anim['directions'] as Map);
    final fps = ((anim['fps'] as num?) ?? 8).toDouble();
    final loop = (anim['loop'] as bool?) ?? true;

    AnimRef? build(String d, {bool flip = false, int depth = 0}) {
      final e = dirs[d] as Map?;
      if (e == null || depth > 2) return null;
      final mirror = e['mirror_of'] as String?;
      if (mirror != null) {
        final base = build(mirror, depth: depth + 1);
        if (base == null) return null;
        final f = (e['flip_x'] as bool?) ?? true;
        return AnimRef(
            atlasId: base.atlasId,
            key: base.key,
            fps: fps,
            loop: loop,
            flipX: f != flip);
      }
      final path = e['atlas_json'] as String?;
      final key = e['animation_key'] as String?;
      if (path == null || key == null) return null;
      return AnimRef(
          atlasId: atlasIdFromPath(path),
          key: key,
          fps: fps,
          loop: loop,
          flipX: flip);
    }

    // A direction, or an alternate take of it (`down_alt`, `right_b`...).
    AnimRef? pick(String d, {bool flip = false}) {
      final exact = build(d, flip: flip);
      if (exact != null) return exact;
      for (final k in dirs.keys) {
        if (k.startsWith('${d}_')) {
          final r = build(k, flip: flip);
          if (r != null) return r;
        }
      }
      return null;
    }

    final exact = pick(direction);
    if (exact != null) return exact;
    if (direction == 'left' || direction == 'right') {
      // A missing side is the other side flipped; profile art that is only
      // named `side` faces right.
      final other = direction == 'left' ? 'right' : 'left';
      final r = pick(other, flip: true) ?? pick('side', flip: direction == 'left');
      if (r != null) return r;
    }
    for (final d in ['down', 'right', 'left', 'up', ...dirs.keys]) {
      final r = build(d);
      if (r != null) return r;
    }
    return null;
  }

  /// `knight.json` (or an older `knight_atlas.json` path) -> `knight`.
  static String atlasIdFromPath(String path) {
    final file = path.split('/').last;
    return file.endsWith('_atlas.json')
        ? file.substring(0, file.length - '_atlas.json'.length)
        : file.replaceAll('.json', '');
  }
}

final characterLibraryProvider = FutureProvider<CharacterLibrary?>((ref) async {
  try {
    return CharacterLibrary.parse(
        await rootBundle.loadString('assets/openworld/characters.json'));
  } catch (_) {
    return null;
  }
});

/// Facing from a movement vector (screen space).
String facingOf(Offset v) {
  if (v.distanceSquared < 1e-6) return 'down';
  if (v.dx.abs() >= v.dy.abs()) return v.dx < 0 ? 'left' : 'right';
  return v.dy < 0 ? 'up' : 'down';
}

/// Draws one character animation frame. Returns false when the art is
/// missing (caller draws a placeholder).
bool drawCharacter(
  Canvas canvas, {
  required CharacterLibrary? lib,
  required Map<String, SpriteAtlas> atlases,
  required String character,
  required String animation,
  required String direction,
  required Offset at,
  required double t,
  double scale = 1,
  bool still = false,
  double opacity = 1,
}) {
  final r = lib?.resolve(character, animation, direction);
  if (r == null) return false;
  final a = atlases[r.atlasId];
  if (a == null) return false;
  final frames = a.anim(r.key);
  if (frames.isEmpty) return false;
  final i = still ? 0 : (t * r.fps).floor();
  final idx = r.loop ? i % frames.length : i.clamp(0, frames.length - 1);
  return a.draw(canvas, frames[idx], at,
          scale: scale, flipX: r.flipX, opacity: opacity) !=
      null;
}
