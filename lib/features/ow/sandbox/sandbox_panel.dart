import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_config.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/world_engine.dart';
import '../../../core/game/xp_curve.dart';
import '../../../game/atlas/anim_overrides.dart';
import '../../../game/atlas/sprite_atlas.dart';
import '../ow_style.dart';

void showSandboxPanel(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Ow.panel,
      builder: (_) => const FractionallySizedBox(
        heightFactor: 0.85,
        child: SandboxPanel(),
      ),
    );

/// Try-anything tools. Only works on the sandbox save; the real progress is
/// untouched and comes back when you leave.
class SandboxPanel extends ConsumerWidget {
  const SandboxPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(sandboxModeProvider);
    final game = ref.read(gameProvider.notifier);
    final s = ref.watch(gameProvider);
    final days = ref.watch(sandboxDaysProvider);
    final level = GameEngine.level(s);
    final now = ref.watch(nowProvider)();

    void edit(GameState Function(GameState) f, String msg) {
      game.sandboxEdit(f);
      owToast(context, msg);
    }

    Widget btn(String label, VoidCallback onTap, {Color color = Ow.gold}) =>
        OwButton(label: label, onPressed: onTap, color: color);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          Expanded(
              child: Text('وضع التجربة', style: Ow.title(22, color: Ow.gold))),
          Switch(
            key: const Key('sandbox_switch'),
            value: on,
            onChanged: (v) => v ? game.enterSandbox() : game.exitSandbox(),
          ),
        ]),
        Text(
            'نسخة منفصلة تجرّب فيها ما تشاء: المستوى والموارد والزمن والجيش. '
            'تقدّمك الحقيقي لا يُمسّ، ويعود كما هو حين تخرج. '
            'الإشعارات لا تعمل في هذا الوضع.',
            style: Ow.body(13, color: Ow.muted)),
        const SizedBox(height: 14),
        if (!on)
          Wrap(spacing: 8, runSpacing: 8, children: [
            btn('ادخل (نسخة من تقدّمي)',
                () => game.enterSandbox(copyReal: true)),
            btn('ادخل ببداية فارغة', () => game.enterSandbox(fresh: true),
                color: Ow.xp),
          ])
        else ...[
          _Section('المستوى: $level', [
            Slider(
              key: const Key('sandbox_level'),
              value: level.toDouble(),
              min: 1,
              max: 100,
              divisions: 99,
              label: '$level',
              onChanged: (v) => game.sandboxEdit(
                  (s) => s.copyWith(totalXp: XpCurve.xpForLevel(v.round()))),
            ),
            Text(
                'نصف قطر العالم ${WorldEngine.worldRadius(level).toStringAsFixed(1)} · '
                'المعسكر يتسع ${ArmyEngine.campCapacity(level)}',
                style: Ow.body(12, color: Ow.muted)),
          ]),
          _Section('الموارد', [
            Wrap(spacing: 8, runSpacing: 8, children: [
              btn('+500 ذهب',
                  () => edit((s) => s.copyWith(gold: s.gold + 500), '+500 ذهب')),
              btn('+20 جوهرة',
                  () => edit((s) => s.copyWith(gems: s.gems + 20), '+20 جوهرة')),
              btn(
                  '+100 إمدادات',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world
                              .copyWith(supplies: s.world.supplies + 100)),
                      '+100 إمدادات')),
              btn(
                  '+50 حصاد',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world.copyWith(
                              pendingHarvest: s.world.pendingHarvest + 50)),
                      'المنجم امتلأ')),
              btn(
                  '+1 تحصين',
                  () => edit(
                      (s) => s.copyWith(
                          streak: s.streak.copyWith(
                              freezesHeld: min(WorldConfig.maxFortifications,
                                  s.streak.freezesHeld + 1))),
                      '+1 تحصين')),
              btn(
                  '+1 حجر أساس',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world.copyWith(stones: s.world.stones + 1)),
                      '+1 حجر أساس')),
            ]),
          ]),
          _Section('الإنجاز', [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final d in Difficulty.values)
                btn('أنجز مهمة ${_dName[d]}', () {
                  final id = game.newHabitId();
                  game.addTask(TaskItem(
                      id: id, title: 'مهمة تجريبية', difficulty: d));
                  game.completeTask(id);
                  owToast(context, 'أُنجزت مهمة ${_dName[d]}');
                }, color: Ow.supply),
            ]),
          ]),
          _Section('الزمن (اليوم +$days)', [
            Text('التاريخ في التجربة: ${dateKeyOf(now)}',
                style: Ow.body(12, color: Ow.muted)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              btn('+1 يوم', () => game.sandboxJumpDays(1), color: Ow.xp),
              btn('+7 أيام', () => game.sandboxJumpDays(7), color: Ow.xp),
              btn('أسبوع إنجاز كامل', () {
                for (var i = 0; i < 7; i++) {
                  final id = '${game.newHabitId()}_$i';
                  game.addTask(TaskItem(
                      id: id, title: 'يوم $i', difficulty: Difficulty.hard));
                  game.completeTask(id);
                  game.sandboxJumpDays(1);
                }
                owToast(context, 'مرّ أسبوع فيه إنجاز كل يوم');
              }, color: Ow.xp),
            ]),
            const SizedBox(height: 4),
            Text(
                'القفز يوماً دون إنجاز يجلب الغول. القفز إلى يوم الاثنين يعيد الكشّافة بالتقرير.',
                style: Ow.body(12, color: Ow.muted)),
          ]),
          _Section('أحداث', [
            Wrap(spacing: 8, runSpacing: 8, children: [
              btn(
                  'استدعِ الغول',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world.copyWith(
                              goblinLoot: s.world.goblinLoot + 60)),
                      'جاء غول بستين ذهباً'),
                  color: Ow.danger),
              btn(
                  'أفضل أسبوع +40',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world
                              .copyWith(bestWeek: s.world.bestWeek + 40)),
                      'ارتفع البرج'),
                  color: Ow.gem),
              btn(
                  '+5 محاربين و+3 راميات',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world.copyWith(army: {
                            ...s.world.army,
                            'barbarian': (s.world.army['barbarian'] ?? 0) + 5,
                            'archer': (s.world.army['archer'] ?? 0) + 3,
                          })),
                      'انضم جنود'),
                  color: Ow.gem),
              btn(
                  'امسح الفتوحات',
                  () => edit(
                      (s) => s.copyWith(
                          world: s.world.copyWith(captured: const {})),
                      'عادت المعالم بلا رايات'),
                  color: Ow.panelHi),
            ]),
          ]),
          _Section('حركات الشخصيات', [
            Text(
                'اختر لكل شخصية الحركة الصحيحة من الحزمة. يُحفظ اختيارك ويُستعمل في الوضعين.',
                style: Ow.body(12, color: Ow.muted)),
            const SizedBox(height: 6),
            for (final slot in CharacterSlots.slots.keys) _AnimPicker(slot),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () =>
                    ref.read(animOverridesProvider.notifier).reset(),
                child: Text('أعد الاختيارات الأصلية', style: Ow.body(13)),
              ),
            ),
          ]),
          _Section('البداية من جديد', [
            Wrap(spacing: 8, runSpacing: 8, children: [
              btn('نسخة من تقدّمي الحقيقي',
                  () => game.enterSandbox(copyReal: true),
                  color: Ow.panelHi),
              btn('بداية فارغة', () => game.enterSandbox(fresh: true),
                  color: Ow.panelHi),
              btn('اخرج من التجربة', () {
                game.exitSandbox();
                Navigator.pop(context);
              }, color: Ow.danger),
            ]),
          ]),
        ],
      ],
    );
  }

  static const _dName = {
    Difficulty.easy: 'سهلة',
    Difficulty.medium: 'متوسطة',
    Difficulty.hard: 'صعبة',
    Difficulty.epic: 'ملحمية',
  };
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OwPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Ow.title(16)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

class _AnimPicker extends ConsumerWidget {
  const _AnimPicker(this.slot);
  final String slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (atlasId, _, label) = CharacterSlots.slots[slot]!;
    final atlas = ref.watch(atlasProvider(atlasId)).valueOrNull;
    final current = animFor(ref.watch(animOverridesProvider), slot);
    final names = atlas?.data.animations.keys.toList() ?? const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Expanded(child: Text(label, style: Ow.body(13))),
        if (names.isEmpty)
          Text(current, style: Ow.body(11, color: Ow.muted))
        else
          DropdownButton<String>(
            value: names.contains(current) ? current : null,
            dropdownColor: Ow.panelHi,
            style: Ow.body(12),
            items: [
              for (final n in names)
                DropdownMenuItem(value: n, child: Text(n)),
            ],
            onChanged: (v) {
              if (v != null) {
                ref.read(animOverridesProvider.notifier).set(slot, v);
              }
            },
          ),
      ]),
    );
  }
}
