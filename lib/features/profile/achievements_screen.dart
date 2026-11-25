import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/achievement_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_panel.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    return Scaffold(
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
                onPressed: () => context.pop(),
              ),
              Expanded(child: Text('Achievements', style: AppText.heading(26))),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: Text(
                  '${s.achievements.length} of ${AchievementEngine.total} unlocked',
                  style: AppText.body(14, color: AppColors.onBackground)),
            ),
            for (final a in achievementDefs)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Opacity(
                  opacity: s.achievements.containsKey(a.id) ? 1 : 0.6,
                  child: GamePanel(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Icon(
                        s.achievements.containsKey(a.id)
                            ? Icons.emoji_events
                            : Icons.lock_outline,
                        color: s.achievements.containsKey(a.id)
                            ? AppColors.gold
                            : AppColors.buttonDisabled,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title, style: AppText.headingPlain(18)),
                              Text(a.description, style: AppText.body(13)),
                              Text(
                                  s.achievements.containsKey(a.id)
                                      ? 'Unlocked ${s.achievements[a.id]}'
                                      : 'Reward: ${a.gold} gold${a.gems > 0 ? ' + ${a.gems} gems' : ''}',
                                  style: AppText.body(12,
                                      color: AppColors.panelPrimary)),
                            ]),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
