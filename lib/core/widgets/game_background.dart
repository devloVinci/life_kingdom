import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../game/catalog.dart';
import '../theme/app_colors.dart';

/// Sky gradient background with safe area. The sky colors come from the
/// equipped background item. [grass] adds the green ground.
class GameBackground extends ConsumerWidget {
  const GameBackground({super.key, required this.child, this.grass = false});

  final Widget child;
  final bool grass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equipped =
        ref.watch(gameProvider.select((s) => s.equipped['background']));
    final g = equipped == null ? null : Catalog.byId[equipped]?.gradient;
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
}
