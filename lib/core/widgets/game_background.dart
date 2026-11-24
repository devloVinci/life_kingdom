import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Sky gradient background with safe area. [grass] adds the green ground.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child, this.grass = false});

  final Widget child;
  final bool grass;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: grass
              ? const [AppColors.skyTop, AppColors.skyBottom, AppColors.grass]
              : const [AppColors.skyTop, AppColors.skyBottom],
          stops: grass ? const [0, 0.55, 0.55] : null,
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
