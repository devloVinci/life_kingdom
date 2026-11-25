import 'package:flutter/material.dart';

/// Visual style of the app's interface (panels, buttons, text, navigation).
///
/// The UI theme is independent of the world season: a dark interface can sit
/// over a spring world and a light one over a winter world.
class UiPalette {
  const UiPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.background,
    required this.backgroundTop,
    required this.surface,
    required this.surfaceEdge,
    required this.surfaceRaised,
    required this.deep,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.onAccent,
    required this.accent,
    required this.accentSoft,
    required this.primary,
    required this.primaryEdge,
    required this.positive,
    required this.positiveEdge,
    required this.disabled,
    required this.navBar,
    required this.chunky,
    required this.radius,
  });

  final String id;
  final String name;
  final Brightness brightness;

  /// Screen background (bottom / top of the gradient).
  final Color background;
  final Color backgroundTop;

  /// Cards and panels.
  final Color surface;
  final Color surfaceEdge;
  final Color surfaceRaised;

  /// Deep fills: bars, chips, counters.
  final Color deep;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color onAccent;

  /// Signature colour (highlights, selected tab, XP glow).
  final Color accent;
  final Color accentSoft;

  /// Main action colour (blue buttons, links).
  final Color primary;
  final Color primaryEdge;
  final Color positive;
  final Color positiveEdge;
  final Color disabled;
  final Color navBar;

  /// True for the original cartoon look: thick ink outlines, hard drop
  /// shadows, Lilita One headings.
  final bool chunky;
  final double radius;

  bool get isDark => brightness == Brightness.dark;

  /// Outline width for panels and buttons.
  double get stroke => chunky ? 3 : 1;

  /// Dark modern default: obsidian surfaces with a warm gold accent.
  static const obsidian = UiPalette(
    id: 'ui_obsidian',
    name: 'Obsidian',
    brightness: Brightness.dark,
    background: Color(0xFF0E1118),
    backgroundTop: Color(0xFF1A2030),
    surface: Color(0xFF181D29),
    surfaceEdge: Color(0xFF0B0E14),
    surfaceRaised: Color(0xFF222938),
    deep: Color(0xFF10141D),
    border: Color(0xFF2C3446),
    text: Color(0xFFEDEFF4),
    textMuted: Color(0xFF8C95A8),
    onAccent: Color(0xFF1A1405),
    accent: Color(0xFFE8B84A),
    accentSoft: Color(0x33E8B84A),
    primary: Color(0xFF4C7BE0),
    primaryEdge: Color(0xFF2B4F9E),
    positive: Color(0xFF3FAE73),
    positiveEdge: Color(0xFF237A4D),
    disabled: Color(0xFF3A4152),
    navBar: Color(0xF2121621),
    chunky: false,
    radius: 14,
  );

  /// Light modern: warm ivory surfaces, ink text, royal blue accent.
  static const ivory = UiPalette(
    id: 'ui_ivory',
    name: 'Ivory',
    brightness: Brightness.light,
    background: Color(0xFFEDE8DE),
    backgroundTop: Color(0xFFF8F5EF),
    surface: Color(0xFFFFFDF9),
    surfaceEdge: Color(0xFFDCD4C5),
    surfaceRaised: Color(0xFFF4EFE6),
    deep: Color(0xFF26304A),
    border: Color(0xFFDAD2C3),
    text: Color(0xFF1C2233),
    textMuted: Color(0xFF6E7487),
    onAccent: Color(0xFFFFFFFF),
    accent: Color(0xFFB8862B),
    accentSoft: Color(0x26B8862B),
    primary: Color(0xFF2F5BC0),
    primaryEdge: Color(0xFF1E3F8A),
    positive: Color(0xFF2E9A63),
    positiveEdge: Color(0xFF1E6E45),
    disabled: Color(0xFFB9B3A6),
    navBar: Color(0xF5FFFDF9),
    chunky: false,
    radius: 14,
  );

  /// Blue fantasy: arcane night blues with silver and cyan.
  static const arcane = UiPalette(
    id: 'ui_arcane',
    name: 'Arcane',
    brightness: Brightness.dark,
    background: Color(0xFF0A1430),
    backgroundTop: Color(0xFF1A2C66),
    surface: Color(0xFF14214A),
    surfaceEdge: Color(0xFF09102A),
    surfaceRaised: Color(0xFF1E2E60),
    deep: Color(0xFF0C1636),
    border: Color(0xFF2E4486),
    text: Color(0xFFEAF1FF),
    textMuted: Color(0xFF93A6D8),
    onAccent: Color(0xFF06142E),
    accent: Color(0xFF6FE3F2),
    accentSoft: Color(0x336FE3F2),
    primary: Color(0xFF5A7CF0),
    primaryEdge: Color(0xFF3550B8),
    positive: Color(0xFF44C08A),
    positiveEdge: Color(0xFF2A8460),
    disabled: Color(0xFF34406A),
    navBar: Color(0xF20C1636),
    chunky: false,
    radius: 16,
  );

  /// The original Clash-style cartoon look.
  static const classic = UiPalette(
    id: 'ui_classic',
    name: 'Kingdom Classic',
    brightness: Brightness.light,
    background: Color(0xFFB8E8FF),
    backgroundTop: Color(0xFF5BC0F8),
    surface: Color(0xFFF1EDE4),
    surfaceEdge: Color(0xFFD8D1C0),
    surfaceRaised: Color(0xFFF7F4EE),
    deep: Color(0xFF12306A),
    border: Color(0xFF14213D),
    text: Color(0xFF14213D),
    textMuted: Color(0xFF4D5878),
    onAccent: Color(0xFF14213D),
    accent: Color(0xFFFFC82E),
    accentSoft: Color(0x40FFC82E),
    primary: Color(0xFF2F7FD6),
    primaryEdge: Color(0xFF1D4E9E),
    positive: Color(0xFF6FBF3B),
    positiveEdge: Color(0xFF4A8F24),
    disabled: Color(0xFF9C9585),
    navBar: Color(0xFF12306A),
    chunky: true,
    radius: 16,
  );

  static const all = [obsidian, ivory, arcane, classic];

  static UiPalette byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => obsidian);
}
