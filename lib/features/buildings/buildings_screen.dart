import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/catalog.dart';
import '../../core/game/economy_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_panel.dart';

class BuildingsScreen extends ConsumerWidget {
  const BuildingsScreen({super.key});

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
              Text('Buildings', style: AppText.heading(26)),
            ]),
            const SizedBox(height: 8),
            GamePanel(
              child: Row(children: [
                const Icon(Icons.construction, color: AppColors.wood),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Builders busy: ${EconomyEngine.busyBuilders(s)} / ${EconomyEngine.builderSlots(s)}',
                      style: AppText.headingPlain(16)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            for (final b in Catalog.buildings)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BuildingTile(def: b),
              ),
          ],
        ),
      ),
    );
  }
}

class _BuildingTile extends ConsumerWidget {
  const _BuildingTile({required this.def});

  final BuildingDef def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final b = s.building(def.id);
    final left = EconomyEngine.daysLeft(s, def.id);
    return GestureDetector(
      onTap: () => context.push('/building/${def.id}'),
      child: GamePanel(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.wood,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outline, width: 3),
            ),
            child: Text('${b.level}', style: AppText.heading(22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(def.name, style: AppText.headingPlain(18)),
                  Text(
                      b.upgrading
                          ? 'Upgrading to ${b.upgradeTarget}  -  $left work day${left == 1 ? '' : 's'} left'
                          : 'Level ${b.level}',
                      style: AppText.body(12)),
                ]),
          ),
          Icon(Icons.chevron_right, color: AppColors.panelPrimary),
        ]),
      ),
    );
  }
}
