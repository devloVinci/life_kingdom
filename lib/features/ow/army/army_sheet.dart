import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/world_engine.dart';
import '../ow_style.dart';

void showArmySheet(BuildContext context) => showModalBottomSheet(
      context: context,
      backgroundColor: Ow.panel,
      builder: (_) => const ArmySheet(),
    );

/// Train the few unit types with gold + supplies; shows army power.
class ArmySheet extends ConsumerWidget {
  const ArmySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final level = GameEngine.level(s);
    final size = ArmyEngine.armySize(s);
    final cap = ArmyEngine.campCapacity(level);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الثكنة', style: Ow.title(20, color: Ow.gold)),
          const SizedBox(height: 4),
          Text(
              'قوة الجيش ${ArmyEngine.armyPower(s)} '
              '(الفارس ${ArmyEngine.heroPower(level)}) · المعسكر $size من $cap',
              style: Ow.body(13, color: Ow.muted)),
          const SizedBox(height: 12),
          for (final u in ArmyEngine.units)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OwPanel(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${u.name} × ${s.world.army[u.id] ?? 0}',
                            style: Ow.body(15, weight: FontWeight.w800)),
                        Text(
                            'قوة ${u.power} · ${u.gold} ذهب + ${u.supplies} إمدادات',
                            style: Ow.body(12, color: Ow.muted)),
                      ],
                    ),
                  ),
                  for (final n in const [1, 5])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(start: 6),
                      child: OwButton(
                        key: Key('train_${u.id}_$n'),
                        label: '+$n',
                        onPressed: () {
                          final st = ref
                              .read(gameProvider.notifier)
                              .train(u.id, n);
                          if (st != TrainStatus.ok) {
                            owToast(
                                context,
                                switch (st) {
                                  TrainStatus.noGold => 'لا يكفي الذهب',
                                  TrainStatus.noSupplies =>
                                    'لا تكفي الإمدادات: أنجز مهامك لتجمعها',
                                  TrainStatus.campFull =>
                                    'المعسكر ممتلئ: يتسع مع مستواك',
                                  _ => 'تعذّر التدريب',
                                });
                          }
                        },
                      ),
                    ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}
