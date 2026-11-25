import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_text.dart';
import 'ui_palette.dart';

ThemeData buildAppTheme(UiPalette p) {
  final scheme = ColorScheme.fromSeed(
    seedColor: p.primary,
    brightness: p.brightness,
  ).copyWith(
    primary: p.primary,
    secondary: p.accent,
    surface: p.surface,
    onSurface: p.text,
    outline: p.border,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    splashFactory: InkSparkle.splashFactory,
  );
  final text = AppText.useGoogleFonts
      ? (p.chunky
          ? GoogleFonts.nunitoTextTheme(base.textTheme)
          : GoogleFonts.interTextTheme(base.textTheme))
      : base.textTheme;
  return base.copyWith(
    textTheme: text.apply(bodyColor: p.text, displayColor: p.text),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(p.radius + 4),
        side: BorderSide(color: p.border, width: p.stroke),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(p.radius + 8)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.isDark ? p.surfaceRaised : p.deep,
      contentTextStyle: AppText.body(14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(p.radius)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? p.accentSoft : p.surfaceRaised),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(p.radius - 4),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(p.radius - 4),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(p.radius - 4),
        borderSide: BorderSide(color: p.accent, width: 1.5),
      ),
    ),
    listTileTheme: ListTileThemeData(textColor: p.text, iconColor: p.textMuted),
    iconTheme: IconThemeData(color: p.text),
  );
}
