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
    final c = rarity.color;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: selected ? AppColors.gold : c, width: selected ? 5 : 4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.12)],
        ),
        boxShadow: [
          if (rarity == Rarity.legendary || rarity == Rarity.epic)
            BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 12),
        ],
      ),
      child: Stack(children: [
        Padding(padding: const EdgeInsets.all(8), child: child),
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: c,
              borderRadius:
                  const BorderRadius.only(bottomRight: Radius.circular(10)),
            ),
            child: Text(rarity.label, style: AppText.heading(11)),
          ),
        ),
      ]),
    );
  }
}
