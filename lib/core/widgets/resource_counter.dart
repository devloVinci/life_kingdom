import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum ResourceType { gold, gem, xp }

/// Pill showing a resource icon and amount (gold / gems / XP).
class ResourceCounter extends StatelessWidget {
  const ResourceCounter({super.key, required this.type, required this.amount});

  final ResourceType type;
  final int amount;

  @override
  Widget build(BuildContext context) {
    final (color, dark, icon) = switch (type) {
      ResourceType.gold => (AppColors.gold, AppColors.goldDark, Icons.circle),
      ResourceType.gem => (AppColors.gem, AppColors.gemDark, Icons.diamond),
      ResourceType.xp => (AppColors.xp, const Color(0xFF2F7FD6), Icons.star),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
      decoration: BoxDecoration(
        color: AppColors.panelDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: dark, width: 3),
          ),
          child: Icon(icon, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Text('$amount', style: AppText.heading(16)),
      ]),
    );
  }
}
