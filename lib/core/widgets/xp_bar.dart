import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Animated progress bar toward the next level.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final f = max <= 0 ? 0.0 : (current / max).clamp(0.0, 1.0);
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.woodDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: f),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(color: AppColors.xp),
            ),
          ),
          Center(child: Text('$current / $max XP', style: AppText.heading(12))),
        ]),
      ),
    );
  }
}
