import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/quest_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/reward_feedback.dart';
import 'quests_screen.dart' show QuestBar;

class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({super.key, required this.questKey});

  final String questKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final matches =
        QuestEngine.all(s, now).where((v) => v.key == questKey).toList();
    final v = matches.isEmpty ? null : matches.first;

    Widget body;
    if (v == null) {
      body = Center(
        child: Text('This quest is no longer active.',
            style: AppText.heading(20), textAlign: TextAlign.center),
      );
    } else {
      final t = v.template;
      final reset = switch (t.type) {
        QuestType.daily => 'Renews every day',
        QuestType.weekly => 'Renews every Monday',
        QuestType.special => 'One-time challenge',
      };
      final rewards = <(IconData, Color, String)>[
        if (t.xp > 0) (Icons.bolt, AppColors.xp, '+${t.xp} XP'),
        if (t.gold > 0) (Icons.monetization_on, AppColors.gold, '+${t.gold} gold'),
        if (t.gems > 0) (Icons.diamond, AppColors.gem, '+${t.gems} gems'),
        if (t.chest != null) (Icons.inventory_2, AppColors.danger, '${t.chest} chest'),
      ];
      body = ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GamePanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.title, style: AppText.headingPlain(24)),
              const SizedBox(height: 4),
              Text(t.description, style: AppText.body(14)),
              const SizedBox(height: 4),
              Text(reset,
                  style: AppText.body(12, color: AppColors.panelPrimary)),
            ]),
          ),
          const SizedBox(height: 12),
          GamePanel(
            child: Column(children: [
              Text('${v.progress} / ${v.target}',
                  key: const Key('quest_progress'),
                  style: AppText.headingPlain(28, color: AppColors.panelPrimary)),
              const SizedBox(height: 8),
              QuestBar(fraction: v.fraction),
            ]),
          ),
          const SizedBox(height: 12),
          GamePanel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Rewards', style: AppText.headingPlain(18)),
              const SizedBox(height: 6),
              for (final r in rewards)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(r.$1, color: r.$2),
                    const SizedBox(width: 8),
                    Text(r.$3, style: AppText.body(15, weight: FontWeight.w900)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Center(
            child: v.claimed
                ? const GameButton(label: 'Claimed', onPressed: null)
                : GameButton(
                    key: const Key('claim_button'),
                    label: v.claimable ? 'Claim' : 'Keep going',
                    style: GameButtonStyle.gold,
                    onPressed: v.claimable
                        ? () {
                            final o = ref
                                .read(gameProvider.notifier)
                                .claimQuest(v.key);
                            if (o.ok) showEvents(context, o.events);
                          }
                        : null,
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      body: GameBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
                onPressed: () => context.pop(),
              ),
              Expanded(child: Text('Quest', style: AppText.heading(26))),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}
