import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography. The classic theme uses Lilita One + Nunito; the modern themes
/// use Cinzel for titles and Inter for everything else.
class AppText {
  AppText._();

  /// Tests set this to false so no network font fetch is attempted.
  static bool useGoogleFonts = true;

  static bool get _chunky => AppColors.palette.chunky;

  /// Display heading for text on the screen background or on coloured
  /// fills. [color] defaults to the on-background colour.
  static TextStyle heading(double size, {Color? color}) {
    final c = color ?? AppColors.textLight;
    if (_chunky) {
      return _lilita(size, c).copyWith(shadows: [
        Shadow(color: AppColors.outline, offset: const Offset(0, 2)),
        Shadow(color: AppColors.outline, offset: const Offset(1.5, 0)),
        Shadow(color: AppColors.outline, offset: const Offset(-1.5, 0)),
      ]);
    }
    return _modernHeading(size, c).copyWith(shadows: [
      Shadow(
          color: Colors.black.withValues(alpha: 0.35),
          offset: const Offset(0, 1),
          blurRadius: 3),
    ]);
  }

  /// Heading for text on panels (no shadow).
  static TextStyle headingPlain(double size, {Color? color}) {
    final c = color ?? AppColors.textDark;
    return _chunky ? _lilita(size, c) : _modernHeading(size, c);
  }

  static TextStyle body(double size,
      {Color? color, FontWeight weight = FontWeight.w700}) {
    final c = color ?? AppColors.textDark;
    if (_chunky) {
      return useGoogleFonts
          ? GoogleFonts.nunito(fontSize: size, color: c, fontWeight: weight)
          : TextStyle(
              fontFamily: 'Nunito', fontSize: size, color: c, fontWeight: weight);
    }
    // Inter reads heavier than Nunito; step the weight down one notch.
    final w = FontWeight.values[(weight.index - 1).clamp(0, 8)];
    return useGoogleFonts
        ? GoogleFonts.inter(fontSize: size, color: c, fontWeight: w)
        : TextStyle(fontFamily: 'Inter', fontSize: size, color: c, fontWeight: w);
  }

  /// Small uppercase label (section headers, tags).
  static TextStyle label(double size, {Color? color}) =>
      body(size, color: color ?? AppColors.textMuted, weight: FontWeight.w800)
          .copyWith(letterSpacing: 1.1);

  static TextStyle _lilita(double size, Color color) => useGoogleFonts
      ? GoogleFonts.lilitaOne(fontSize: size, color: color)
      : TextStyle(fontFamily: 'LilitaOne', fontSize: size, color: color);

  static TextStyle _modernHeading(double size, Color color) {
    if (size >= 20) {
      return useGoogleFonts
          ? GoogleFonts.cinzel(
              fontSize: size, color: color, fontWeight: FontWeight.w700)
          : TextStyle(
              fontFamily: 'Cinzel',
              fontSize: size,
              color: color,
              fontWeight: FontWeight.w700);
    }
    return useGoogleFonts
        ? GoogleFonts.inter(
            fontSize: size, color: color, fontWeight: FontWeight.w800)
        : TextStyle(
            fontFamily: 'Inter',
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w800);
  }
}
