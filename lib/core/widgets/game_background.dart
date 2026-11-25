import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../game/catalog.dart';
import '../theme/app_colors.dart';

/// Screen background with safe area.
///
/// Classic theme: sky gradient from the equipped background item.
/// Modern themes: the palette's background with a soft light from the top;
/// the equipped background item tints that light.
class GameBackground extends ConsumerWidget {
  const GameBackground({super.key, required this.child, this.grass = false});

  final Widget child;
  final bool grass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AppColors.palette;
    final equipped =
        ref.watch(gameProvider.select((s) => s.equipped['background']));
    final g = equipped == null ? null : Catalog.byId[equipped]?.gradient;

    if (p.chunky) {
      final top = g == null ? AppColors.skyTop : Color(g[0]);
      final bottom = g == null ? AppColors.skyBottom : Color(g[1]);
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: grass ? [top, bottom, AppColors.grass] : [top, bottom],
            stops: grass ? const [0, 0.55, 0.55] : null,
          ),
        ),
        child: SafeArea(child: child),
      );
    }

    final glow = g == null ? p.accent : Color(g[0]);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.background],
          stops: const [0, 0.6],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.15),
            radius: 1.1,
            colors: [
              glow.withValues(alpha: p.isDark ? 0.16 : 0.12),
              glow.withValues(alpha: 0),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}
