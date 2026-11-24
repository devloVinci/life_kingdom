import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/catalog.dart';
import '../../core/game/economy_engine.dart';
import '../../core/game/game_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
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
