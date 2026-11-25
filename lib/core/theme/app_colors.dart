import 'package:flutter/material.dart';

import 'ui_palette.dart';

/// Life Kingdom colours.
///
/// Interface colours (panels, text, outlines, buttons) follow the active
/// [UiPalette] and change with the UI theme. World, currency and rarity
/// colours are fixed.
class AppColors {
  AppColors._();

  /// Active interface palette. Set by the app root before building.
  static UiPalette palette = UiPalette.obsidian;
  static UiPalette get _p => palette;

  // ---- World (fixed) ----
  static const grass = Color(0xFFA8E05F);
  static const grassDark = Color(0xFF3F8F2A);
  static const wood = Color(0xFF9A6A3A);
  static const woodDark = Color(0xFF6B4423);
  static const path = Color(0xFFC9975F);
  static const stone = Color(0xFFCFC8B8);

  // ---- Interface (theme dependent) ----
  static Color get skyTop => _p.backgroundTop;
  static Color get skyBottom => _p.background;
  static Color get panel => _p.surface;
  static Color get panelDark => _p.surfaceEdge;
  static Color get panelRaised => _p.surfaceRaised;

  /// Emphasis text/icons on panels.
  static Color get panelPrimary =>
      _p.chunky ? _p.primaryEdge : (_p.isDark ? _p.accent : _p.primary);
  static Color get panelLight => _p.primary;
  static Color get panelDeep => _p.deep;
  static Color get outline => _p.border;
  static Color get textDark => _p.text;
  static Color get textMuted => _p.textMuted;

  /// Text and icons drawn straight on the screen background.
  static Color get onBackground =>
      _p.chunky || _p.isDark ? Colors.white : _p.text;
  static Color get textLight => onBackground;
  static Color get accent => _p.accent;
  static Color get buttonGreen => _p.positive;
  static Color get buttonBlue => _p.primary;
  static Color get buttonDisabled => _p.disabled;
  static Color get success => _p.positive;
  static Color get successDark => _p.positiveEdge;

  // ---- Currency / state (fixed) ----
  static const gold = Color(0xFFFFC82E);
  static const goldDark = Color(0xFFE59A13);
  static const gem = Color(0xFFA855F7);
  static const gemDark = Color(0xFF7E34C7);
  static const xp = Color(0xFF5AA9F0);
  static const buttonGold = Color(0xFFFFC82E);
  static const danger = Color(0xFFE94B3C);
  static const dangerDark = Color(0xFFA82F23);

  // ---- Rarity (fixed) ----
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
