import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_config.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/world_engine.dart';
import '../ow_style.dart';

const difficultyNames = {
  Difficulty.easy: 'سهلة',
  Difficulty.medium: 'متوسطة',
  Difficulty.hard: 'صعبة',
  Difficulty.epic: 'ملحمية',
};

/// Today's habits and one-off tasks. Every finished item feeds the kingdom.
class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(nowProvider)();
    final today = dateKeyOf(now);
    final habits =
        s.habits.where((h) => !h.archived && h.isDueOn(now)).toList();
    final openTasks = s.tasks.where((t) => !t.done).toList();
    final doneToday = s.tasks.where((t) => t.doneKey == today).toList();
    final doneHabits = {
      for (final c in s.completions)
        if (c.dateKey == today) c.habitId
    };

    return Scaffold(
      backgroundColor: Ow.bg,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add_item'),
        backgroundColor: Ow.gold,
        foregroundColor: Ow.bg,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Ow.panel,
          builder: (_) => const _AddSheet(),
        ),
        icon: const Icon(Icons.add),
        label: Text('إضافة', style: Ow.body(15, color: Ow.bg)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 130, 14, 100),
        children: [
          Text('عادات اليوم', style: Ow.title(20, color: Ow.gold)),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            Text('لا عادات لليوم. أضف عادة من زر الإضافة.',
                style: Ow.body(13, color: Ow.muted)),
          for (final h in habits)
            _ItemTile(
              key: Key('habit_${h.id}'),
              title: h.title,
              difficulty: h.difficulty,
              done: doneHabits.contains(h.id),
              onToggle: () {
                final game = ref.read(gameProvider.notifier);
                if (doneHabits.contains(h.id)) {
                  game.undo(h.id);
                } else {
                  final o = game.complete(h.id);
                  if (o.ok) _rewardToast(context, o, h.difficulty);
                }
              },
              onLongPress: () => _confirmDelete(context, () {
                ref.read(gameProvider.notifier).deleteHabit(h.id);
              }),
            ),
          const SizedBox(height: 20),
          Text('المهام', style: Ow.title(20, color: Ow.gold)),
          const SizedBox(height: 4),
          Text('اضغط النجمة على أهم مهمة اليوم: إنجازها يمنحك حجر أساس.',
              style: Ow.body(12, color: Ow.muted)),
          const SizedBox(height: 8),
          if (openTasks.isEmpty && doneToday.isEmpty)
            Text('لا مهام مفتوحة.', style: Ow.body(13, color: Ow.muted)),
          for (final t in openTasks)
            _ItemTile(
              key: Key('task_${t.id}'),
              title: t.title,
              difficulty: t.difficulty,
              done: false,
              starred: s.world.mainTaskId == t.id && s.world.mainTaskKey == today,
              onStar: () =>
                  ref.read(gameProvider.notifier).setMainTask(t.id),
              onToggle: () {
                final o = ref.read(gameProvider.notifier).completeTask(t.id);
                if (o.ok) {
                  if (o.goldGained > 0) {
                    _rewardToast(context, o, t.difficulty);
                  } else {
                    owToast(context,
                        'أُنجزت. بلغت حد مكافآت المهام لهذا اليوم.');
                  }
                }
              },
              onLongPress: () => _confirmDelete(context, () {
                ref.read(gameProvider.notifier).deleteTask(t.id);
              }),
            ),
          for (final t in doneToday)
            _ItemTile(
              title: t.title,
              difficulty: t.difficulty,
              done: true,
              onToggle: null,
            ),
        ],
      ),
    );
  }

  void _rewardToast(
      BuildContext context, CompletionOutcome o, Difficulty d) {
    owToast(context,
        '+${o.xpGained} خبرة · +${o.goldGained} ذهب · +${WorldConfig.supplies[d]} إمدادات · المنجم يمتلئ');
  }

  void _confirmDelete(BuildContext context, VoidCallback onYes) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Ow.panel,
        title: Text('حذف؟', style: Ow.title(18)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: Text('إلغاء', style: Ow.body(14))),
          TextButton(
              onPressed: () {
                onYes();
                Navigator.pop(c);
              },
              child: Text('حذف', style: Ow.body(14, color: Ow.danger))),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    super.key,
    required this.title,
    required this.difficulty,
    required this.done,
    required this.onToggle,
    this.onLongPress,
    this.starred = false,
    this.onStar,
  });

  final String title;
  final Difficulty difficulty;
  final bool done;
  final VoidCallback? onToggle;
  final VoidCallback? onLongPress;
  final bool starred;
  final VoidCallback? onStar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: onToggle,
          onLongPress: onLongPress,
          child: OwPanel(
            accent: done ? Ow.supply : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: done ? Ow.supply : Ow.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: Ow.body(15,
                        color: done ? Ow.muted : Ow.text,
                        weight: FontWeight.w700)),
              ),
              Text(difficultyNames[difficulty]!,
                  style: Ow.body(12, color: Ow.muted)),
              if (onStar != null)
                IconButton(
                  onPressed: onStar,
                  icon: Icon(starred ? Icons.star : Icons.star_border,
                      color: starred ? Ow.gold : Ow.muted),
                ),
            ]),
          ),
        ),
      );
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet();

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  final _title = TextEditingController();
  bool _habit = false;
  Difficulty _difficulty = Difficulty.medium;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final game = ref.read(gameProvider.notifier);
    final id = game.newHabitId();
    try {
      if (_habit) {
        game.addHabit(Habit(id: id, title: title, difficulty: _difficulty));
      } else {
        game.addTask(TaskItem(id: id, title: title, difficulty: _difficulty));
      }
      Navigator.pop(context);
    } catch (e) {
      owToast(context, 'تعذّرت الإضافة: بلغت الحد الأقصى');
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('مهمة', style: Ow.body(14))),
                ButtonSegment(value: true, label: Text('عادة يومية', style: Ow.body(14))),
              ],
              selected: {_habit},
              onSelectionChanged: (v) => setState(() => _habit = v.first),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('add_title'),
              controller: _title,
              autofocus: true,
              style: Ow.body(15),
              decoration: InputDecoration(
                hintText: _habit ? 'اسم العادة' : 'ما المهمة؟',
                filled: true,
                fillColor: Ow.panelHi,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final d in Difficulty.values)
                ChoiceChip(
                  label: Text(difficultyNames[d]!, style: Ow.body(13)),
                  selected: _difficulty == d,
                  onSelected: (_) => setState(() => _difficulty = d),
                ),
            ]),
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OwButton(
                  key: const Key('add_save'), label: 'حفظ', onPressed: _save),
            ),
          ],
        ),
      );
}
