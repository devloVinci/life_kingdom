import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/characters/sprite/roaming_dragon.dart';
import '../../core/characters/sprite/sprite_hero.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Living village scene (kingdom revamp experiment).
///
/// Ground heroes from [owned] stand on the field, breathe and attack every
/// few seconds (tap one to attack now). Heroes with flight frames, such as
/// the dragon Hayyab, roam the sky over the village after purchase.
class LivingVillage extends StatelessWidget {
  const LivingVillage({super.key, required this.owned, this.height = 300});

  /// Item ids the player owns (only sprite heroes are shown).
  final Set<String> owned;
  final double height;

  @override
  Widget build(BuildContext context) {
    final heroes = [
      for (final id in owned)
        if (spriteHeroFor(id) != null) spriteHeroFor(id)!,
    ]..sort((a, b) => a.itemId.compareTo(b.itemId));
    final walkers = heroes.where((h) => h.flight == null).toList();
    final fliers = heroes.where((h) => h.flight != null).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.outline, width: 3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth, h = c.maxHeight;
          final heroH = h * 0.36;
          return Stack(clipBehavior: Clip.hardEdge, children: [
            const Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
            // ground heroes, spread along the path, back to front
            for (var i = 0; i < walkers.length; i++)
              _placed(
                walkers[i],
                feet: Offset(
                  w * (walkers.length == 1 ? 0.5 : 0.25 + 0.5 * i / (walkers.length - 1)),
                  h * (0.70 + 0.12 * (i % 2)),
                ),
                height: heroH,
                flip: i.isOdd,
                index: i,
              ),
            for (final f in fliers)
              Positioned.fill(
                child: RoamingDragon(
                  def: f,
                  flightHeight: h * 0.34,
                  groundHeight: h * 0.42,
                ),
              ),
            if (heroes.isEmpty)
              Center(
                child: Text('Recruit heroes in the shop to fill your village',
                    textAlign: TextAlign.center, style: AppText.heading(16)),
              ),
          ]);
        }),
      ),
    );
  }

  Widget _placed(SpriteHeroDef def,
      {required Offset feet, required double height, required bool flip, required int index}) {
    return _AnchoredHero(
      key: ValueKey(def.itemId),
      def: def,
      feet: feet,
      height: height,
      flip: flip,
      autoEvery: Duration(seconds: 7 + 3 * index),
    );
  }
}

/// Positions a [SpriteHero] so its anchor (feet) sits on [feet].
class _AnchoredHero extends StatefulWidget {
  const _AnchoredHero({
    super.key,
    required this.def,
    required this.feet,
    required this.height,
    required this.flip,
    required this.autoEvery,
  });

  final SpriteHeroDef def;
  final Offset feet;
  final double height;
  final bool flip;
  final Duration autoEvery;

  @override
  State<_AnchoredHero> createState() => _AnchoredHeroState();
}

class _AnchoredHeroState extends State<_AnchoredHero> {
  SpriteFrames? _f;

  @override
  Widget build(BuildContext context) {
    final f = _f;
    final w = f == null ? widget.height * 0.8 : widget.height * f.aspect;
    final ax = f?.anchor.dx ?? 0.5, ay = f?.anchor.dy ?? 1.0;
    return Positioned(
      left: widget.feet.dx - w * ax,
      top: widget.feet.dy - widget.height * ay,
      child: SpriteHero(
        def: widget.def,
        height: widget.height,
        flip: widget.flip,
        autoEvery: widget.autoEvery,
        onFrames: (frames) {
          if (mounted) setState(() => _f = frames);
        },
      ),
    );
  }
}

/// Grass field with a winding dirt path and tufts — placeholder ground
/// until the painted building set lands.
class _FieldPainter extends CustomPainter {
  const _FieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Offset.zero & size;
    canvas.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7CC24A), Color(0xFF5FA83A), Color(0xFF4E9632)],
          ).createShader(r));

    // soft light patches
    final rnd = math.Random(7);
    final patch = Paint()..color = const Color(0x22FFFFFF);
    for (var i = 0; i < 9; i++) {
      final c = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      canvas.drawOval(Rect.fromCenter(center: c, width: 90 + rnd.nextDouble() * 80, height: 30 + rnd.nextDouble() * 24), patch);
    }

    // dirt path
    final path = Path()
      ..moveTo(-20, size.height * 0.92)
      ..cubicTo(size.width * 0.3, size.height * 0.62, size.width * 0.55, size.height * 0.98,
          size.width + 20, size.height * 0.70);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF3B2A17)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.15
          ..strokeCap = StrokeCap.round);
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFC89B5E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.height * 0.13
          ..strokeCap = StrokeCap.round);

    // grass tufts
    final tuft = Paint()
      ..color = const Color(0xFF3E7F25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 40; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      for (final d in const [-4.0, 0.0, 4.0]) {
        canvas.drawLine(Offset(x, y), Offset(x + d, y - 7 - d.abs() * 0.5), tuft);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => false;
}
