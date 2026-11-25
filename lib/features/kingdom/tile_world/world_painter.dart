import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/world/tile_map.dart';
import 'world_props.dart';

/// Colour of unexplored land.
const Color worldFogColor = Color(0xFF0B0F1A);

/// Size of one fog cell in map pixels (half a tile: chunky, pixel-art edge).
const double _cell = 16;

/// Tile layers, packed once for a single drawAtlas call.
class TileAtlas {
  TileAtlas(this.map) {
    final tw = map.tileWidth.toDouble();
    final th = map.tileHeight.toDouble();
    for (final layer in map.layers) {
      if (!layer.visible) continue;
      for (var i = 0; i < layer.gids.length; i++) {
        final gid = layer.gids[i];
        if (gid == 0) continue;
        final t = gid - map.firstGid;
        rects.add(Rect.fromLTWH(
            (t % map.columns) * tw, (t ~/ map.columns) * th, tw, th));
        transforms.add(ui.RSTransform.fromComponents(
          rotation: 0,
          scale: 1,
          anchorX: 0,
          anchorY: 0,
          translateX: (i % map.width) * tw,
          translateY: (i ~/ map.width) * th,
        ));
      }
    }
  }

  final TileMapData map;
  final List<Rect> rects = [];
  final List<ui.RSTransform> transforms = [];
}

/// Pseudo-random 0..1 per fog cell, so the land's edge looks natural.
/// (Same formula as tools/tiles/preview_world.py.)
double cellNoise(int x, int y) =>
    (((x * 73856093) ^ (y * 19349663)) & 0xFFFF) / 65535.0;

/// Fog opacity (0 = open land, 1 = unexplored) for a point in map pixels,
/// stepped in quarters for a pixel-art look.
double fogAlpha(Offset p, Offset home, double radius, {double tile = 32}) {
  var d = (p - home).distance / tile;
  d += (cellNoise(p.dx ~/ _cell, p.dy ~/ _cell) - 0.5) * 1.1;
  final open = ((radius - d) / 1.6).clamp(0.0, 1.0);
  return ((1 - open) * 4).ceil() / 4;
}

/// Draws the home world: tile layers, y-sorted props, wind, and the fog of
/// unexplored land.
class WorldPainter extends CustomPainter {
  WorldPainter({
    required this.atlas,
    required this.image,
    required this.radius,
    required this.clock,
    required this.home,
  }) : super(repaint: clock);

  final TileAtlas atlas;
  final ui.Image image;

  /// Open-land radius in tiles.
  final double radius;

  /// Seconds, for wind and fireflies (stays 0 when animation is off).
  final ValueListenable<double> clock;
  double get time => clock.value;
  final Offset home;

  static final Paint _pixel = Paint()
    ..filterQuality = FilterQuality.none
    ..isAntiAlias = false;

  static final List<WorldProp> _sorted = [...GrassLandLayout.props]
    ..sort((a, b) => a.foot.dy.compareTo(b.foot.dy));

  @override
  void paint(Canvas canvas, Size size) {
    final map = atlas.map;
    final bounds = Rect.fromLTWH(0, 0, map.pixelWidth, map.pixelHeight);
    canvas.drawRect(bounds, Paint()..color = worldFogColor);
    canvas.drawAtlas(image, atlas.transforms, atlas.rects, null, null, null,
        _pixel);

    for (final p in _sorted) {
      _drawProp(canvas, p);
    }

    _drawFireflies(canvas);
    _drawFog(canvas, bounds);
  }

  void _drawProp(Canvas canvas, WorldProp p) {
    final shadow = p.sprite.shadow;
    if (shadow != null) {
      canvas.drawImageRect(
          image,
          shadow,
          Rect.fromLTWH(p.foot.dx - shadow.width / 2,
              p.foot.dy - shadow.height + 6, shadow.width, shadow.height),
          _pixel);
    }
    final dst = p.bounds;
    if (p.sways && time > 0) {
      // Skew the top of the grass tuft a pixel or two, keeping its base fixed.
      final phase = p.foot.dx * .05 + p.foot.dy * .03;
      final lean = (math.sin(time * 1.6 + phase) * 1.5).roundToDouble();
      canvas.save();
      canvas.translate(p.foot.dx, p.foot.dy);
      canvas.transform(_skewX(-lean / dst.height));
      canvas.translate(-p.foot.dx, -p.foot.dy);
      canvas.drawImageRect(image, p.sprite.src, dst, _pixel);
      canvas.restore();
    } else {
      canvas.drawImageRect(image, p.sprite.src, dst, _pixel);
    }
  }

  /// A few drifting motes of light over the open land.
  void _drawFireflies(Canvas canvas) {
    if (time <= 0) return;
    final paint = Paint()..isAntiAlias = false;
    final r = radius * 32;
    for (var i = 0; i < 14; i++) {
      final a = cellNoise(i, 7) * math.pi * 2 + time * (.05 + cellNoise(i, 3) * .08);
      final dist = r * (.25 + cellNoise(i, 11) * .6);
      final bob = math.sin(time * 1.3 + i) * 6;
      final pos = home + Offset(math.cos(a) * dist, math.sin(a) * dist + bob);
      final glow = (math.sin(time * 2.1 + i * 1.7) + 1) / 2;
      if (glow < .25) continue;
      final x = pos.dx.roundToDouble();
      final y = pos.dy.roundToDouble();
      paint.color = const Color(0xFFFFF2A8).withOpacity(.35 + glow * .55);
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2), paint);
      paint.color = const Color(0xFFFFF2A8).withOpacity(.15 * glow);
      canvas.drawRect(Rect.fromLTWH(x - 2, y - 2, 6, 6), paint);
    }
  }

  void _drawFog(Canvas canvas, Rect bounds) {
    final paint = Paint()..isAntiAlias = false;
    final cols = (bounds.width / _cell).ceil();
    final rows = (bounds.height / _cell).ceil();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final c = Offset((x + .5) * _cell, (y + .5) * _cell);
        var a = fogAlpha(c, home, radius);
        if (a <= 0) continue;
        if (a < 1 && time > 0) {
          // The frontier shimmers softly, hinting there is more to find.
          a = (a + math.sin(time * 1.2 + cellNoise(x, y) * 6) * .06)
              .clamp(0.0, 1.0)
              .toDouble();
        }
        paint.color = worldFogColor.withOpacity(a * .95);
        canvas.drawRect(Rect.fromLTWH(x * _cell, y * _cell, _cell, _cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(WorldPainter old) =>
      old.radius != radius || old.image != image || old.clock != clock;
}

/// Column-major 4x4 matrix that shifts x by [k] per unit of y.
Float64List _skewX(double k) =>
    Float64List.fromList([1, 0, 0, 0, k, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
