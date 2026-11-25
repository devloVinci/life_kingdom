import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Badge for ranks E, D, C, B, A, S, National Level.
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, this.size = 56});

  final String rank;
  final double size;

  static const ranks = ['E', 'D', 'C', 'B', 'A', 'S', 'N'];

  Color get _color => switch (rank) {
        'E' => AppColors.common,
        'D' => const Color(0xFF58C93A),
        'C' => AppColors.rare,
        'B' => AppColors.epic,
        'A' => const Color(0xFFFF7A1A),
        'S' => AppColors.legendary,
        _ => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final c = _color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: p.chunky
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(c, Colors.white, 0.3)!, c, Color.lerp(c, Colors.black, 0.35)!],
              ),
        color: p.chunky ? c : null,
        borderRadius: BorderRadius.circular(size * (p.chunky ? 0.3 : 0.26)),
        border: Border.all(
            color: p.chunky ? AppColors.outline : Colors.white.withValues(alpha: 0.35),
            width: p.chunky ? 3 : 1),
        boxShadow: p.chunky
            ? const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4))]
            : [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: size * 0.25)],
      ),
      child: Text(rank,
          style: p.chunky
              ? AppText.heading(size * 0.5, color: Colors.white)
              : AppText.body(size * 0.46, color: Colors.white, weight: FontWeight.w900)
                  .copyWith(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 3)])),
    );
  }
}
