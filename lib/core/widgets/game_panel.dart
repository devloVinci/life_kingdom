import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Card surface. Classic theme: parchment with ink outline and hard shadow.
/// Modern themes: soft surface, hairline border, gentle depth.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final fill = color ?? p.surface;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        gradient: p.chunky || color != null
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.surfaceRaised, p.surface],
              ),
        borderRadius: BorderRadius.circular(p.radius),
        border: Border.all(color: borderColor ?? p.border, width: p.stroke),
        boxShadow: p.chunky
            ? [
                BoxShadow(color: p.surfaceEdge, offset: const Offset(0, 4)),
                const BoxShadow(
                    color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 6),
              ]
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: p.isDark ? 0.35 : 0.08),
                    offset: const Offset(0, 6),
                    blurRadius: 18),
              ],
      ),
      // Lets ListTiles and ink effects paint on the panel.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
