import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// Hand-drawn village buildings, built from flat shapes with the same
/// palette and 2.5px ink outline as the Figma Kingdom Home.
const _ink = AppColors.outline;
const _bw = 2.5;

Positioned _box(double l, double t, double w, double h, Color c,
        {double r = 3, bool border = true, Widget? child}) =>
    Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(r),
          border: border ? Border.all(color: _ink, width: _bw) : null,
        ),
        child: child,
      ),
    );

Positioned _oval(double l, double t, double w, double h, Color c,
        {bool border = true}) =>
    Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: Container(
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: border ? Border.all(color: _ink, width: _bw) : null,
        ),
      ),
    );

Positioned _tri(double l, double t, double w, double h, Color c) => Positioned(
      left: l,
      top: t,
      width: w,
      height: h,
      child: CustomPaint(painter: _TriPainter(c)),
    );

class _TriPainter extends CustomPainter {
  _TriPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width / 2, 1)
      ..lineTo(size.width - 1, size.height - 1)
      ..lineTo(1, size.height - 1)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.drawPath(
        p,
        Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = _bw
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_TriPainter old) => old.color != color;
}

/// A row of battlements (crenellations) starting at [l],[t].
List<Widget> _battlements(double l, double t, double w, Color c) {
  final n = math.max(2, (w / 11).floor());
  final bw = w / (n * 2 - 1);
  return [
    for (var i = 0; i < n; i++) _box(l + i * bw * 2, t, bw, 8, c, r: 1.5),
  ];
}

Positioned _window(double l, double t, {double s = 12}) =>
    _box(l, t, s, s * 1.2, AppColors.panelDeep, r: 4);

Positioned _door(double l, double t, double w, double h) => _box(
    l, t, w, h, AppColors.woodDark,
    r: 6, child: null);

/// A name plate under a building.
class NamePlate extends StatelessWidget {
  const NamePlate(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.panelDeep,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _ink, width: 2),
        ),
        child: Text(text,
            style: AppText.body(12, color: Colors.white, weight: FontWeight.w800),
            maxLines: 1),
      );
}

/// A small round notification badge such as "3", "!" or "$".
class VillageBadge extends StatelessWidget {
  const VillageBadge(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 2))
          ],
        ),
        child: Text(label,
            style: AppText.body(12, color: Colors.white, weight: FontWeight.w800)),
      );
}

/// Static geometry of each building: size of its art box.
class BuildingArt {
  const BuildingArt(this.id, this.size, this.build);
  final String id;
  final Size size;
  final List<Widget> Function() build;
}

final Map<String, BuildingArt> buildingArt = {
  'keep': BuildingArt('keep', const Size(150, 172), _keep),
  'builders_hut': BuildingArt('builders_hut', const Size(104, 88), _hut),
  'army_camp': BuildingArt('army_camp', const Size(110, 90), _camp),
  'laboratory': BuildingArt('laboratory', const Size(92, 134), _lab),
  'treasury': BuildingArt('treasury', const Size(108, 92), _treasury),
  'clan_castle': BuildingArt('clan_castle', const Size(122, 118), _castle),
  'shop': BuildingArt('shop', const Size(108, 90), _shop),
  'magic_items': BuildingArt('magic_items', const Size(88, 116), _magic),
};

List<Widget> _keep() => [
      _oval(8, 150, 134, 18, const Color(0x33000000), border: false),
      _box(8, 96, 134, 70, AppColors.stone),
      ..._battlements(8, 90, 134, AppColors.stone),
      // side towers
      _box(0, 58, 40, 108, AppColors.stone),
      _box(110, 58, 40, 108, AppColors.stone),
      ..._battlements(0, 50, 40, AppColors.stone),
      ..._battlements(110, 50, 40, AppColors.stone),
      _window(14, 78),
      _window(124, 78),
      // central tower
      _box(44, 30, 62, 136, AppColors.stone),
      _tri(36, -2, 78, 44, AppColors.panelPrimary),
      _box(72, -22, 3, 24, AppColors.woodDark, border: false),
      _window(63, 52, s: 14),
      _window(80, 52, s: 14),
      _box(50, 100, 50, 3, AppColors.panelDark, border: false),
      // gate
      _box(61, 112, 28, 54, AppColors.wood, r: 14),
      _box(73, 112, 3, 54, AppColors.woodDark, border: false),
      _oval(66, 134, 5, 5, AppColors.gold, border: false),
      _oval(79, 134, 5, 5, AppColors.gold, border: false),
    ];

List<Widget> _hut() => [
      _oval(4, 74, 96, 12, const Color(0x33000000), border: false),
      _box(10, 36, 84, 46, AppColors.wood),
      for (var i = 0; i < 3; i++)
        _box(26.0 + i * 24, 38, 2, 42, AppColors.woodDark, border: false),
      _tri(0, 4, 104, 40, AppColors.danger),
      _box(76, 6, 12, 22, AppColors.stone), // chimney
      _door(40, 52, 24, 30),
      _window(16, 50, s: 11),
      _window(76, 50, s: 11),
      // tools
      _box(90, 62, 4, 18, AppColors.woodDark, border: false),
      _box(86, 60, 12, 5, AppColors.stone, r: 1.5),
    ];

List<Widget> _camp() => [
      _oval(4, 76, 102, 12, const Color(0x33000000), border: false),
      _tri(4, 6, 102, 76, AppColors.panelLight),
      _tri(32, 26, 46, 56, AppColors.panelDeep),
      _box(53, 4, 3, 16, AppColors.woodDark, border: false),
      _tri(56, 4, 18, 10, AppColors.gold),
      // crossed swords sign
      _box(50, 44, 10, 34, AppColors.woodDark, r: 4),
      // training dummy
      _box(88, 48, 4, 30, AppColors.wood, border: false),
      _oval(83, 40, 14, 14, AppColors.path),
      _box(80, 56, 20, 5, AppColors.wood, r: 2),
    ];

List<Widget> _lab() => [
      _oval(4, 120, 84, 12, const Color(0x33000000), border: false),
      _box(8, 56, 76, 70, AppColors.panel),
      _box(14, 20, 64, 44, AppColors.panelLight, r: 8),
      _tri(8, -14, 76, 40, AppColors.gem),
      _oval(34, 6, 24, 24, AppColors.panelDeep),
      _oval(40, 12, 12, 12, const Color(0xFF7DE0FF), border: false),
      _window(18, 74, s: 13),
      _window(60, 74, s: 13),
      _door(34, 90, 24, 36),
      // flask
      _box(70, 100, 14, 24, AppColors.gem, r: 6),
      _box(74, 92, 6, 12, const Color(0xFFE9D8FF), r: 2),
    ];

List<Widget> _treasury() => [
      _oval(4, 78, 100, 12, const Color(0x33000000), border: false),
      _box(8, 34, 92, 52, AppColors.stone),
      _tri(0, 4, 108, 38, AppColors.goldDark),
      for (var i = 0; i < 4; i++)
        _box(16.0 + i * 22, 38, 8, 46, AppColors.panelDark, r: 2),
      _box(38, 56, 32, 30, AppColors.woodDark, r: 4),
      _oval(48, 60, 12, 12, AppColors.gold),
      _oval(74, 70, 14, 14, AppColors.gold),
      _oval(80, 76, 14, 14, AppColors.goldDark),
    ];

List<Widget> _castle() => [
      _oval(6, 104, 110, 12, const Color(0x33000000), border: false),
      _box(14, 56, 94, 54, AppColors.stone),
      ..._battlements(14, 50, 94, AppColors.stone),
      _box(0, 30, 34, 80, AppColors.stone),
      _box(88, 30, 34, 80, AppColors.stone),
      _tri(-4, 2, 42, 34, AppColors.panelPrimary),
      _tri(84, 2, 42, 34, AppColors.panelPrimary),
      _box(60, 14, 3, 22, AppColors.woodDark, border: false),
      _tri(63, 14, 18, 10, AppColors.gem),
      _window(11, 52, s: 11),
      _window(100, 52, s: 11),
      _box(44, 70, 34, 40, AppColors.wood, r: 17),
      _box(60, 70, 2, 40, AppColors.woodDark, border: false),
    ];

List<Widget> _shop() => [
      _oval(4, 76, 100, 12, const Color(0x33000000), border: false),
      _box(10, 34, 88, 48, AppColors.panel),
      // striped awning
      for (var i = 0; i < 6; i++)
        _box(4.0 + i * 16, 14, 16, 26, i.isEven ? AppColors.danger : Colors.white,
            r: 3),
      _box(22, 50, 30, 20, AppColors.wood, r: 3), // counter
      _oval(28, 42, 10, 10, AppColors.gem),
      _oval(40, 42, 10, 10, AppColors.gold),
      _door(66, 46, 22, 36),
    ];

List<Widget> _magic() => [
      _oval(4, 104, 80, 10, const Color(0x33000000), border: false),
      _box(14, 58, 60, 50, AppColors.panelPrimary),
      _tri(4, 14, 80, 50, AppColors.gem),
      _oval(34, 32, 20, 20, AppColors.panelDeep),
      _oval(39, 37, 10, 10, const Color(0xFFFFE27A), border: false),
      _door(34, 76, 20, 32),
      _window(20, 70, s: 9),
      _window(60, 70, s: 9),
    ];

/// Small plain tree used all over the village (drawn once, sized by caller).
class VillageTree extends StatelessWidget {
  const VillageTree({super.key, required this.size});
  final Size size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(painter: _TreePainter()),
      );
}

class _TreePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final trunk = Rect.fromLTWH(s.width * .42, s.height * .62, s.width * .16, s.height * .36);
    final fill = Paint()..color = AppColors.woodDark;
    canvas.drawRect(trunk, fill);
    final dark = Paint()..color = const Color(0xFF2F7A25);
    final light = Paint()..color = const Color(0xFF4DAA3A);
    final line = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final c1 = Offset(s.width * .5, s.height * .36);
    final r = s.width * .46;
    canvas.drawCircle(c1, r, dark);
    canvas.drawCircle(c1, r, line);
    canvas.drawCircle(c1.translate(-r * .22, -r * .22), r * .6, light);
  }

  @override
  bool shouldRepaint(_) => false;
}
