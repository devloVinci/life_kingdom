import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Lilita One for headings/numbers, Nunito for body.
class AppText {
  AppText._();

  /// Tests set this to false so no network font fetch is attempted.
  static bool useGoogleFonts = true;

  /// Figma: Heading/S 20, Counter 18, Button/Label 20, Caption Nunito ExtraBold 12.
  static TextStyle heading(double size, {Color color = AppColors.textLight}) =>
      _headingBase(size, color).copyWith(
        shadows: const [
          Shadow(color: AppColors.outline, offset: Offset(0, 2), blurRadius: 0),
          Shadow(color: AppColors.outline, offset: Offset(1.5, 0), blurRadius: 0),
          Shadow(color: AppColors.outline, offset: Offset(-1.5, 0), blurRadius: 0),
        ],
      );

  /// Heading without the outline shadows (for text on light panels).
  static TextStyle headingPlain(double size,
          {Color color = AppColors.textDark}) =>
      _headingBase(size, color);

  static TextStyle _headingBase(double size, Color color) => useGoogleFonts
      ? GoogleFonts.lilitaOne(fontSize: size, color: color)
      : TextStyle(fontFamily: 'LilitaOne', fontSize: size, color: color);

  static TextStyle body(double size,
          {Color color = AppColors.textDark,
          FontWeight weight = FontWeight.w700}) =>
      useGoogleFonts
          ? GoogleFonts.nunito(fontSize: size, color: color, fontWeight: weight)
          : TextStyle(
              fontFamily: 'Nunito',
              fontSize: size,
              color: color,
              fontWeight: weight);
}
