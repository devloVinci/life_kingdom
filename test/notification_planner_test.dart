import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/game_config.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/notifications/notification_planner.dart';

Habit habit(String id, {int? reminder, Set<int>? days, bool archived = false}) =>
    Habit(
      id: id,
      title: 'Habit $id',
      difficulty: Difficulty.medium,
      weekdays: days ?? const {1, 2, 3, 4, 5, 6, 7},
      reminderMinutes: reminder,
      archived: archived,
    );

void main() {
  // Wednesday 2026-11-25, 09:00.
  final now = DateTime(2026, 11, 25, 9, 0);

  test('schedules a habit reminder for every due day in the horizon', () {
    final s = GameState(habits: [habit('a', reminder: 7 * 60 + 30)]);
    final p = NotificationPlanner.plan(s, now);
    final habits = p.where((n) => n.kind == 'habit').toList();
    // Today's 07:30 already passed, so 13 days remain.
    expect(habits.length, NotificationPlanner.horizonDays - 1);
    expect(habits.first.at, DateTime(2026, 11, 26, 7, 30));
  });

  test('respects specific weekdays', () {
    final s = GameState(habits: [habit('a', reminder: 20 * 60 + 30, days: {1})]);
    final p = NotificationPlanner.plan(s, now)
        .where((n) => n.kind == 'habit')
        .toList();
    expect(p.every((n) => n.at.weekday == DateTime.monday), isTrue);
    expect(p.length, 2); // two Mondays in 14 days
  });

  test('completed habit skips only today\'s reminders', () {
    final s = GameState(
      habits: [habit('a', reminder: 21 * 60)],
      completions: [
        Completion(habitId: 'a', dateKey: dateKeyOf(now), xp: 10, gold: 5),
      ],
    );
    final p = NotificationPlanner.plan(s, now);
    expect(p.where((n) => n.kind == 'habit').first.at.day, 26);
    // Nothing left today, so no "missed" nudge today either.
    expect(
        p.where((n) => n.kind == 'missed' && n.at.day == 25), isEmpty);
    expect(p.where((n) => n.kind == 'missed' && n.at.day == 26), isNotEmpty);
  });

  test('missed reminder counts unfinished habits today', () {
    final s = GameState(habits: [habit('a'), habit('b')]);
    final today = NotificationPlanner.plan(s, now)
        .firstWhere((n) => n.kind == 'missed' && n.at.day == 25);
    expect(today.at, DateTime(2026, 11, 25, 20, 0));
    expect(today.body, contains('2 habits'));
  });

  test('open-the-app nudge skips today', () {
    final s = GameState(habits: [habit('a')]);
    final p = NotificationPlanner.plan(s, now);
    final open = p.where((n) => n.kind == 'open').toList();
    expect(open.first.at, DateTime(2026, 11, 26, 18, 0));
  });

  test('toggles switch kinds off', () {
    final s = GameState(habits: [
      habit('a', reminder: 600)
    ], settings: const {
      'notif_habit_reminders': false,
      'notif_missed_daily': false,
      'notif_app_open': false,
    });
    expect(NotificationPlanner.plan(s, now), isEmpty);
  });

  test('archived habits are ignored and the list is capped and sorted', () {
    final s = GameState(habits: [
      for (var i = 0; i < 10; i++) habit('h$i', reminder: 480 + i),
      habit('old', reminder: 100, archived: true),
    ]);
    final p = NotificationPlanner.plan(s, now);
    expect(p.length, NotificationPlanner.maxCount);
    expect(p.any((n) => n.title == 'Habit old'), isFalse);
    for (var i = 1; i < p.length; i++) {
      expect(p[i].at.isBefore(p[i - 1].at), isFalse);
    }
  });
}
