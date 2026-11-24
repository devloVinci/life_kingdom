import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/game/catalog.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/xp_curve.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/game_button.dart';
import '../../../core/widgets/rank_badge.dart';
import '../../../core/widgets/resource_counter.dart';
import '../../../core/widgets/xp_bar.dart';

/// Heads-up display drawn over the village: hero, level, XP, currencies,
/// streak and today's progress.
class VillageHud extends ConsumerWidget {
  const VillageHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final level = GameEngine.level(s);
    final rank = GameEngine.rank(s);
    final (cur, need) = XpCurve.progress(s.totalXp);
    final streak = GameEngine.currentStreak(s, now);
    final due = s.habits.where((h) => !h.archived && h.isDueOn(now)).length;
    final done = GameEngine.completedToday(s, now);
    final hero =
        Catalog.byId[s.equipped['character']] ?? Catalog.byId['char_raider']!;
    final allDone = due > 0 && done >= due;

    return SafeArea(
      bottom: false,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0A1B3D).withOpacity(.72),
              const Color(0xFF0A1B3D).withOpacity(0),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              key: const Key('hud_avatar'),
              onTap: () => context.push('/profile'),
              child: Semantics(
                button: true,
                label: 'Open profile',
                child: SizedBox(
                  width: 70,
                  height: 72,
                  child: Stack(clipBehavior: Clip.none, children: [
                    CharacterAvatar(item: hero, size: 64),
                    Positioned(
                      left: -4,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: AppColors.outline, width: 2.5),
                        ),
                        child: Text('$level',
                            style: AppText.headingPlain(14)),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(s.playerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.heading(20)),
                      ),
                      const SizedBox(width: 6),
                      RankBadge(
                          rank: rank.name == 'National Level' ? 'N' : rank.name,
                          size: 34),
                    ]),
                    const SizedBox(height: 4),
                    XpBar(current: cur, max: need),
                    const SizedBox(height: 2),
                    Text('Level $level  -  Rank ${rank.name}',
                        style: AppText.body(11, color: Colors.white)),
                  ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ResourceCounter(type: ResourceType.gold, amount: s.gold),
              const SizedBox(height: 6),
              ResourceCounter(type: ResourceType.gem, amount: s.gems),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Chip(
              key: const Key('streak_chip'),
              color: AppColors.danger,
              icon: Icons.local_fire_department,
              text: '$streak day${streak == 1 ? '' : 's'}',
              onTap: () => context.push('/calendar'),
            ),
            const SizedBox(width: 8),
            _Chip(
              key: const Key('today_chip'),
              color: allDone ? AppColors.success : AppColors.panelLight,
              icon: allDone ? Icons.emoji_events : Icons.check_circle,
              text: due == 0 ? 'No habits' : 'Today $done / $due',
              onTap: () => context.go('/habits'),
            ),
          ]),
          if (s.habits.isEmpty) ...[
            const SizedBox(height: 10),
            GameButton(
              label: 'Create your first habit',
              icon: Icons.add,
              compact: true,
              onPressed: () => context.push('/habit/new'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
          decoration: BoxDecoration(
            color: AppColors.panelDeep,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outline, width: 2.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(text,
                style: AppText.body(13,
                    color: Colors.white, weight: FontWeight.w800)),
          ]),
        ),
      );
}
