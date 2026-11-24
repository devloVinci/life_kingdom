import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/rank_badge.dart';
import '../../core/widgets/rarity_frame.dart';
import '../../core/widgets/resource_counter.dart';
import '../../core/widgets/xp_bar.dart';

/// Placeholder home screen using the shared widgets (static demo data).
class KingdomHomeScreen extends StatelessWidget {
  const KingdomHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.skyTop, AppColors.skyBottom, AppColors.grass],
            stops: [0, 0.55, 0.55],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Wrap(spacing: 8, runSpacing: 8, children: [
                ResourceCounter(type: ResourceType.gold, amount: 1250),
                ResourceCounter(type: ResourceType.gem, amount: 48),
                ResourceCounter(type: ResourceType.xp, amount: 320),
              ]),
              const SizedBox(height: 16),
              GamePanel(
                child: Column(children: [
                  Row(children: [
                    const RankBadge(rank: 'E'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Level 3 - Squire',
                          style: AppText.heading(22, color: AppColors.textDark)
                              .copyWith(shadows: const [])),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  const XpBar(current: 320, max: 500),
                ]),
              ),
              const SizedBox(height: 16),
              const SizedBox(
                height: 110,
                child: RarityFrame(
                  rarity: Rarity.epic,
                  child: Center(child: Text('Character art here')),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GameButton(
                  label: 'Complete Habit',
                  icon: Icons.check,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
