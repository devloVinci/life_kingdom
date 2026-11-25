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

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December',
];
const _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class CalendarStatsScreen extends ConsumerStatefulWidget {
  const CalendarStatsScreen({super.key});

  @override
  ConsumerState<CalendarStatsScreen> createState() => _CalendarStatsState();
}

class _CalendarStatsState extends ConsumerState<CalendarStatsScreen> {
  late DateTime _month;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final todayKey = dateKeyOf(now);

    final perDay = <String, int>{};
    for (final c in s.completions) {
      perDay[c.dateKey] = (perDay[c.dateKey] ?? 0) + 1;
    }
    final freeze = s.streak.freezeDates;

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1; // Monday-first grid

    final last7 = [for (var i = 6; i >= 0; i--) addDays(dayStart(now), -i)];
    final maxCount =
        last7.map((d) => perDay[dateKeyOf(d)] ?? 0).fold<int>(1, (a, b) => a > b ? a : b);

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
              Expanded(
                  child: Text('Calendar & Stats', style: AppText.heading(24))),
            ]),
            const SizedBox(height: 8),
            GamePanel(
              child: Column(children: [
                Row(children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month - 1)),
                  ),
                  Expanded(
                    child: Text('${_months[_month.month - 1]} ${_month.year}',
                        textAlign: TextAlign.center,
                        style: AppText.headingPlain(20)),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() =>
                        _month = DateTime(_month.year, _month.month + 1)),
                  ),
                ]),
                Row(children: [
                  for (final l in _weekdayLabels)
                    Expanded(
                        child: Center(
                            child: Text(l, style: AppText.body(12)))),
                ]),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (var i = 0; i < offset; i++) const SizedBox.shrink(),
                    for (var d = 1; d <= daysInMonth; d++)
                      _DayCell(
                        day: d,
                        count: perDay[dateKeyOf(DateTime(_month.year, _month.month, d))] ?? 0,
                        frozen: freeze.contains(
                            dateKeyOf(DateTime(_month.year, _month.month, d))),
                        today: dateKeyOf(DateTime(_month.year, _month.month, d)) == todayKey,
                        selected: dateKeyOf(DateTime(_month.year, _month.month, d)) == _selected,
                        onTap: () => setState(() => _selected =
                            dateKeyOf(DateTime(_month.year, _month.month, d))),
                      ),
                  ],
                ),
              ]),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              _DayDetail(dateKey: _selected!),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _Tile(
                      value: '${GameEngine.currentStreak(s, now)}',
                      label: 'Current streak')),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _Tile(value: '${s.streak.longest}', label: 'Best streak')),
              const SizedBox(width: 12),
              Expanded(
                  child: _Tile(
                      value: '${s.completions.length}', label: 'Total done')),
            ]),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last 7 days', style: AppText.headingPlain(18)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 90,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final d in last7)
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text('${perDay[dateKeyOf(d)] ?? 0}',
                                      style: AppText.body(11)),
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 4 +
                                        56 *
                                            ((perDay[dateKeyOf(d)] ?? 0) /
                                                maxCount),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.xp,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppColors.outline, width: 2),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(_weekdayLabels[d.weekday - 1],
                                      style: AppText.body(11)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 12),
            GamePanel(
              child: Row(children: [
                Icon(Icons.ac_unit, color: AppColors.panelLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Streak Freezes: ${s.streak.freezesHeld} / ${GameConfig.maxFreezes}\nProtects one missed day.',
                      style: AppText.body(13)),
                ),
                GameButton(
                  label: '${GameConfig.freezeCost} gold',
                  compact: true,
                  style: GameButtonStyle.gold,
                  onPressed: () {
                    final ok = ref.read(gameProvider.notifier).buyFreeze();
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(ok
                              ? 'Streak Freeze added'
                              : 'Not enough gold, or you already hold the maximum')));
                  },
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.frozen,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool frozen;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = count > 0
        ? AppColors.success
        : frozen
            ? AppColors.panelLight
            : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : today
                    ? AppColors.panelPrimary
                    : AppColors.panelDark,
            width: selected || today ? 3 : 1.5,
          ),
        ),
        child: Text('$day',
            style: AppText.body(13,
                color: count > 0 || frozen ? Colors.white : AppColors.textDark)),
      ),
    );
  }
}

class _DayDetail extends ConsumerWidget {
  const _DayDetail({required this.dateKey});

  final String dateKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final done = s.completions.where((c) => c.dateKey == dateKey).toList();
    String name(String id) {
      for (final h in s.habits) {
        if (h.id == id) return h.title;
      }
      return 'Deleted habit';
    }

    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(dateKey, style: AppText.headingPlain(18)),
        const SizedBox(height: 4),
        if (done.isEmpty)
          Text(
              s.streak.freezeDates.contains(dateKey)
                  ? 'Covered by a Streak Freeze'
                  : 'No habits completed',
              style: AppText.body(13)),
        for (final c in done)
          Text('${name(c.habitId)}  (+${c.xp} XP)', style: AppText.body(13)),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(children: [
        Text(value, style: AppText.headingPlain(20)),
        Text(label, textAlign: TextAlign.center, style: AppText.body(11)),
      ]),
    );
  }
}
