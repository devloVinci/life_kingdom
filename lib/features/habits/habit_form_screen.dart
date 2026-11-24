import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/game_config.dart';
import '../../core/game/game_engine.dart';
import '../../core/game/models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';

/// Create (habitId == null) or edit a habit.
class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.habitId});

  final String? habitId;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  final _title = TextEditingController();
  final _description = TextEditingController();
  Difficulty _difficulty = Difficulty.medium;
  Set<int> _weekdays = {1, 2, 3, 4, 5, 6, 7};
  int? _reminder;
  String? _error;
  Habit? _existing;

  @override
  void initState() {
    super.initState();
    final id = widget.habitId;
    if (id != null) {
      final match =
          ref.read(gameProvider).habits.where((h) => h.id == id).toList();
      if (match.isNotEmpty) {
        _existing = match.first;
        _title.text = _existing!.title;
        _description.text = _existing!.description;
        _difficulty = _existing!.difficulty;
        _weekdays = {..._existing!.weekdays};
        _reminder = _existing!.reminderMinutes;
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _fmt(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime() async {
    final initial = _reminder ?? 9 * 60;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (t != null) setState(() => _reminder = t.hour * 60 + t.minute);
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a name');
      return;
    }
    if (_weekdays.isEmpty) {
      setState(() => _error = 'Pick at least one day');
      return;
    }
    final controller = ref.read(gameProvider.notifier);
    try {
      if (_existing == null) {
        controller.addHabit(Habit(
          id: controller.newHabitId(),
          title: title,
          description: _description.text.trim(),
          difficulty: _difficulty,
          weekdays: _weekdays,
          reminderMinutes: _reminder,
        ));
      } else {
        controller.updateHabit(_existing!.copyWith(
          title: title,
          description: _description.text.trim(),
          difficulty: _difficulty,
          weekdays: _weekdays,
          reminderMinutes: _reminder,
          clearReminder: _reminder == null,
        ));
      }
      context.pop();
    } on HabitLimitException {
      setState(() => _error =
          'You can have at most ${GameConfig.maxActiveHabits} active habits');
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text(
            'The habit will be removed. Your past progress and XP are kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && mounted) {
      ref.read(gameProvider.notifier).deleteHabit(_existing!.id);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = _existing != null;
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
              Text(editing ? 'Edit Habit' : 'New Habit',
                  style: AppText.heading(26)),
            ]),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      key: const Key('habit_title'),
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 16),
                    Text('Difficulty', style: AppText.headingPlain(16)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: [
                      for (final d in Difficulty.values)
                        ChoiceChip(
                          label: Text(
                              '${d.name} (+${GameConfig.habitXp[d]} XP)'),
                          selected: _difficulty == d,
                          onSelected: (_) => setState(() => _difficulty = d),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Text('Repeat on', style: AppText.headingPlain(16)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: [
                      for (var i = 0; i < 7; i++)
                        FilterChip(
                          label: Text(_dayLabels[i]),
                          selected: _weekdays.contains(i + 1),
                          onSelected: (on) => setState(() {
                            on ? _weekdays.add(i + 1) : _weekdays.remove(i + 1);
                          }),
                        ),
                    ]),
                    const SizedBox(height: 16),
                    Text('Reminder', style: AppText.headingPlain(16)),
                    const SizedBox(height: 6),
                    Row(children: [
                      OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.alarm),
                        label: Text(
                            _reminder == null ? 'Set time' : _fmt(_reminder!)),
                      ),
                      if (_reminder != null)
                        IconButton(
                          tooltip: 'Clear reminder',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _reminder = null),
                        ),
                    ]),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: AppText.body(14, color: AppColors.danger)),
                    ],
                  ]),
            ),
            const SizedBox(height: 20),
            Center(child: GameButton(label: 'Save', onPressed: _save)),
            if (editing) ...[
              const SizedBox(height: 12),
              Center(
                child: GameButton(
                  label: 'Delete',
                  style: GameButtonStyle.danger,
                  onPressed: _delete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
