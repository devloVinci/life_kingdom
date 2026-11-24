import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/achievement_engine.dart';
import '../../core/game/catalog.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/xp_curve.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/rank_badge.dart';
import '../../core/widgets/xp_bar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final level = GameEngine.level(s);
    final rank = GameEngine.rank(s);
    final (cur, need) = XpCurve.progress(s.totalXp);
    final character =
        Catalog.byId[s.equipped['character']] ?? Catalog.byId['char_raider']!;
    final title = Catalog.byId[s.equipped['title']]?.name;

    return GameBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profile', style: AppText.heading(28)),
          const SizedBox(height: 12),
          GamePanel(
            child: Column(children: [
              Row(children: [
                CharacterAvatar(item: character, size: 72),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.playerName, style: AppText.headingPlain(24)),
                        Text(title ?? 'No title equipped',
                            style: AppText.body(13)),
                        Text('Level $level  -  ${s.totalXp} XP',
                            style: AppText.body(13)),
                      ]),
                ),
                RankBadge(rank: rank.name == 'National Level' ? 'N' : rank.name),
              ]),
              const SizedBox(height: 12),
              XpBar(current: cur, max: need),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _Stat(value: '${s.completions.length}', label: 'Habits done')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(value: '${s.streak.longest}', label: 'Best streak')),
            const SizedBox(width: 12),
            Expanded(
                child: _Stat(
                    value: '${s.achievements.length}/${AchievementEngine.total}',
                    label: 'Achievements')),
          ]),
          const SizedBox(height: 16),
          GamePanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ranks', style: AppText.headingPlain(20)),
                  const SizedBox(height: 8),
                  for (final r in GameConfig.ranks)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(children: [
                        Icon(
                          level >= r.fromLevel
                              ? Icons.check_circle
                              : Icons.lock_outline,
                          color: level >= r.fromLevel
                              ? AppColors.success
                              : AppColors.buttonDisabled,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              '${r.name}  -  from level ${r.fromLevel}',
                              style: AppText.body(14,
                                  weight: r.name == rank.name
                                      ? FontWeight.w900
                                      : FontWeight.w600)),
                        ),
                      ]),
                    ),
                ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            GameButton(
              label: 'Achievements',
              icon: Icons.emoji_events,
              style: GameButtonStyle.gold,
              onPressed: () => context.push('/achievements'),
            ),
            GameButton(
              label: 'Calendar & Stats',
              icon: Icons.calendar_month,
              style: GameButtonStyle.blue,
              onPressed: () => context.push('/calendar'),
            ),
            GameButton(
              label: 'Settings',
              icon: Icons.settings,
              style: GameButtonStyle.blue,
              onPressed: () => context.push('/settings'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(children: [
        Text(value, style: AppText.headingPlain(20)),
        Text(label, textAlign: TextAlign.center, style: AppText.body(11)),
      ]),
    );
  }
}
