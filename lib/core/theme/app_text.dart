import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Lilita One for headings/numbers, Nunito for body.
class AppText {
  AppText._();

  /// Figma: Heading/S 20, Counter 18, Button/Label 20, Caption Nunito ExtraBold 12.
  static TextStyle heading(double size, {Color color = AppColors.textLight}) =>
      GoogleFonts.lilitaOne(
        fontSize: size,
        color: color,
        shadows: const [
          Shadow(color: AppColors.outline, offset: Offset(0, 2), blurRadius: 0),
          Shadow(color: AppColors.outline, offset: Offset(1.5, 0), blurRadius: 0),
          Shadow(color: AppColors.outline, offset: Offset(-1.5, 0), blurRadius: 0),
        ],
      );

  static TextStyle body(double size,
          {Color color = AppColors.textDark,
          FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.nunito(fontSize: size, color: color, fontWeight: weight);
}
