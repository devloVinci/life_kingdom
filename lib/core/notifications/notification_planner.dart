import '../game/models.dart';

/// One local notification to be delivered at an exact moment.
class PlannedNotification {
  const PlannedNotification({
    required this.at,
    required this.title,
    required this.body,
    required this.kind,
  });

  final DateTime at;
  final String title;
  final String body;

  /// habit | missed | open
  final String kind;

  @override
  bool operator ==(Object o) =>
      o is PlannedNotification &&
      o.at == at &&
      o.title == title &&
      o.body == body &&
      o.kind == kind;

  @override
  int get hashCode => Object.hash(at, title, body, kind);

  @override
  String toString() => '$kind@$at "$title"';
}

/// Turns the game state into the list of notifications to schedule.
///
/// Phones cannot run "if the habit is not done" logic at delivery time, so we
/// schedule concrete one-shot notifications for the next [horizonDays] days
/// and re-plan every time the app opens or the state changes (completing a
/// habit removes today's reminders for it). Pure Dart, fully testable.
class NotificationPlanner {
  NotificationPlanner._();

  static const horizonDays = 14;

  /// iOS keeps at most 64 pending local notifications; stay below it.
  static const maxCount = 60;

  /// Evening "unfinished habits" reminder, minutes after midnight (20:00).
  static const missedMinutes = 20 * 60;

  /// "Come back to your kingdom" reminder (18:00).
  static const openMinutes = 18 * 60;

  static List<PlannedNotification> plan(GameState s, DateTime now) {
    final out = <PlannedNotification>[];
    final todayKey = dateKeyOf(now);
    final active = s.habits.where((h) => !h.archived).toList();
    final doneToday = {
      for (final c in s.completions)
        if (c.dateKey == todayKey) c.habitId,
    };
    final today = DateTime(now.year, now.month, now.day);

    for (var i = 0; i < horizonDays; i++) {
      final day = today.add(Duration(days: i));
      final isToday = i == 0;
      final due = active.where((h) => h.isDueOn(day)).toList();

      if (s.setting('notif_habit_reminders')) {
        for (final h in due) {
          final m = h.reminderMinutes;
          if (m == null) continue;
          if (isToday && doneToday.contains(h.id)) continue;
          out.add(PlannedNotification(
            at: day.add(Duration(minutes: m)),
            title: h.title,
            body: 'Time for your habit! Earn XP and gold for your kingdom.',
            kind: 'habit',
          ));
        }
      }

      if (s.setting('notif_missed_daily') && due.isNotEmpty) {
        final left = isToday
            ? due.where((h) => !doneToday.contains(h.id)).length
            : due.length;
        if (left > 0) {
          out.add(PlannedNotification(
            at: day.add(const Duration(minutes: missedMinutes)),
            title: 'Your quests are waiting',
            body: left == 1
                ? '1 habit is still unfinished today. Protect your streak!'
                : '$left habits are still unfinished today. Protect your streak!',
            kind: 'missed',
          ));
        }
      }

      // The app is open right now, so today's "open the app" nudge is moot.
      if (s.setting('notif_app_open') && !isToday) {
        out.add(PlannedNotification(
          at: day.add(const Duration(minutes: openMinutes)),
          title: 'Your kingdom misses you',
          body: 'Open Life Kingdom and keep your streak alive.',
          kind: 'open',
        ));
      }
    }

    final future = out.where((n) => n.at.isAfter(now)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    return future.length <= maxCount ? future : future.sublist(0, maxCount);
  }
}
