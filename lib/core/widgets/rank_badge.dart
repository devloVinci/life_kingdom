import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Shield badge for ranks E, D, C, B, A, S, National Level.
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _color,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: AppColors.outline, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 4))],
      ),
      child: Text(rank, style: AppText.heading(size * 0.5)),
    );
  }
}
