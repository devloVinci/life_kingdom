import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum ResourceType { gold, gem, xp }

/// Pill showing a resource icon and amount (gold / gems / XP). The number
/// rolls up or down when it changes.
class ResourceCounter extends StatelessWidget {
  const ResourceCounter({super.key, required this.type, required this.amount});

  final ResourceType type;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final (color, dark, icon) = switch (type) {
      ResourceType.gold => (AppColors.gold, AppColors.goldDark, Icons.circle),
      ResourceType.gem => (AppColors.gem, AppColors.gemDark, Icons.diamond),
      ResourceType.xp => (AppColors.xp, const Color(0xFF2F7FD6), Icons.star),
    };
    final coin = Container(
      width: p.chunky ? 28 : 22,
      height: p.chunky ? 28 : 22,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, dark],
          stops: const [0, 0.55, 1],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: p.chunky ? dark : dark.withValues(alpha: 0.8), width: p.chunky ? 3 : 1.2),
        boxShadow: p.chunky ? null : [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8)],
      ),
      child: Icon(icon, size: p.chunky ? 14 : 11, color: Colors.white.withValues(alpha: 0.9)),
    );
    final number = TweenAnimationBuilder<double>(
      tween: Tween(end: amount.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => Text('${v.round()}',
          style: p.chunky
              ? AppText.heading(16, color: Colors.white)
              : AppText.body(14, color: Colors.white, weight: FontWeight.w800)
                  .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
    );
    return Container(
      padding: p.chunky
          ? const EdgeInsets.fromLTRB(4, 4, 14, 4)
          : const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: p.chunky ? p.deep : Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: p.chunky ? AppColors.outline : Colors.white.withValues(alpha: 0.12),
            width: p.chunky ? 3 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        coin,
        const SizedBox(width: 8),
        number,
      ]),
    );
  }
}
