import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum GameButtonStyle { primary, gold, danger }

/// Chunky 3D button that presses down on tap.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = GameButtonStyle.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameButtonStyle style;
  final IconData? icon;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  (Color, Color) get _colors => switch (widget.style) {
        GameButtonStyle.primary => (AppColors.success, AppColors.successDark),
        GameButtonStyle.gold => (AppColors.gold, AppColors.goldDark),
        GameButtonStyle.danger => (AppColors.danger, AppColors.dangerDark),
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (face, edge) = enabled
        ? _colors
        : (AppColors.common, const Color(0xFF6B7580));
    const depth = 5.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        margin: EdgeInsets.only(top: _down ? depth : 0),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: face,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outline, width: 3),
          boxShadow: [
            if (!_down) BoxShadow(color: edge, offset: const Offset(0, depth)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
            ],
            Text(widget.label, style: AppText.heading(18)),
          ],
        ),
      ),
    );
  }
}
