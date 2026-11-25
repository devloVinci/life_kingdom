import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/world/season.dart';
import '../../../core/world/world_layout.dart';

const _ink = Color(0xFF1A1622);

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

// ---------------------------------------------------------------------------
// Ground: grass, roads, plaza, water, mountains. Static per season.
// ---------------------------------------------------------------------------

class GroundPainter extends CustomPainter {
  GroundPainter(this.season);

  final SeasonPack season;

  @override
  void paint(Canvas canvas, Size size) {
    final s = season;
    final world = Offset.zero & WorldLayout.size;
    final rnd = math.Random(3);

    canvas.drawRect(
      world,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_mix(s.grass, s.grassTuft, 0.25), s.grass, _mix(s.grass, s.grassDark, 0.35)],
        ).createShader(world),
    );

    // Soft light and dark patches so the grass is not flat.
    for (var i = 0; i < 80; i++) {
      final c = Offset(rnd.nextDouble() * world.width, rnd.nextDouble() * world.height);
      final r = 50 + rnd.nextDouble() * 140;
      final col = (i.isEven ? s.grassDark : s.grassTuft).withValues(alpha: 0.28);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [col, col.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    _mountains(canvas);
    _water(canvas, WorldLayout.lake, big: true);
    _water(canvas, WorldLayout.pond);
    _nest(canvas);

    // Grass tufts.
    final tuft = Paint()
      ..color = s.grassDark.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final tuftLight = Paint()
      ..color = s.grassTuft.withValues(alpha: 0.9)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 900; i++) {
      final p = Offset(rnd.nextDouble() * world.width, 260 + rnd.nextDouble() * (world.height - 260));
      final k = 3 + rnd.nextDouble() * 3;
      canvas.drawLine(p, p + Offset(-k * 0.5, -k), tuft);
      canvas.drawLine(p, p + Offset(k * 0.4, -k * 1.1), tuftLight);
    }

    // Flowers.
    for (final (i, f) in WorldLayout.flowers.indexed) {
      final col = s.flowers[i % s.flowers.length];
      for (var j = 0; j < 4; j++) {
        final q = f + Offset(math.cos(j * 1.7 + i) * 6, math.sin(j * 2.3 + i) * 3.5);
        canvas.drawCircle(q, 1.9, Paint()..color = col);
        canvas.drawCircle(q, 0.8, Paint()..color = const Color(0xFFFFF3B0));
      }
    }

    // Roads.
    final edge = Paint()
      ..color = s.pathEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = s.path
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final roads = WorldLayout.roads.map(_pathOf).toList();
    for (final r in roads) {
      canvas.drawPath(r, edge);
    }
    for (final r in roads) {
      canvas.drawPath(r, fill);
      canvas.drawPath(r.shift(const Offset(-2, -3)), shine);
    }
    final pebble = Paint()..color = s.pathEdge.withValues(alpha: 0.55);
    for (final road in WorldLayout.roads) {
      for (var i = 1; i < road.length; i++) {
        final q = road[i] + Offset(rnd.nextDouble() * 14 - 7, rnd.nextDouble() * 10 - 5);
        canvas.drawOval(Rect.fromCenter(center: q, width: 3.2, height: 2), pebble);
      }
    }

    _plaza(canvas);
  }

  Path _pathOf(List<Offset> pts) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      p.lineTo(q.dx, q.dy);
    }
    return p;
  }

  void _plaza(Canvas canvas) {
    final s = season;
    const c = WorldLayout.plaza;
    const r = WorldLayout.plazaRadius;
    final oval = Rect.fromCenter(center: c, width: r * 2, height: r * 1.45);
    canvas.drawOval(oval.inflate(6), Paint()..color = s.pathEdge);
    canvas.drawOval(
      oval,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [_mix(s.path, Colors.white, 0.3), s.path, _mix(s.path, s.pathEdge, 0.5)],
        ).createShader(oval),
    );
    final line = Paint()
      ..color = s.pathEdge.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final k in [0.38, 0.68]) {
      canvas.drawOval(Rect.fromCenter(center: c, width: r * 2 * k, height: r * 1.45 * k), line);
    }
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8;
      canvas.drawLine(c + Offset(math.cos(a) * r * 0.38, math.sin(a) * r * 0.27),
          c + Offset(math.cos(a) * r * 0.98, math.sin(a) * r * 0.71), line);
    }
    // Fountain basin.
    final basin = Rect.fromCenter(center: c + const Offset(0, 4), width: 64, height: 34);
    canvas.drawOval(basin.shift(const Offset(3, 5)), Paint()..color = Colors.black.withValues(alpha: 0.18));
    canvas.drawOval(basin.inflate(2), Paint()..color = _ink);
    canvas.drawOval(
        basin,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFF1EADC), Color(0xFFA89C86)])
              .createShader(basin));
    final water = basin.deflate(6);
    canvas.drawOval(
        water,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [s.waterLight, s.water],
          ).createShader(water));
    // Pillar.
    final pillar = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c + const Offset(0, -6), width: 10, height: 26), const Radius.circular(3));
    canvas.drawRRect(pillar.inflate(1.6), Paint()..color = _ink);
    canvas.drawRRect(
        pillar,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xFFF7F0E2), Color(0xFF9C8F78)])
              .createShader(pillar.outerRect));
    final bowl = Rect.fromCenter(center: c + const Offset(0, -19), width: 26, height: 10);
    canvas.drawOval(bowl.inflate(1.6), Paint()..color = _ink);
    canvas.drawOval(bowl, Paint()..color = const Color(0xFFE6DCC8));
    canvas.drawOval(bowl.deflate(3), Paint()..color = s.water);
  }

  void _water(Canvas canvas, Rect r, {bool big = false}) {
    final s = season;
    final frozen = s.particle == Particle.snow;
    final shape = big
        ? (Path()
          ..moveTo(r.left + r.width * 0.5, r.top)
          ..cubicTo(r.right + 10, r.top + 40, r.right, r.top + r.height * 0.45, r.right - 10, r.top + r.height * 0.6)
          ..cubicTo(r.right - 20, r.bottom - 40, r.left + r.width * 0.6, r.bottom + 10, r.left + 20, r.bottom - 30)
          ..cubicTo(r.left - 20, r.bottom - 120, r.left + 30, r.top + r.height * 0.5, r.left + 6, r.top + 120)
          ..cubicTo(r.left - 10, r.top + 50, r.left + 20, r.top - 6, r.left + r.width * 0.5, r.top)
          ..close())
        : (Path()..addOval(r));
    canvas.drawPath(shape.shift(const Offset(0, 4)), Paint()..color = Colors.black.withValues(alpha: 0.12));
    canvas.drawPath(
        shape,
        Paint()
          ..color = _mix(s.path, s.pathEdge, 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    canvas.drawPath(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: frozen
                ? [Colors.white, s.waterLight, s.water]
                : [s.waterLight, s.water, _mix(s.water, const Color(0xFF0B2B45), 0.4)],
          ).createShader(r));
    final hi = Paint()
      ..color = Colors.white.withValues(alpha: frozen ? 0.8 : 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = frozen ? 1.2 : 2
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(r.left.toInt());
    for (var i = 0; i < (big ? 14 : 4); i++) {
      final x = r.left + 20 + rnd.nextDouble() * (r.width - 40);
      final y = r.top + 20 + rnd.nextDouble() * (r.height - 40);
      if (frozen) {
        canvas.drawLine(Offset(x, y), Offset(x + 14, y + 8), hi);
        canvas.drawLine(Offset(x + 14, y + 8), Offset(x + 10, y + 20), hi);
      } else {
        canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 24, height: 8), math.pi * 1.1, math.pi * 0.8, false, hi);
      }
    }
    // Reeds / stones along the shore.
    if (!big) {
      for (var i = 0; i < 6; i++) {
        final a = math.pi * (0.9 + i * 0.12);
        final p = r.center + Offset(math.cos(a) * r.width * 0.5, math.sin(a) * r.height * 0.5);
        canvas.drawLine(p, p + const Offset(-1, -12), Paint()
          ..color = frozen ? const Color(0xFF9AA8B5) : season.grassDark
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round);
      }
    }
  }

  void _mountains(Canvas canvas) {
    final s = season;
    final snowy = s.particle == Particle.snow;
    const peaks = [
      (60.0, 250.0, 120.0, 150.0), (200.0, 255.0, 150.0, 190.0), (360.0, 250.0, 140.0, 170.0),
      (520.0, 260.0, 170.0, 225.0), (690.0, 250.0, 150.0, 180.0), (850.0, 255.0, 160.0, 200.0),
      (1010.0, 250.0, 130.0, 160.0),
    ];
    for (final back in [true, false]) {
      for (final (i, pk) in peaks.indexed) {
        final (x0, base, half, h) = pk;
        final x = x0 + (back ? 70 : 0);
        final by = base - (back ? 40 : 0);
        final hh = h * (back ? 0.8 : 1);
        final top = Offset(x + (i.isEven ? 8 : -6), by - hh);
        final body = Path()
          ..moveTo(x - half, by)
          ..lineTo(top.dx, top.dy)
          ..lineTo(x + half, by)
          ..close();
        final rock = back
            ? [const Color(0xFFA9B3C4), const Color(0xFF8790A3)]
            : [const Color(0xFF8E96A6), const Color(0xFF5B6274)];
        canvas.drawPath(body, Paint()..color = _mix(rock[1], s.skyTop, back ? 0.35 : 0.1));
        // Lit left face.
        final lit = Path()
          ..moveTo(x - half, by)
          ..lineTo(top.dx, top.dy)
          ..lineTo(top.dx + 6, by)
          ..close();
        canvas.drawPath(lit, Paint()..color = _mix(rock[0], s.skyTop, back ? 0.35 : 0.08));
        // Snow cap.
        final capH = hh * (snowy ? 0.55 : 0.3);
        final k = capH / hh;
        final cap = Path()
          ..moveTo(top.dx, top.dy)
          ..lineTo(top.dx - half * k, top.dy + capH)
          ..lineTo(top.dx - half * k * 0.45, top.dy + capH * 0.8)
          ..lineTo(top.dx - half * k * 0.1, top.dy + capH * 1.05)
          ..lineTo(top.dx + half * k * 0.35, top.dy + capH * 0.82)
          ..lineTo(top.dx + half * k, top.dy + capH)
          ..close();
        canvas.drawPath(cap, Paint()..color = back ? const Color(0xFFEFF3F8) : Colors.white);
        if (!back) {
          canvas.drawPath(
              body,
              Paint()
                ..color = _ink.withValues(alpha: 0.6)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.6
                ..strokeJoin = StrokeJoin.round);
        }
      }
    }
    // Foothills blend into the grass.
    final hills = Rect.fromLTWH(0, 220, WorldLayout.size.width, 70);
    canvas.drawRect(
        hills,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.grassDark.withValues(alpha: 0), s.grassDark.withValues(alpha: 0.5), s.grass.withValues(alpha: 0)],
          ).createShader(hills));
  }

  void _nest(Canvas canvas) {
    const c = Offset(720, 1390);
    canvas.drawOval(Rect.fromCenter(center: c, width: 120, height: 54), Paint()..color = const Color(0xFF6E5A44));
    canvas.drawOval(Rect.fromCenter(center: c, width: 92, height: 38), Paint()..color = const Color(0xFFB08A55));
    final rnd = math.Random(5);
    for (var i = 0; i < 14; i++) {
      final a = i / 14 * math.pi * 2;
      final p = c + Offset(math.cos(a) * 58, math.sin(a) * 25);
      final r = 7 + rnd.nextDouble() * 5;
      canvas.drawOval(Rect.fromCenter(center: p, width: r * 2.2, height: r * 1.5), Paint()..color = _ink);
      canvas.drawOval(Rect.fromCenter(center: p, width: r * 2, height: r * 1.3), Paint()..color = const Color(0xFF9A93A0));
    }
    for (final (i, e) in [const Offset(-16, -4), const Offset(4, -8), const Offset(18, 0)].indexed) {
      final r = Rect.fromCenter(center: c + e, width: 18, height: 24);
      canvas.drawOval(r.inflate(1.5), Paint()..color = _ink);
      canvas.drawOval(
          r,
          Paint()
            ..shader = LinearGradient(colors: [
              [const Color(0xFFFFE08A), const Color(0xFF8FD3F0), const Color(0xFFB26BFF)][i],
              [const Color(0xFFB4301F), const Color(0xFF3F88B8), const Color(0xFF3A2C55)][i],
            ]).createShader(r));
    }
  }

  @override
  bool shouldRepaint(GroundPainter old) => old.season.id != season.id;
}

// ---------------------------------------------------------------------------
// Living layer: trees, bushes and rocks that sway, plus fountain spray and
// drifting cloud shadows.
// ---------------------------------------------------------------------------

class LivingPainter extends CustomPainter {
  LivingPainter({required this.time, required this.season}) : super(repaint: time);

  final ValueNotifier<double> time;
  final SeasonPack season;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    for (final d in WorldLayout.decor) {
      switch (d.kind) {
        case DecorKind.tree:
          _tree(canvas, d, t);
        case DecorKind.bush:
          _bush(canvas, d);
        case DecorKind.rock:
          _rock(canvas, d);
      }
    }
    _fountain(canvas, t);
    _cloudShadows(canvas, t);
  }

  void _shadow(Canvas canvas, Offset p, double w, double h) => canvas.drawOval(
      Rect.fromCenter(center: p + Offset(w * 0.18, 0), width: w, height: h),
      Paint()..color = Colors.black.withValues(alpha: 0.18));

  void _tree(Canvas canvas, Decor d, double t) {
    final s = season;
    final r = d.radius;
    final p = d.pos;
    final f = s.foliage;
    _shadow(canvas, p, r * 2.4, r * 0.7);
    final sway = 0.035 * math.sin(t * 1.3 + d.seed % 100) + 0.015 * math.sin(t * 3.1 + d.seed % 37);

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(sway);

    if (s.tree == TreeKind.frosted) {
      // Pine: trunk + three tiers + snow.
      final trunk = Rect.fromLTWH(-r * 0.14, -r * 0.7, r * 0.28, r * 0.75);
      canvas.drawRect(trunk.inflate(1.2), Paint()..color = _ink);
      canvas.drawRect(trunk, Paint()..color = const Color(0xFF5E3B1D));
      for (var i = 0; i < 3; i++) {
        final w = r * (1.25 - i * 0.3);
        final by = -r * (0.55 + i * 0.75);
        final top = by - r * 1.15;
        final tier = Path()
          ..moveTo(-w, by)
          ..quadraticBezierTo(0, by + r * 0.22, w, by)
          ..lineTo(0, top)
          ..close();
        canvas.drawPath(tier, Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round);
        canvas.drawPath(tier, Paint()
          ..shader = LinearGradient(colors: [f[0], f[1], f[2]], stops: const [0, 0.45, 1])
              .createShader(Rect.fromLTRB(-w, top, w, by)));
        final snow = Path()
          ..moveTo(-w * 0.55, by - r * 0.45)
          ..quadraticBezierTo(-w * 0.2, by - r * 0.3, 0, by - r * 0.42)
          ..quadraticBezierTo(w * 0.25, by - r * 0.3, w * 0.5, by - r * 0.48)
          ..lineTo(0, top + 1)
          ..close();
        canvas.drawPath(snow, Paint()..color = Colors.white);
        canvas.drawPath(
            Path()
              ..moveTo(-w + 2, by - 1)
              ..quadraticBezierTo(0, by + r * 0.18, w - 2, by - 1),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round);
      }
      canvas.restore();
      return;
    }

    // Broadleaf family: trunk + clustered canopy.
    final trunk = Path()
      ..moveTo(-r * 0.18, 0)
      ..lineTo(-r * 0.1, -r * 1.2)
      ..lineTo(r * 0.1, -r * 1.2)
      ..lineTo(r * 0.2, 0)
      ..close();
    canvas.drawPath(trunk, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(trunk, Paint()..color = const Color(0xFF6E4723));
    canvas.drawLine(Offset(-r * 0.04, -r * 0.2), Offset(-r * 0.02, -r * 1.1),
        Paint()
          ..color = const Color(0xFF9C6A3A)
          ..strokeWidth = 1.2);

    final blobs = <(Offset, double)>[
      (Offset(0, -r * 1.9), r * 1.05),
      (Offset(-r * 0.68, -r * 1.45), r * 0.72),
      (Offset(r * 0.7, -r * 1.5), r * 0.76),
      (Offset(r * 0.08, -r * 2.6), r * 0.72),
      (Offset(-r * 0.45, -r * 2.3), r * 0.6),
    ];
    final canopy = Path();
    for (final (c, rr) in blobs) {
      canopy.addOval(Rect.fromCircle(center: c, radius: rr));
    }
    final box = Rect.fromLTRB(-r * 1.5, -r * 3.4, r * 1.5, -r * 0.7);
    canvas.drawPath(canopy, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2);
    canvas.drawPath(canopy, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [f[0], f[1], f[2]],
        stops: const [0.05, 0.5, 1],
      ).createShader(box));
    // Highlights on the lit side and depth on the shaded side.
    canvas.drawCircle(Offset(-r * 0.35, -r * 2.35), r * 0.38, Paint()..color = f[0].withValues(alpha: 0.75));
    canvas.drawCircle(Offset(-r * 0.75, -r * 1.6), r * 0.26, Paint()..color = f[0].withValues(alpha: 0.6));
    canvas.drawCircle(Offset(r * 0.55, -r * 1.35), r * 0.42, Paint()..color = f[2].withValues(alpha: 0.35));

    final rnd = math.Random(d.seed);
    if (s.tree == TreeKind.blossom) {
      for (var i = 0; i < 9; i++) {
        final q = Offset((rnd.nextDouble() - 0.5) * r * 2, -r * (1.3 + rnd.nextDouble() * 1.6));
        canvas.drawCircle(q, r * 0.09, Paint()..color = Colors.white);
        canvas.drawCircle(q, r * 0.04, Paint()..color = const Color(0xFFFFE08A));
      }
    } else if (s.tree == TreeKind.autumn) {
      for (var i = 0; i < 6; i++) {
        final q = Offset((rnd.nextDouble() - 0.5) * r * 2, -r * (1.3 + rnd.nextDouble() * 1.6));
        canvas.drawCircle(q, r * 0.14, Paint()..color = (i.isEven ? const Color(0xFFFFD86A) : const Color(0xFFB8442A)).withValues(alpha: 0.8));
      }
    } else {
      for (var i = 0; i < 5; i++) {
        final q = Offset((rnd.nextDouble() - 0.5) * r * 1.8, -r * (1.4 + rnd.nextDouble() * 1.4));
        canvas.drawArc(Rect.fromCircle(center: q, radius: r * 0.22), math.pi * 1.1, math.pi * 0.7, false,
            Paint()
              ..color = f[2].withValues(alpha: 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
      }
    }
    canvas.restore();
  }

  void _bush(Canvas canvas, Decor d) {
    final s = season;
    final r = d.radius;
    final p = d.pos;
    _shadow(canvas, p, r * 2.4, r * 0.6);
    final winter = s.particle == Particle.snow;
    final cols = winter ? [Colors.white, const Color(0xFFD5E3EF), const Color(0xFF9FB4C8)] : s.foliage;
    final leaves = s.tree == TreeKind.blossom || s.tree == TreeKind.autumn
        ? [_mix(s.grassTuft, cols[0], 0.3), s.grassDark, _mix(s.grassDark, _ink, 0.4)]
        : cols;
    final path = Path()
      ..addOval(Rect.fromCircle(center: p + Offset(-r * 0.6, -r * 0.55), radius: r * 0.7))
      ..addOval(Rect.fromCircle(center: p + Offset(r * 0.55, -r * 0.6), radius: r * 0.75))
      ..addOval(Rect.fromCircle(center: p + Offset(0, -r * 0.95), radius: r * 0.85));
    canvas.drawPath(path, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4);
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [leaves[0], leaves[1], leaves[2]],
      ).createShader(Rect.fromCircle(center: p + Offset(0, -r * 0.8), radius: r * 1.4)));
    if (s.tree == TreeKind.blossom || s.tree == TreeKind.autumn) {
      final rnd = math.Random(d.seed);
      for (var i = 0; i < 4; i++) {
        canvas.drawCircle(
            p + Offset((rnd.nextDouble() - 0.5) * r * 1.6, -r * (0.4 + rnd.nextDouble())),
            r * 0.13,
            Paint()..color = s.flowers[i % s.flowers.length]);
      }
    }
  }

  void _rock(Canvas canvas, Decor d) {
    final r = d.radius;
    final p = d.pos;
    _shadow(canvas, p, r * 2.4, r * 0.6);
    final rock = Path()
      ..moveTo(p.dx - r, p.dy)
      ..lineTo(p.dx - r * 0.8, p.dy - r * 0.8)
      ..lineTo(p.dx - r * 0.1, p.dy - r * 1.2)
      ..lineTo(p.dx + r * 0.75, p.dy - r * 0.85)
      ..lineTo(p.dx + r, p.dy)
      ..close();
    canvas.drawPath(rock, Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(rock, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFC9C6C0), Color(0xFF77736E)])
          .createShader(Rect.fromCircle(center: p, radius: r * 1.2)));
    if (season.particle == Particle.snow) {
      canvas.drawPath(
          Path()
            ..moveTo(p.dx - r * 0.8, p.dy - r * 0.78)
            ..lineTo(p.dx - r * 0.1, p.dy - r * 1.2)
            ..lineTo(p.dx + r * 0.75, p.dy - r * 0.85)
            ..quadraticBezierTo(p.dx, p.dy - r * 0.6, p.dx - r * 0.8, p.dy - r * 0.78),
          Paint()..color = Colors.white);
    }
  }

  void _fountain(Canvas canvas, double t) {
    if (season.particle == Particle.snow) return; // frozen in winter
    const c = Offset(550, 741);
    final drop = Paint()..color = season.waterLight.withValues(alpha: 0.9);
    for (var i = 0; i < 10; i++) {
      final ph = (t * 0.9 + i / 10) % 1.0;
      final a = i / 10 * math.pi * 2;
      final x = math.cos(a) * 20 * ph;
      final y = -12 * math.sin(math.pi * ph) + 10 * ph;
      canvas.drawCircle(c + Offset(x, y * 0.9 + math.sin(a) * 6 * ph), 1.6 * (1 - ph * 0.5), drop);
    }
  }

  void _cloudShadows(Canvas canvas, double t) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    for (var i = 0; i < 4; i++) {
      final x = ((t * 9 + i * 420) % 1700) - 300;
      final y = 380.0 + i * 280;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 300, height: 120), paint);
    }
  }

  @override
  bool shouldRepaint(LivingPainter old) => old.season.id != season.id;
}

// ---------------------------------------------------------------------------
// Fog over locked regions.
// ---------------------------------------------------------------------------

class FogPainter extends CustomPainter {
  FogPainter({required this.time, required this.locked, required this.tint})
      : super(repaint: time);

  final ValueNotifier<double> time;
  final List<WorldRegion> locked;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final base = Color.lerp(tint, const Color(0xFFE9EEF5), 0.6)!;
    for (final r in locked) {
      canvas.drawRect(
          r.bounds.inflate(10),
          Paint()
            ..color = base.withValues(alpha: 0.9)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));
      final rnd = math.Random(r.id.length * 31);
      final puff = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      final n = (r.bounds.width * r.bounds.height / 9000).clamp(6, 40).toInt();
      for (var i = 0; i < n; i++) {
        final cx = r.bounds.left + rnd.nextDouble() * r.bounds.width;
        final cy = r.bounds.top + rnd.nextDouble() * r.bounds.height;
        final dx = 14 * math.sin(t * 0.25 + i);
        final rad = 40 + rnd.nextDouble() * 50;
        puff.color = Colors.white.withValues(alpha: 0.35 + 0.2 * rnd.nextDouble());
        canvas.drawCircle(Offset(cx + dx, cy), rad, puff);
      }
    }
  }

  @override
  bool shouldRepaint(FogPainter old) =>
      old.locked.length != locked.length || old.tint != tint;
}

// ---------------------------------------------------------------------------
// Weather particles in screen space.
// ---------------------------------------------------------------------------

class WeatherPainter extends CustomPainter {
  WeatherPainter({required this.time, required this.season}) : super(repaint: time);

  final ValueNotifier<double> time;
  final SeasonPack season;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final s = season;
    final rnd = math.Random(42);
    for (var i = 0; i < s.particleCount; i++) {
      final sx = rnd.nextDouble();
      final sy = rnd.nextDouble();
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      final col = s.particleColors[i % s.particleColors.length];
      final phase = rnd.nextDouble() * 10;
      switch (s.particle) {
        case Particle.snow:
          final y = (sy * size.height + t * 38 * speed) % (size.height + 20) - 10;
          final x = (sx * size.width + 14 * math.sin(t * 0.8 + phase)) % size.width;
          final r = 1.4 + speed * 1.6;
          canvas.drawCircle(Offset(x, y), r, Paint()..color = col.withValues(alpha: 0.9));
        case Particle.petals:
        case Particle.leaves:
          final y = (sy * size.height + t * 26 * speed) % (size.height + 30) - 15;
          final x = (sx * size.width + t * 18 * speed + 26 * math.sin(t * 0.9 + phase)) % (size.width + 30) - 15;
          final a = t * (1.5 + speed) + phase;
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(a);
          canvas.scale(1, 0.4 + 0.6 * math.cos(a * 0.7).abs());
          if (s.particle == Particle.petals) {
            canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 7, height: 4.4), Paint()..color = col);
          } else {
            final leaf = Path()
              ..moveTo(-5, 0)
              ..quadraticBezierTo(0, -4, 5, 0)
              ..quadraticBezierTo(0, 4, -5, 0);
            canvas.drawPath(leaf, Paint()..color = col);
            canvas.drawLine(const Offset(-5, 0), const Offset(5, 0),
                Paint()
                  ..color = Colors.black.withValues(alpha: 0.25)
                  ..strokeWidth = 0.6);
          }
          canvas.restore();
        case Particle.pollen:
          final y = size.height - ((sy * size.height + t * 9 * speed) % (size.height + 10));
          final x = (sx * size.width + 16 * math.sin(t * 0.5 + phase)) % size.width;
          final glow = 0.5 + 0.5 * math.sin(t * 2 + phase);
          canvas.drawCircle(Offset(x, y), 3.5, Paint()
            ..color = col.withValues(alpha: 0.25 * glow)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          canvas.drawCircle(Offset(x, y), 1.2, Paint()..color = col.withValues(alpha: 0.8 * glow + 0.2));
      }
    }
  }

  @override
  bool shouldRepaint(WeatherPainter old) => old.season.id != season.id;
}
