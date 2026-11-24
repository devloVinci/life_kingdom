import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

/// One stackable SVG layer of a character (all layers share one canvas).
class RigPart {
  const RigPart({required this.name, required this.file, required this.role});

  final String name;
  final String file;

  /// shadow | legL | legR | armL | armR | head | body
  final String role;
}

/// Parsed `rig.json` produced by tools/split_character.py.
class RigData {
  const RigData({
    required this.slug,
    required this.width,
    required this.height,
    required this.parts,
    required this.pivots,
  });

  final String slug;
  final double width;
  final double height;
  final List<RigPart> parts;
  final Map<String, Offset> pivots;

  double get aspect => width / height;

  String assetPath(RigPart p) => 'assets/characters/$slug/${p.file}';

  factory RigData.fromJson(Map<String, dynamic> j) {
    final pivots = <String, Offset>{};
    (j['pivots'] as Map<String, dynamic>).forEach((k, v) {
      final l = (v as List).map((e) => (e as num).toDouble()).toList();
      pivots[k] = Offset(l[0], l[1]);
    });
    return RigData(
      slug: j['slug'] as String,
      width: (j['width'] as num).toDouble(),
      height: (j['height'] as num).toDouble(),
      parts: [
        for (final p in j['parts'] as List)
          RigPart(
            name: p['name'] as String,
            file: p['file'] as String,
            role: p['role'] as String,
          ),
      ],
      pivots: pivots,
    );
  }

  static final Map<String, Future<RigData?>> _cache = {};

  /// Loads (and caches) a rig; resolves to null when the character has no art.
  static Future<RigData?> load(String slug, {AssetBundle? bundle}) {
    return _cache.putIfAbsent(slug, () async {
      try {
        final raw = await (bundle ?? rootBundle)
            .loadString('assets/characters/$slug/rig.json');
        return RigData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    });
  }
}

/// Characters that already have exported SVG art in assets/characters/<slug>/.
/// Add the slug here (and the folder to pubspec.yaml) when a new one is added.
const riggedCharacterSlugs = {
  'archer',
  'boar_rider',
  'brute',
  'builder',
  'crimson_maiden',
  'drake',
  'gremlin',
  'huntress_queen',
  'iron_colossus',
  'lancer_champion',
  'oracle',
  'raider',
  'seraph',
  'sorcerer',
  'warlord',
};

/// `char_builder` -> `builder`; null if the character has no art yet.
String? rigSlugForItemId(String itemId) {
  if (!itemId.startsWith('char_')) return null;
  final slug = itemId.substring(5);
  return riggedCharacterSlugs.contains(slug) ? slug : null;
}
