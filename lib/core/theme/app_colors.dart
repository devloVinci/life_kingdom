import 'package:flutter/material.dart';

/// Life Kingdom palette (Clash-style: bright, flat, bold outlines).
/// Values are first-pass tokens; sync them with the Figma Color variables.
class AppColors {
  AppColors._();

  // Tokens below are read from the Figma file (Color collection).
  // World
  static const grass = Color(0xFFA8E05F); // world/grass-light
  static const grassDark = Color(0xFF3F8F2A); // world/grass-dark
  static const wood = Color(0xFF9A6A3A); // world/wood
  static const woodDark = Color(0xFF6B4423); // world/wood-dark
  static const path = Color(0xFFC9975F); // world/path
  static const stone = Color(0xFFCFC8B8); // world/stone
  // Sky is not a Figma variable; first-pass values.
  static const skyTop = Color(0xFF5BC0F8);
  static const skyBottom = Color(0xFFB8E8FF);

  // Panels
  static const panel = Color(0xFFF1EDE4); // panel/parchment
  static const panelDark = Color(0xFFD8D1C0); // derived edge shade
  static const panelPrimary = Color(0xFF1D4E9E); // panel/primary
  static const panelLight = Color(0xFF2F7FD6); // panel/light
  static const panelDeep = Color(0xFF12306A); // panel/deep

  // Outline / text
  static const outline = Color(0xFF14213D); // outline/ink
  static const textDark = Color(0xFF14213D);
  static const textLight = Color(0xFFFFFFFF); // text/on-dark

  // Currency
  static const gold = Color(0xFFFFC82E); // currency/gold
  static const goldDark = Color(0xFFE59A13); // currency/gold-dark
  static const gem = Color(0xFFA855F7); // currency/gem
  static const gemDark = Color(0xFF7E34C7); // derived
  static const xp = Color(0xFF5AA9F0); // currency/xp

  // Buttons / state
  static const buttonGreen = Color(0xFF6FBF3B);
  static const buttonBlue = Color(0xFF2F7FD6);
  static const buttonGold = Color(0xFFFFC82E);
  static const buttonDisabled = Color(0xFF9C9585);
  static const success = Color(0xFF6FBF3B); // state/success
  static const successDark = Color(0xFF4A8F24); // derived
  static const danger = Color(0xFFE94B3C); // state/alert
  static const dangerDark = Color(0xFFA82F23); // derived

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
