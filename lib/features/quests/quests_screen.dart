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

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: GameBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Quests', style: AppText.heading(28)),
            ),
          ),
          TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppColors.gold,
            dividerColor: Colors.transparent,
            labelStyle: AppText.body(14, color: Colors.white),
            tabs: const [
              Tab(text: 'Daily'),
              Tab(text: 'Weekly'),
              Tab(text: 'Special'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [
              _QuestList(type: QuestType.daily),
              _QuestList(type: QuestType.weekly),
              _QuestList(type: QuestType.special),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _QuestList extends ConsumerWidget {
  const _QuestList({required this.type});

  final QuestType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final views = QuestEngine.views(s, now, type: type);
    final hint = switch (type) {
      QuestType.daily => 'Renew every day',
      QuestType.weekly => 'Renew every Monday',
      QuestType.special => 'One-time challenges',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(hint, style: AppText.body(13, color: Colors.white)),
        const SizedBox(height: 8),
        for (final v in views)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuestCard(view: v),
          ),
      ],
    );
  }
}

String rewardText(QuestTemplate t) {
  final parts = <String>[
    if (t.xp > 0) '+${t.xp} XP',
    if (t.gold > 0) '+${t.gold} gold',
    if (t.gems > 0) '+${t.gems} gems',
    if (t.chest != null) '${t.chest} chest',
  ];
  return parts.join('   ');
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.view});

  final QuestView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = view.template;
    Widget action;
    if (view.claimed) {
      action = const GameButton(label: 'Claimed', compact: true, onPressed: null);
    } else if (view.claimable) {
      action = GameButton(
        label: 'Claim',
        compact: true,
        style: GameButtonStyle.gold,
        onPressed: () {
          final o = ref.read(gameProvider.notifier).claimQuest(view.key);
          if (o.ok) showEvents(context, o.events);
        },
      );
    } else {
      action = Text('${view.progress} / ${view.target}',
          style: AppText.headingPlain(16, color: AppColors.panelPrimary));
    }
    return GestureDetector(
      key: Key('quest_${t.id}'),
      onTap: () => context.push('/quest/${Uri.encodeComponent(view.key)}'),
      child: GamePanel(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.title, style: AppText.headingPlain(18))),
          action,
        ]),
        const SizedBox(height: 2),
        Text(t.description, style: AppText.body(13)),
        const SizedBox(height: 8),
        QuestBar(fraction: view.fraction),
        const SizedBox(height: 6),
        Text(rewardText(t),
            style: AppText.body(12, color: AppColors.panelPrimary)),
      ]),
    ));
  }
}

/// Progress bar shared by the quest list and the quest detail screen.
class QuestBar extends StatelessWidget {
  const QuestBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.panelDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(color: AppColors.xp),
          ),
        ),
      ),
    );
  }
}
