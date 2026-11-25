import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/game_config.dart';
import '../../core/game/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/reward_feedback.dart';
import 'tasks_view.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  bool _tasks = false;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final key = dateKeyOf(now);
    final doneIds = {
      for (final c in s.completions)
        if (c.dateKey == key) c.habitId
    };
    final active = s.habits.where((h) => !h.archived).toList();
    final today = active.where((h) => h.isDueOn(now)).toList();
    final later = active.where((h) => !h.isDueOn(now)).toList();

    return GameBackground(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_tasks ? 'Tasks' : "Today's Habits",
              style: AppText.heading(28)),
          const SizedBox(height: 12),
          Row(children: [
            ChoiceChip(
              key: const Key('seg_habits'),
              label: const Text('Habits'),
              selected: !_tasks,
              onSelected: (_) => setState(() => _tasks = false),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              key: const Key('seg_tasks'),
              label: Text(
                  'Tasks (${s.tasks.where((t) => !t.done).length})'),
              selected: _tasks,
              onSelected: (_) => setState(() => _tasks = true),
            ),
          ]),
          const SizedBox(height: 12),
          if (_tasks)
            const TasksView()
          else ...[
          if (active.isEmpty)
            GamePanel(
              child: Column(children: [
                Text('No habits yet', style: AppText.headingPlain(20)),
                const SizedBox(height: 4),
                Text('Create a habit to start earning XP and gold.',
                    textAlign: TextAlign.center, style: AppText.body(14)),
              ]),
            ),
          for (final h in today)
            _HabitTile(habit: h, done: doneIds.contains(h.id)),
          if (later.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Not scheduled today',
                style: AppText.body(14, color: AppColors.onBackground)),
            const SizedBox(height: 8),
            for (final h in later) _HabitTile(habit: h, done: false, dim: true),
          ],
          const SizedBox(height: 16),
          Center(
            child: GameButton(
              label: 'New Habit',
              icon: Icons.add,
              onPressed: () => context.push('/habit/new'),
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile({required this.habit, required this.done, this.dim = false});

  final Habit habit;
  final bool done;
  final bool dim;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final xp = GameConfig.habitXp[habit.difficulty]!;
    final gold = GameConfig.habitGold[habit.difficulty]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: dim ? 0.6 : 1,
        child: GamePanel(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            GestureDetector(
              key: const Key('complete_button'),
              onTap: dim
                  ? null
                  : () {
                      final c = ref.read(gameProvider.notifier);
                      final o = done ? c.undo(habit.id) : c.complete(habit.id);
                      showOutcomeFeedback(context, o);
                      final unlocked = c.takeUnlocked();
                      if (unlocked.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Achievement unlocked: ${unlocked.map((a) => a.title).join(', ')}')));
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: done
                      ? AppColors.success
                      : (AppColors.palette.chunky ? Colors.white : AppColors.panelRaised),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.palette.chunky
                          ? AppColors.outline
                          : (done ? AppColors.success : AppColors.accent.withValues(alpha: 0.55)),
                      width: AppColors.palette.chunky ? 3 : 2),
                  boxShadow: [
                    if (done && !AppColors.palette.chunky)
                      BoxShadow(color: AppColors.success.withValues(alpha: 0.5), blurRadius: 12),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: done
                      ? const Icon(Icons.check_rounded, key: ValueKey('on'), color: Colors.white)
                      : const SizedBox(key: ValueKey('off')),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.title,
                        style: AppText.headingPlain(18).copyWith(
                            decoration:
                                done ? TextDecoration.lineThrough : null)),
                    Text(
                        '${habit.difficulty.name.toUpperCase()}  -  +$xp XP  +$gold gold',
                        style: AppText.body(12)),
                  ]),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: Icon(Icons.edit, color: AppColors.panelPrimary),
              onPressed: () => context.push('/habit/${habit.id}'),
            ),
          ]),
        ),
      ),
    );
  }
}
