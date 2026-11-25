import 'dart:ui';

/// A sprite cut from the tileset image (pixel rect in grassland_tiles.png).
class PropSprite {
  const PropSprite(this.src, {this.shadow});

  final Rect src;

  /// Optional ground shadow drawn under the sprite.
  final Rect? shadow;
}

/// Sprites in the EPIC RPG World free demo tileset.
class Sprites {
  Sprites._();

  static const well = PropSprite(Rect.fromLTWH(649, 565, 74, 54));
  static const tree = PropSprite(Rect.fromLTWH(266, 341, 102, 179),
      shadow: Rect.fromLTWH(296, 551, 75, 41));
  static const bushFlowers = PropSprite(Rect.fromLTWH(198, 495, 48, 33));
  static const bush = PropSprite(Rect.fromLTWH(207, 560, 70, 40));
  static const rockBig = PropSprite(Rect.fromLTWH(609, 494, 65, 44));
  static const rockMid = PropSprite(Rect.fromLTWH(679, 512, 46, 33));
  static const rockSmall = PropSprite(Rect.fromLTWH(675, 482, 27, 27));
  static const pebble = PropSprite(Rect.fromLTWH(709, 492, 20, 13));
  static const grassA = PropSprite(Rect.fromLTWH(389, 356, 29, 28));
  static const grassB = PropSprite(Rect.fromLTWH(416, 358, 31, 25));
  static const grassC = PropSprite(Rect.fromLTWH(384, 387, 28, 25));
  static const grassD = PropSprite(Rect.fromLTWH(486, 398, 28, 19));
  static const grassE = PropSprite(Rect.fromLTWH(425, 417, 23, 13));
}

/// A sprite placed in the world. [foot] is the bottom-centre point in map
/// pixels; props are drawn in order of [foot].dy so nearer ones overlap.
class WorldProp {
  const WorldProp(this.id, this.sprite, this.foot, {this.sways = false});

  final String id;
  final PropSprite sprite;
  final Offset foot;

  /// Tall grass sways gently in the wind.
  final bool sways;

  Rect get bounds => Rect.fromLTWH(foot.dx - sprite.src.width / 2,
      foot.dy - sprite.src.height, sprite.src.width, sprite.src.height);
}

/// Layout of the Grass Land home world (map is 30x20 tiles of 32 px).
class GrassLandLayout {
  GrassLandLayout._();

  /// Centre of the starting clearing: the well on the raised plateau.
  static const home = Offset(606, 430);

  static const props = <WorldProp>[
    WorldProp('well', Sprites.well, Offset(606, 440)),
    WorldProp('g_home_1', Sprites.grassA, Offset(566, 392), sways: true),
    WorldProp('g_home_2', Sprites.grassC, Offset(650, 476), sways: true),
    WorldProp('g_home_3', Sprites.grassE, Offset(582, 488), sways: true),
    WorldProp('pebble_home', Sprites.pebble, Offset(652, 404)),
    WorldProp('rock_steps', Sprites.rockSmall, Offset(512, 446)),
    WorldProp('bush_flowers_1', Sprites.bushFlowers, Offset(478, 498)),
    WorldProp('rock_big_1', Sprites.rockBig, Offset(470, 332)),
    WorldProp('g_mid_1', Sprites.grassB, Offset(430, 380), sways: true),
    WorldProp('g_mid_2', Sprites.grassD, Offset(760, 432), sways: true),
    WorldProp('rock_mid_1', Sprites.rockMid, Offset(760, 520)),
    WorldProp('g_mid_3', Sprites.grassA, Offset(700, 300), sways: true),
    WorldProp('bush_1', Sprites.bush, Offset(372, 470)),
    WorldProp('rock_small_2', Sprites.rockSmall, Offset(352, 548)),
    WorldProp('tree_1', Sprites.tree, Offset(92, 636)),
    WorldProp('g_far_1', Sprites.grassC, Offset(250, 380), sways: true),
    WorldProp('rock_mid_2', Sprites.rockMid, Offset(318, 300)),
    WorldProp('bush_flowers_2', Sprites.bushFlowers, Offset(820, 210)),
    WorldProp('g_far_2', Sprites.grassB, Offset(560, 180), sways: true),
    WorldProp('rock_big_2', Sprites.rockBig, Offset(880, 630)),
    WorldProp('bush_2', Sprites.bush, Offset(130, 566)),
    WorldProp('g_far_3', Sprites.grassD, Offset(110, 250), sways: true),
    WorldProp('pebble_far', Sprites.pebble, Offset(60, 450)),
    WorldProp('g_far_4', Sprites.grassE, Offset(420, 90), sways: true),
  ];
}
