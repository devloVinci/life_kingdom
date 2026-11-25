import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/game/game_config.dart';
import '../../core/game/models.dart';
import '../../core/game/task_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/reward_feedback.dart';

/// One-off to-dos with a due date, paid in XP and gold.
class TasksView extends ConsumerWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final today = dateKeyOf(now);
    final open = s.tasks.where((t) => !t.done).toList()
      ..sort((a, b) => (a.dueKey ?? '9999').compareTo(b.dueKey ?? '9999'));
    final done = s.tasks.where((t) => t.done).toList();
    final left = TaskEngine.dailyRewardCap - TaskEngine.rewardedToday(s, now);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (open.isEmpty)
        GamePanel(
          child: Column(children: [
            Text('No open tasks', style: AppText.headingPlain(20)),
            const SizedBox(height: 4),
            Text('Add things you need to do once: homework, an errand, a call.',
                textAlign: TextAlign.center, style: AppText.body(14)),
          ]),
        ),
      for (final t in open) _TaskTile(task: t, today: today),
      const SizedBox(height: 4),
      Text(
          left > 0
              ? '$left rewarded task${left == 1 ? '' : 's'} left today'
              : 'Daily reward limit reached - tasks still count!',
          textAlign: TextAlign.center,
          style: AppText.body(12, color: AppColors.onBackground)),
      const SizedBox(height: 12),
      Center(
        child: GameButton(
          label: 'New Task',
          icon: Icons.add,
          onPressed: () => _addTask(context, ref, now),
        ),
      ),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: Text('Completed (${done.length})',
                  style: AppText.body(14, color: AppColors.onBackground))),
          TextButton(
            key: const Key('clear_done'),
            onPressed: () => ref.read(gameProvider.notifier).clearDoneTasks(),
            child: const Text('Clear'),
          ),
        ]),
        for (final t in done) _TaskTile(task: t, today: today),
      ],
    ]);
  }
}

Future<void> _addTask(BuildContext context, WidgetRef ref, DateTime now) async {
  final title = TextEditingController();
  var diff = Difficulty.medium;
  String? due; // null, today, tomorrow
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('New Task'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('task_title'),
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'What needs doing?'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 6, children: [
              for (final d in Difficulty.values)
                ChoiceChip(
                  label: Text('${d.name} (+${GameConfig.habitXp[d]})'),
                  selected: diff == d,
                  onSelected: (_) => setState(() => diff = d),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              ChoiceChip(
                  label: const Text('Anytime'),
                  selected: due == null,
                  onSelected: (_) => setState(() => due = null)),
              ChoiceChip(
                  label: const Text('Today'),
                  selected: due == 'today',
                  onSelected: (_) => setState(() => due = 'today')),
              ChoiceChip(
                  label: const Text('Tomorrow'),
                  selected: due == 'tomorrow',
                  onSelected: (_) => setState(() => due = 'tomorrow')),
            ]),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            key: const Key('task_save'),
            onPressed: () {
              final text = title.text.trim();
              if (text.isEmpty) return;
              final dueKey = switch (due) {
                'today' => dateKeyOf(now),
                'tomorrow' => dateKeyOf(addDays(now, 1)),
                _ => null,
              };
              try {
                ref.read(gameProvider.notifier).addTask(TaskItem(
                    id: ref.read(gameProvider.notifier).newHabitId(),
                    title: text,
                    difficulty: diff,
                    dueKey: dueKey));
              } on StateError {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Too many open tasks - finish some first')));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  title.dispose();
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.today});

  final TaskItem task;
  final String today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = GameConfig.habitXp[task.difficulty]!;
    final gold = GameConfig.habitGold[task.difficulty]!;
    final overdue = !task.done && task.dueKey != null && task.dueKey!.compareTo(today) < 0;
    final dueText = task.dueKey == null
        ? 'Anytime'
        : task.dueKey == today
            ? 'Due today'
            : overdue
                ? 'Overdue'
                : 'Due ${task.dueKey}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: task.done ? 0.6 : 1,
        child: GamePanel(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            GestureDetector(
              key: const Key('task_complete'),
              onTap: task.done
                  ? null
                  : () {
                      final o =
                          ref.read(gameProvider.notifier).completeTask(task.id);
                      showOutcomeFeedback(context, o);
                      final c = ref.read(gameProvider.notifier);
                      final unlocked = c.takeUnlocked();
                      if (unlocked.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')}')));
                      }
                    },
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: task.done ? AppColors.success : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outline, width: 3),
                ),
                child: task.done
                    ? const Icon(Icons.check, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title,
                        style: AppText.headingPlain(18).copyWith(
                            decoration:
                                task.done ? TextDecoration.lineThrough : null)),
                    Text('$dueText  -  +$xp XP  +$gold gold',
                        style: AppText.body(12,
                            color: overdue ? AppColors.danger : AppColors.textDark)),
                  ]),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete, color: AppColors.danger),
              onPressed: () =>
                  ref.read(gameProvider.notifier).deleteTask(task.id),
            ),
          ]),
        ),
      ),
    );
  }
}
