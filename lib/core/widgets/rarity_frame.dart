import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Framed card background keyed by rarity (border + tint + label ribbon).
class RarityFrame extends StatelessWidget {
  const RarityFrame({
    super.key,
    required this.rarity,
    required this.child,
    this.selected = false,
  });

  final Rarity rarity;
  final Widget child;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final c = rarity.color;
    final shiny = rarity == Rarity.legendary || rarity == Rarity.epic;
    final decoration = p.chunky
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.gold : c, width: selected ? 5 : 4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.12)],
            ),
            boxShadow: [
              if (shiny) BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12),
            ],
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(p.radius),
            border: Border.all(
                color: selected ? p.accent : c.withValues(alpha: 0.45),
                width: selected ? 1.8 : 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(c.withValues(alpha: p.isDark ? 0.16 : 0.10), p.surfaceRaised),
                p.surface,
              ],
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5)),
              if (shiny) BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: 18),
            ],
          );
    return Container(
      decoration: decoration,
      child: Stack(children: [
        Padding(padding: const EdgeInsets.all(8), child: child),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: p.chunky ? c : c.withValues(alpha: 0.9),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(p.chunky ? 0 : p.radius),
                  bottomRight: const Radius.circular(10)),
            ),
            child: Text(
                p.chunky ? rarity.label : rarity.label.toUpperCase(),
                style: p.chunky
                    ? AppText.heading(11, color: Colors.white)
                    : AppText.body(9.5, color: Colors.white, weight: FontWeight.w900)
                        .copyWith(letterSpacing: 1)),
          ),
        ),
      ]),
    );
  }
}
