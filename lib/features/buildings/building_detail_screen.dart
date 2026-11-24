import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/characters/rig_poses.dart';
import '../../core/game/catalog.dart';
import '../../core/game/companion_engine.dart';
import '../../core/game/economy_engine.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/resource_counter.dart';

class BuildingDetailScreen extends ConsumerWidget {
  const BuildingDetailScreen({super.key, required this.buildingId});

  final String buildingId;

  static String _message(UpgradeStatus st) => switch (st) {
        UpgradeStatus.ok => 'Upgrade started! Complete habits to finish it.',
        UpgradeStatus.notFound => 'Building not found',
        UpgradeStatus.alreadyUpgrading => 'Already upgrading',
        UpgradeStatus.maxLevel => 'Already at max level',
        UpgradeStatus.keepTooLow => 'Upgrade the Keep first',
        UpgradeStatus.playerLevelTooLow => 'Your player level is too low',
        UpgradeStatus.noBuilderFree => 'All builders are busy',
        UpgradeStatus.insufficientGold => 'Not enough gold',
        UpgradeStatus.insufficientGems => 'Not enough gems',
        UpgradeStatus.notUpgrading => 'Nothing to skip',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = Catalog.buildingById[buildingId];
    final s = ref.watch(gameProvider);
    if (def == null) {
      return Scaffold(
        body: GameBackground(
          child: Center(child: Text('Not found', style: AppText.heading(22))),
        ),
      );
    }
    final b = s.building(buildingId);
    final target = b.level + 1;
    final atMax = b.level >= GameConfig.maxBuildingLevel;
    final left = EconomyEngine.daysLeft(s, buildingId);
    final controller = ref.read(gameProvider.notifier);

    void show(UpgradeStatus st) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_message(st))));

    String requirement;
    if (atMax) {
      requirement = 'Max level reached';
    } else if (buildingId == 'keep') {
      requirement =
          'Requires player level ${EconomyEngine.keepPlayerLevelRequirement(target)}';
    } else {
      requirement = 'Requires Keep level $target';
    }

    return Scaffold(
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              Expanded(child: Text(def.name, style: AppText.heading(26))),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ResourceCounter(type: ResourceType.gold, amount: s.gold),
              ResourceCounter(type: ResourceType.gem, amount: s.gems),
            ]),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level ${b.level}', style: AppText.headingPlain(24)),
                    const SizedBox(height: 4),
                    Text(def.description, style: AppText.body(14)),
                    const SizedBox(height: 8),
                    Text('Effect: ${def.effectPerLevel}',
                        style: AppText.body(13, color: AppColors.panelPrimary)),
                  ]),
            ),
            ..._extras(context, s, buildingId),
            const SizedBox(height: 12),
            GamePanel(
              child: b.upgrading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Upgrading to level ${b.upgradeTarget}',
                            style: AppText.headingPlain(18)),
                        const SizedBox(height: 4),
                        Text(
                            '$left work day${left == 1 ? '' : 's'} left. Your Builder works on days you complete a habit.',
                            style: AppText.body(13)),
                        const SizedBox(height: 12),
                        Center(
                          child: GameButton(
                            label: 'Skip with $left gem${left == 1 ? '' : 's'}',
                            style: GameButtonStyle.blue,
                            onPressed: () =>
                                show(controller.skipUpgradeDays(buildingId).status),
                          ),
                        ),
                      ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(atMax ? 'Fully upgraded' : 'Upgrade to level $target',
                            style: AppText.headingPlain(18)),
                        if (!atMax) ...[
                          const SizedBox(height: 4),
                          Text(
                              'Cost: ${EconomyEngine.upgradeCost(target)} gold  -  ${EconomyEngine.workDaysFor(target)} work day${EconomyEngine.workDaysFor(target) == 1 ? '' : 's'}',
                              style: AppText.body(13)),
                          Text(requirement, style: AppText.body(13)),
                          const SizedBox(height: 12),
                          Center(
                            child: GameButton(
                              label: 'Upgrade',
                              icon: Icons.construction,
                              onPressed: () =>
                                  show(controller.startUpgrade(buildingId).status),
                            ),
                          ),
                        ],
                      ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Building-specific panels (each building shows what it actually does).
List<Widget> _extras(BuildContext context, GameState s, String id) {
  Widget panel(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GamePanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.headingPlain(18)),
                const SizedBox(height: 6),
                ...children,
              ]),
        ),
      );
  Widget line(String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(t, style: AppText.body(13)));
  final level = s.buildingLevel(id);

  switch (id) {
    case 'keep':
      final level0 = GameEngine.level(s);
      final next = level + 1;
      return [
        panel('Kingdom levels', [
          line('Every building can be upgraded up to the Keep level ($level).'),
          if (level < GameConfig.maxBuildingLevel)
            line(
                'Keep level $next needs player level ${EconomyEngine.keepPlayerLevelRequirement(next)} (you are level $level0).'),
          const SizedBox(height: 4),
          for (final b in Catalog.buildings.where((b) => b.id != 'keep'))
            line('${b.name}: level ${s.buildingLevel(b.id)}'),
        ]),
      ];
    case 'builders_hut':
      final busy = EconomyEngine.busyBuilders(s);
      final slots = EconomyEngine.builderSlots(s);
      final active = [
        for (final e in s.buildings.entries)
          if (e.value.upgrading) e.key,
      ];
      return [
        panel('Your Builder', [
          Center(
            child: CharacterAvatar(
              item: Catalog.byId['char_builder']!,
              size: 96,
              anim: busy > 0 ? RigAnim.work : RigAnim.idle,
              animate: true,
            ),
          ),
          Center(
              child: Text(
                  busy > 0 ? 'Hammering away!' : 'Waiting for a project',
                  style: AppText.body(13))),
          const SizedBox(height: 6),
          line('Builders busy: $busy / $slots'),
          line('A second builder joins at level 5, a third at level 10.'),
          for (final a in active)
            line(
                '${Catalog.buildingById[a]?.name ?? a}: ${EconomyEngine.daysLeft(s, a)} work day(s) left'),
        ]),
      ];
    case 'treasury':
      return [
        panel('Gold bonus', [
          line('Now: +${(level - 1) * 2}% gold from habits.'),
          if (level < GameConfig.maxBuildingLevel)
            line('Next level: +${level * 2}%.'),
        ]),
      ];
    case 'army_camp':
      return [
        panel('Companions', [
          line(
              'Active slots: ${s.companions.length} / ${CompanionEngine.slots(s)}'),
          if (CompanionEngine.nextSlotLevel(s) != null)
            line('Next slot at level ${CompanionEngine.nextSlotLevel(s)}.'),
          const SizedBox(height: 8),
          Center(
            child: GameButton(
              label: 'Manage companions',
              icon: Icons.pets,
              style: GameButtonStyle.blue,
              onPressed: () => context.push('/companions'),
            ),
          ),
        ]),
      ];
    case 'clan_castle':
      final hero = Catalog.byId[s.equipped['character']];
      return [
        panel('Favourite hero', [
          if (hero != null)
            Row(children: [
              CharacterAvatar(item: hero, size: 56),
              const SizedBox(width: 12),
              Expanded(child: Text(hero.name, style: AppText.headingPlain(18))),
            ]),
          const SizedBox(height: 8),
          Center(
            child: GameButton(
              label: 'Choose hero',
              icon: Icons.groups,
              style: GameButtonStyle.blue,
              onPressed: () => context.push('/collection'),
            ),
          ),
        ]),
      ];
    default:
      // Laboratory, Shop stock tiers and Magic Items are not active yet.
      return [
        panel('Coming soon', [
          line('The effect of this building arrives in a later update. You can already upgrade it.'),
        ]),
      ];
  }
}
