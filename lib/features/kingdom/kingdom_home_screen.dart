import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/catalog.dart';
import '../../core/game/economy_engine.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/xp_curve.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/characters/rig_poses.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/rank_badge.dart';
import '../../core/widgets/resource_counter.dart';
import '../../core/widgets/xp_bar.dart';
import 'living_village.dart';

class KingdomHomeScreen extends ConsumerWidget {
  const KingdomHomeScreen({super.key});

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

    return GameBackground(
      grass: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            ResourceCounter(type: ResourceType.gold, amount: s.gold),
            ResourceCounter(type: ResourceType.gem, amount: s.gems),
            ResourceCounter(type: ResourceType.xp, amount: s.totalXp),
          ]),
          const SizedBox(height: 16),
          LivingVillage(owned: s.owned),
          const SizedBox(height: 16),
          GamePanel(
            child: Column(children: [
              Row(children: [
                RankBadge(
                    rank: rank.name == 'National Level' ? 'N' : rank.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.playerName, style: AppText.headingPlain(22)),
                        Text('Level $level  -  Rank ${rank.name}',
                            style: AppText.body(14)),
                      ]),
                ),
              ]),
              const SizedBox(height: 12),
              XpBar(current: cur, max: need),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department,
                color: AppColors.danger,
                value: '$streak',
                label: 'Day streak',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.check_circle,
                color: AppColors.success,
                value: '$done / $due',
                label: 'Done today',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events,
                color: AppColors.gold,
                value: '${s.streak.longest}',
                label: 'Best streak',
              ),
            ),
          ]),
          const SizedBox(height: 16),
          _HeroPanel(
            character: Catalog.byId[s.equipped['character']] ??
                Catalog.byId['char_raider']!,
            title: Catalog.byId[s.equipped['title']]?.name,
          ),
          if (s.chests.isNotEmpty) ...[
            const SizedBox(height: 16),
            GamePanel(
              child: Column(children: [
                Text('Chests to open', style: AppText.headingPlain(18)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final type in s.chests.toSet())
                    GameButton(
                      label:
                          '$type x${s.chests.where((c) => c == type).length}',
                      compact: true,
                      style: GameButtonStyle.gold,
                      onPressed: () => _openChest(context, ref, type),
                    ),
                ]),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: GameButton(
              label: 'Buildings (${EconomyEngine.busyBuilders(s)}/${EconomyEngine.builderSlots(s)} builders busy)',
              icon: Icons.construction,
              style: GameButtonStyle.blue,
              onPressed: () => context.push('/buildings'),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: s.habits.isEmpty
                ? GameButton(
                    label: 'Create your first habit',
                    icon: Icons.add,
                    onPressed: () => context.push('/habit/new'),
                  )
                : GameButton(
                    label: due - done > 0
                        ? '${due - done} habits left today'
                        : 'All done today!',
                    icon: Icons.checklist,
                    style: GameButtonStyle.blue,
                    onPressed: () => context.go('/habits'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: AppText.headingPlain(20)),
        Text(label,
            textAlign: TextAlign.center, style: AppText.body(11)),
      ]),
    );
  }
}

Future<void> _openChest(BuildContext context, WidgetRef ref, String type) async {
  final r = ref.read(gameProvider.notifier).openChest(type);
  if (r == null || !context.mounted) return;
  final item = r.itemId == null ? null : Catalog.byId[r.itemId!];
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: GamePanel(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Chest opened!', style: AppText.headingPlain(26, color: AppColors.panelPrimary)),
          const SizedBox(height: 12),
          Text('+${r.gold} gold', style: AppText.body(18)),
          if (r.gems > 0) Text('+${r.gems} gems', style: AppText.body(18)),
          if (item != null) ...[
            const SizedBox(height: 12),
            CharacterAvatar(item: item, size: 84, anim: RigAnim.celebrate, animate: true),
            const SizedBox(height: 6),
            Text(
                r.duplicate
                    ? '${item.name} (duplicate, converted to currency)'
                    : 'New hero: ${item.name}!',
                textAlign: TextAlign.center,
                style: AppText.body(15)),
          ],
          const SizedBox(height: 16),
          GameButton(label: 'Nice!', onPressed: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.character, this.title});

  final ShopItem character;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      child: Row(children: [
        CharacterAvatar(item: character, size: 84, animate: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, style: AppText.headingPlain(20)),
                Text(title ?? 'No title equipped', style: AppText.body(13)),
              ]),
        ),
      ]),
    );
  }
}
