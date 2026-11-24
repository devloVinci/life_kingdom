import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Parchment panel with bold outline and hard drop shadow.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = AppColors.panel,
    this.borderColor = AppColors.outline,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 3),
        boxShadow: const [
          BoxShadow(color: AppColors.panelDark, offset: Offset(0, 4)),
          BoxShadow(
              color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 6),
        ],
      ),
      child: child,
    );
  }
}
