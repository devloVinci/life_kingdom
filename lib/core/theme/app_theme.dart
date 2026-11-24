import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_text.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.panelLight,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: AppColors.skyBottom,
  );
  return base.copyWith(
    textTheme: AppText.useGoogleFonts
        ? GoogleFonts.nunitoTextTheme(base.textTheme)
        : base.textTheme,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.panelDeep,
      indicatorColor: AppColors.panelLight,
      iconTheme: WidgetStateProperty.all(
          const IconThemeData(color: Colors.white)),
      labelTextStyle: WidgetStateProperty.all(
          AppText.body(12, color: Colors.white, weight: FontWeight.w800)),
    ),
  );
}
