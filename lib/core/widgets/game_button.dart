import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum GameButtonStyle { primary, blue, gold, danger }

/// Main action button. Presses down with a little squash and a haptic tick.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = GameButtonStyle.primary,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final GameButtonStyle style;
  final IconData? icon;

  /// Smaller padding and text, for use inside list cards.
  final bool compact;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  (Color, Color, Color) get _colors {
    final p = AppColors.palette;
    return switch (widget.style) {
      GameButtonStyle.primary => (p.positive, p.positiveEdge, Colors.white),
      GameButtonStyle.blue => (p.primary, p.primaryEdge, Colors.white),
      GameButtonStyle.gold => (
          const Color(0xFFF2C14E),
          const Color(0xFFB8862B),
          const Color(0xFF2A1C04)
        ),
      GameButtonStyle.danger => (
          AppColors.danger,
          AppColors.dangerDark,
          Colors.white
        ),
    };
  }

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final enabled = widget.onPressed != null;
    final (face, edge, ink) = enabled
        ? _colors
        : (p.disabled, p.disabled, p.isDark ? p.textMuted : Colors.white);
    final depth = p.chunky ? 5.0 : 3.0;
    final pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 22, vertical: 13);
    final label = p.chunky
        ? AppText.heading(widget.compact ? 14 : 18, color: Colors.white)
        : AppText.body(widget.compact ? 13 : 15, color: ink, weight: FontWeight.w800)
            .copyWith(letterSpacing: 0.3);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: enabled ? (_) => _set(false) : null,
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _down && !p.chunky ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: EdgeInsets.only(top: _down ? depth : 0),
            padding: pad,
            decoration: BoxDecoration(
              color: face,
              gradient: p.chunky || !enabled
                  ? null
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(face, Colors.white, 0.14)!, face],
                    ),
              borderRadius: BorderRadius.circular(p.chunky ? 14 : p.radius - 2),
              border: p.chunky
                  ? Border.all(color: AppColors.outline, width: 3)
                  : Border.all(
                      color: Colors.white.withValues(alpha: enabled ? 0.18 : 0.05)),
              boxShadow: [
                if (!_down) BoxShadow(color: edge, offset: Offset(0, depth)),
                if (!p.chunky && enabled && !_down)
                  BoxShadow(
                      color: face.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: p.chunky ? Colors.white : ink, size: widget.compact ? 18 : 20),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(widget.label, textAlign: TextAlign.center, style: label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
