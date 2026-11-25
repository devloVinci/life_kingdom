import 'package:flutter/material.dart';

import '../theme/app_text.dart';
import '../theme/ui_palette.dart';
import '../world/season.dart';

/// Miniature landscape of a world season.
class SeasonSwatch extends StatelessWidget {
  const SeasonSwatch({super.key, required this.id, this.large = false});

  final String id;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = SeasonPack.byId(id);
    return ClipRRect(
      borderRadius: BorderRadius.circular(large ? 16 : 12),
      child: CustomPaint(painter: _SeasonPainter(s, large), child: const SizedBox.expand()),
    );
  }
}

class _SeasonPainter extends CustomPainter {
  _SeasonPainter(this.s, this.large);
  final SeasonPack s;
  final bool large;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.skyTop, s.skyBottom],
          ).createShader(r));
    // Hills.
    final hill = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.3, h * 0.48, w * 0.6, h * 0.6)
      ..quadraticBezierTo(w * 0.85, h * 0.68, w, h * 0.56)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        hill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [s.grass, s.grassDark],
          ).createShader(r));
    // Trees.
    final f = s.foliage;
    for (final (x, y, k) in [(0.22, 0.62, 1.0), (0.72, 0.64, 0.8), (0.48, 0.7, 0.65)]) {
      final base = Offset(w * x, h * y);
      final rr = h * 0.16 * k;
      canvas.drawRect(Rect.fromCenter(center: base + Offset(0, -rr * 0.4), width: rr * 0.3, height: rr * 0.9),
          Paint()..color = const Color(0xFF5E3B1D));
      if (s.tree == TreeKind.frosted) {
        final tri = Path()
          ..moveTo(base.dx - rr, base.dy - rr * 0.6)
          ..lineTo(base.dx, base.dy - rr * 2.6)
          ..lineTo(base.dx + rr, base.dy - rr * 0.6)
          ..close();
        canvas.drawPath(tri, Paint()..color = f[1]);
        canvas.drawPath(
            Path()
              ..moveTo(base.dx - rr * 0.45, base.dy - rr * 1.7)
              ..lineTo(base.dx, base.dy - rr * 2.6)
              ..lineTo(base.dx + rr * 0.45, base.dy - rr * 1.7)
              ..close(),
            Paint()..color = Colors.white);
      } else {
        final c = base + Offset(0, -rr * 1.5);
        canvas.drawCircle(c, rr, Paint()
          ..shader = LinearGradient(colors: [f[0], f[2]], begin: Alignment.topLeft, end: Alignment.bottomRight)
              .createShader(Rect.fromCircle(center: c, radius: rr)));
      }
    }
    // Particles.
    for (var i = 0; i < (large ? 22 : 9); i++) {
      final p = Offset(w * ((i * 0.37) % 1), h * ((i * 0.61) % 0.6));
      canvas.drawCircle(p, large ? 2.4 : 1.4, Paint()..color = s.particleColors[i % s.particleColors.length]);
    }
    canvas.drawRect(r, Paint()..color = s.light.withValues(alpha: s.lightStrength));
  }

  @override
  bool shouldRepaint(_SeasonPainter old) => old.s.id != s.id;
}

/// Miniature screen showing a UI theme's surfaces and accent.
class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({super.key, required this.id, this.large = false});

  final String id;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = UiPalette.byId(id);
    final k = large ? 1.6 : 1.0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.background],
        ),
        borderRadius: BorderRadius.circular(large ? 16 : 12),
        border: Border.all(color: p.border, width: p.chunky ? 2 : 1),
      ),
      padding: EdgeInsets.all(6 * k),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 6 * k,
          decoration: BoxDecoration(
            color: p.accent,
            borderRadius: BorderRadius.circular(3 * k),
          ),
        ),
        SizedBox(height: 5 * k),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(5 * k),
              border: Border.all(color: p.border, width: p.chunky ? 1.6 : 0.8),
            ),
            padding: EdgeInsets.all(4 * k),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (large)
                Text(p.name, style: AppText.body(13, color: p.text, weight: FontWeight.w900))
              else
                Container(height: 3, width: 24, color: p.text.withValues(alpha: 0.7)),
              SizedBox(height: 3 * k),
              Container(height: 3 * k, width: 18 * k, color: p.textMuted.withValues(alpha: 0.6)),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  height: 8 * k,
                  width: 20 * k,
                  decoration: BoxDecoration(
                    color: p.primary,
                    borderRadius: BorderRadius.circular(3 * k),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
