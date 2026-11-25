import 'package:flutter/material.dart';

/// Tree silhouettes the world painter knows how to draw.
enum TreeKind { blossom, broadleaf, autumn, frosted }

/// Weather / ambient particles.
enum Particle { petals, pollen, leaves, snow }

/// A world environment pack. The map reads everything visual from here, so a
/// new season (or a non-seasonal environment) is one more entry in [all].
class SeasonPack {
  const SeasonPack({
    required this.id,
    required this.name,
    required this.tagline,
    required this.skyTop,
    required this.skyBottom,
    required this.grass,
    required this.grassDark,
    required this.grassTuft,
    required this.path,
    required this.pathEdge,
    required this.water,
    required this.waterLight,
    required this.tree,
    required this.foliage,
    required this.flowers,
    required this.particle,
    required this.particleColors,
    required this.particleCount,
    required this.light,
    required this.lightStrength,
    this.snowOnRoofs = false,
    this.ambience = '',
  });

  /// Shop item id, e.g. `season_spring`.
  final String id;
  final String name;
  final String tagline;
  final Color skyTop, skyBottom;
  final Color grass, grassDark, grassTuft;
  final Color path, pathEdge;
  final Color water, waterLight;
  final TreeKind tree;

  /// Foliage ramp: light, mid, dark.
  final List<Color> foliage;
  final List<Color> flowers;
  final Particle particle;
  final List<Color> particleColors;
  final int particleCount;

  /// Colour grade laid over the whole world (warm summer, cool winter...).
  final Color light;
  final double lightStrength;
  final bool snowOnRoofs;

  /// Name of the ambient sound loop (reserved for the sound packs).
  final String ambience;

  static const spring = SeasonPack(
    id: 'season_spring',
    name: 'Spring Bloom',
    tagline: 'Cherry blossoms, fresh grass and drifting petals.',
    skyTop: Color(0xFF9FD8F5),
    skyBottom: Color(0xFFE6F6EC),
    grass: Color(0xFF8ED16B),
    grassDark: Color(0xFF5DA54A),
    grassTuft: Color(0xFFB8E68F),
    path: Color(0xFFE2C79A),
    pathEdge: Color(0xFFB99A6A),
    water: Color(0xFF5BB8D9),
    waterLight: Color(0xFFBDEBF7),
    tree: TreeKind.blossom,
    foliage: [Color(0xFFFFD6E4), Color(0xFFF2A0BE), Color(0xFFB8678A)],
    flowers: [Color(0xFFFFF4A8), Color(0xFFFFB3CF), Color(0xFFFFFFFF)],
    particle: Particle.petals,
    particleColors: [Color(0xFFFFC7DA), Color(0xFFFFE3EC)],
    particleCount: 26,
    light: Color(0xFFFFF0F5),
    lightStrength: 0.06,
    ambience: 'birdsong',
  );

  static const summer = SeasonPack(
    id: 'season_summer',
    name: 'High Summer',
    tagline: 'Warm light, lush trees and lazy pollen in the air.',
    skyTop: Color(0xFF6CC4F2),
    skyBottom: Color(0xFFCFEFFF),
    grass: Color(0xFF7CC556),
    grassDark: Color(0xFF4C9638),
    grassTuft: Color(0xFFA4DC6E),
    path: Color(0xFFDDBA82),
    pathEdge: Color(0xFFAE8A55),
    water: Color(0xFF3FA9D6),
    waterLight: Color(0xFFA9E3F6),
    tree: TreeKind.broadleaf,
    foliage: [Color(0xFF9BD45E), Color(0xFF4E9C38), Color(0xFF2A5E25)],
    flowers: [Color(0xFFFFE066), Color(0xFFFF8A5C), Color(0xFFFFFFFF)],
    particle: Particle.pollen,
    particleColors: [Color(0xFFFFF6C8), Color(0xFFFFFFFF)],
    particleCount: 18,
    light: Color(0xFFFFE2A8),
    lightStrength: 0.08,
    ambience: 'meadow',
  );

  static const autumn = SeasonPack(
    id: 'season_autumn',
    name: 'Golden Autumn',
    tagline: 'Amber forests, falling leaves and a low warm sun.',
    skyTop: Color(0xFFF2B47A),
    skyBottom: Color(0xFFFCE4C4),
    grass: Color(0xFFB4B357),
    grassDark: Color(0xFF7E7A35),
    grassTuft: Color(0xFFD1C46E),
    path: Color(0xFFD7AE78),
    pathEdge: Color(0xFFA27A48),
    water: Color(0xFF4F93B8),
    waterLight: Color(0xFFB7D7E6),
    tree: TreeKind.autumn,
    foliage: [Color(0xFFFFC75A), Color(0xFFE5782E), Color(0xFF9C3A1E)],
    flowers: [Color(0xFFE8A23A), Color(0xFFC75B2B), Color(0xFFF2D27A)],
    particle: Particle.leaves,
    particleColors: [Color(0xFFE5782E), Color(0xFFFFB23F), Color(0xFFB8442A)],
    particleCount: 22,
    light: Color(0xFFFFB46A),
    lightStrength: 0.12,
    ambience: 'wind',
  );

  static const winter = SeasonPack(
    id: 'season_winter',
    name: 'Frostfall',
    tagline: 'Snow-capped roofs, frosted pines and quiet snowfall.',
    skyTop: Color(0xFF9DB7D6),
    skyBottom: Color(0xFFE9F0F7),
    grass: Color(0xFFE8EFF5),
    grassDark: Color(0xFFB8C8D8),
    grassTuft: Color(0xFFFFFFFF),
    path: Color(0xFFC9C3BA),
    pathEdge: Color(0xFF9A928A),
    water: Color(0xFF9CC9E2),
    waterLight: Color(0xFFE8F6FD),
    tree: TreeKind.frosted,
    foliage: [Color(0xFF6E9C8E), Color(0xFF3E6B60), Color(0xFF1F3E39)],
    flowers: [Color(0xFFFFFFFF), Color(0xFFDCEBF7), Color(0xFFBFD6EA)],
    particle: Particle.snow,
    particleColors: [Color(0xFFFFFFFF), Color(0xFFE8F2FB)],
    particleCount: 60,
    light: Color(0xFFB9D3F0),
    lightStrength: 0.14,
    snowOnRoofs: true,
    ambience: 'snowfall',
  );

  static const all = [spring, summer, autumn, winter];

  static SeasonPack byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => summer);
}
