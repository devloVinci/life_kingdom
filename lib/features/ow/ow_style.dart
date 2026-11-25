import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_text.dart';

/// Look of the open-world app: dark stone panels, gold accents, Arabic type.
class Ow {
  Ow._();

  static const bg = Color(0xFF14171F);
  static const panel = Color(0xFF232836);
  static const panelHi = Color(0xFF2E3446);
  static const edge = Color(0xFF3B4258);
  static const gold = Color(0xFFF5C542);
  static const goldDeep = Color(0xFFB8862B);
  static const gem = Color(0xFFB57BFF);
  static const supply = Color(0xFF7FD17A);
  static const xp = Color(0xFF5AB4F5);
  static const danger = Color(0xFFE5654F);
  static const text = Color(0xFFF2EEE3);
  static const muted = Color(0xFFA2A8B8);

  static TextStyle title(double size, {Color color = text}) =>
      AppText.useGoogleFonts
          ? GoogleFonts.reemKufi(
              fontSize: size, color: color, fontWeight: FontWeight.w700)
          : TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w700);

  static TextStyle body(double size,
          {Color color = text, FontWeight weight = FontWeight.w600}) =>
      AppText.useGoogleFonts
          ? GoogleFonts.cairo(fontSize: size, color: color, fontWeight: weight)
          : TextStyle(fontSize: size, color: color, fontWeight: weight);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: gold,
        secondary: supply,
        surface: panel,
      ),
    );
    return base.copyWith(
      textTheme: AppText.useGoogleFonts
          ? GoogleFonts.cairoTextTheme(base.textTheme)
          : base.textTheme,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: panelHi,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class OwPanel extends StatelessWidget {
  const OwPanel({super.key, required this.child, this.padding, this.accent});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Ow.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent ?? Ow.edge, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: child,
      );
}

class OwButton extends StatelessWidget {
  const OwButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.color = Ow.gold,
      this.icon});

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, Color.lerp(color, Colors.black, 0.3)!],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black54, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Ow.bg),
                const SizedBox(width: 6),
              ],
              Text(label, style: Ow.body(15, color: Ow.bg, weight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class ResourceChip extends StatelessWidget {
  const ResourceChip(
      {super.key,
      required this.icon,
      required this.value,
      required this.color,
      this.tooltip});

  final IconData icon;
  final String value;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: Ow.body(13, weight: FontWeight.w800)),
      ]),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

void owToast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: Ow.body(14)),
      duration: const Duration(seconds: 2),
    ));
}

/// Arabic-Indic digits are not used; Western digits read fine in the UI.
String fmt(int n) => n >= 10000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
