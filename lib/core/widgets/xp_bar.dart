import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Animated progress bar toward the next level. max <= 0 means max level.
class XpBar extends StatelessWidget {
  const XpBar({super.key, required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final isMax = max <= 0;
    final f = isMax ? 1.0 : (current / max).clamp(0.0, 1.0);
    final r = p.chunky ? 12.0 : 8.0;
    return Container(
      height: p.chunky ? 24 : 18,
      decoration: BoxDecoration(
        color: p.chunky ? p.deep : Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
            color: p.chunky ? AppColors.outline : Colors.white.withValues(alpha: 0.12),
            width: p.chunky ? 3 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r - (p.chunky ? 3 : 1)),
        child: Stack(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: f),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: p.chunky
                        ? [AppColors.xp, AppColors.xp]
                        : const [Color(0xFF3E7BE8), Color(0xFF6FD3FF)],
                  ),
                  boxShadow: p.chunky
                      ? null
                      : const [BoxShadow(color: Color(0x886FD3FF), blurRadius: 8)],
                ),
                // Gloss on the upper half.
                child: Align(
                  alignment: Alignment.topCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.45,
                    widthFactor: 1,
                    child: ColoredBox(
                        color: Colors.white.withValues(alpha: p.chunky ? 0 : 0.18)),
                  ),
                ),
              ),
            ),
          ),
          Center(
              child: Text(isMax ? 'MAX' : '$current / $max XP',
                  style: p.chunky
                      ? AppText.heading(12, color: Colors.white)
                      : AppText.body(10.5, color: Colors.white, weight: FontWeight.w800))),
        ]),
      ),
    );
  }
}
