import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/xp_curve.dart';
import 'diwan/diwan_screen.dart';
import 'kingdom/kingdom_screen.dart';
import 'ow_style.dart';
import 'tasks/tasks_screen.dart';
import 'world/world_screen.dart';

final shellTabProvider = StateProvider<int>((ref) => 0);

/// Four tabs: Kingdom, World, Tasks, Diwan. The HUD sits on top of all.
class OwShell extends ConsumerWidget {
  const OwShell({super.key});

  static const _tabs = [
    (icon: Icons.castle, label: 'المملكة'),
    (icon: Icons.public, label: 'العالم'),
    (icon: Icons.task_alt, label: 'المهام'),
    (icon: Icons.menu_book, label: 'الديوان'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(shellTabProvider);
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: IndexedStack(index: tab, children: const [
            KingdomScreen(),
            WorldScreen(),
            TasksScreen(),
            DiwanScreen(),
          ]),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: OwHud()),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Ow.panel,
          border: Border(top: BorderSide(color: Ow.edge, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    key: Key('tab_$i'),
                    onTap: () => ref.read(shellTabProvider.notifier).state = i,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_tabs[i].icon,
                            color: i == tab ? Ow.gold : Ow.muted, size: 26),
                        Text(_tabs[i].label,
                            style: Ow.body(12,
                                color: i == tab ? Ow.gold : Ow.muted)),
                      ],
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Level, rank, XP bar and resources.
class OwHud extends ConsumerWidget {
  const OwHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final level = GameEngine.level(s);
    final rank = GameEngine.rank(s);
    final (into, need) = XpCurve.progress(s.totalXp);
    final streak = GameEngine.currentStreak(s, now);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Ow.bg.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Ow.edge),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Ow.panelHi,
                  border: Border.all(color: Ow.gold, width: 2),
                ),
                child: Text('$level',
                    key: const Key('hud_level'), style: Ow.title(16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.playerName} · رتبة ${rank.name}',
                        style: Ow.body(13), overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: need <= 0 ? 1 : (into / need).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Ow.panelHi,
                        color: Ow.xp,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              ResourceChip(
                  icon: Icons.monetization_on,
                  value: fmt(s.gold),
                  color: Ow.gold,
                  tooltip: 'ذهب'),
              ResourceChip(
                  icon: Icons.diamond, value: fmt(s.gems), color: Ow.gem,
                  tooltip: 'جواهر'),
              ResourceChip(
                  icon: Icons.inventory_2,
                  value: fmt(s.world.supplies),
                  color: Ow.supply,
                  tooltip: 'إمدادات'),
              ResourceChip(
                  icon: Icons.shield,
                  value: '${s.streak.freezesHeld}',
                  color: Ow.xp,
                  tooltip: 'تحصينات'),
              ResourceChip(
                  icon: Icons.local_fire_department,
                  value: '$streak',
                  color: Ow.danger,
                  tooltip: 'أيام متصلة'),
              if (s.world.stones > 0)
                ResourceChip(
                    icon: Icons.view_in_ar,
                    value: '${s.world.stones}',
                    color: Ow.muted,
                    tooltip: 'حجر الأساس'),
            ]),
          ]),
        ),
      ),
    );
  }
}
