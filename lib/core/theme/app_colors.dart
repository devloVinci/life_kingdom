import 'package:flutter/material.dart';

/// Life Kingdom palette (Clash-style: bright, flat, bold outlines).
/// Values are first-pass tokens; sync them with the Figma Color variables.
class AppColors {
  AppColors._();

  // Surfaces
  static const skyTop = Color(0xFF5BC0F8);
  static const skyBottom = Color(0xFFB8E8FF);
  static const grass = Color(0xFF7BC74D);
  static const grassDark = Color(0xFF4E9A2E);
  static const wood = Color(0xFF8B5A2B);
  static const woodDark = Color(0xFF5C3A1A);
  static const panel = Color(0xFFF6E7C1);
  static const panelDark = Color(0xFFD9BE86);

  // Outline / text
  static const outline = Color(0xFF2B1B0E);
  static const textDark = Color(0xFF3A2410);
  static const textLight = Color(0xFFFFFFFF);

  // Resources
  static const gold = Color(0xFFFFC928);
  static const goldDark = Color(0xFFC98A00);
  static const gem = Color(0xFF3FD0FF);
  static const gemDark = Color(0xFF1A8FC0);
  static const xp = Color(0xFFB36CFF);

  // Actions
  static const success = Color(0xFF58C93A);
  static const successDark = Color(0xFF2F8F1A);
  static const danger = Color(0xFFE8473B);
  static const dangerDark = Color(0xFFA42A21);

  // Rarity
  static const common = Color(0xFF9AA5B1);
  static const rare = Color(0xFF3B8EEA);
  static const epic = Color(0xFFA65BF0);
  static const legendary = Color(0xFFFFB300);
}

enum Rarity {
  common('Common', AppColors.common),
  rare('Rare', AppColors.rare),
  epic('Epic', AppColors.epic),
  legendary('Legendary', AppColors.legendary);

  const Rarity(this.label, this.color);
  final String label;
  final Color color;
}
