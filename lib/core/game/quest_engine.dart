import 'dart:math';

import 'game_config.dart';
import 'game_engine.dart';
import 'models.dart';

enum QuestType { daily, weekly, special }

class QuestTemplate {
  const QuestTemplate({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.target,
    this.xp = 0,
    this.gold = 0,
    this.gems = 0,
    this.chest,
  });

  final String id;
  final QuestType type;
  final String title;
  final String description;

  /// Fixed target (daily "all habits" quest overrides it dynamically).
  final int target;
  final int xp, gold, gems;
  final String? chest;
}

/// A quest as it stands for a given moment.
class QuestView {
  const QuestView({
    required this.template,
    required this.key,
    required this.progress,
    required this.target,
    required this.claimed,
  });

  final QuestTemplate template;

  /// Unique instance key, stored in GameState.claimedQuests when claimed.
  final String key;
  final int progress;
  final int target;
  final bool claimed;

  bool get complete => progress >= target;
  bool get claimable => complete && !claimed;
  double get fraction => target <= 0 ? 0 : (progress / target).clamp(0.0, 1.0);
}

enum ClaimStatus { ok, notFound, notReady, alreadyClaimed }

class ClaimOutcome {
  const ClaimOutcome(this.state, this.status, {this.events = const []});
  final GameState state;
  final ClaimStatus status;
  final List<GameEvent> events;
  bool get ok => status == ClaimStatus.ok;
}

class QuestEngine {
  QuestEngine._();

  static const dailyThree = QuestTemplate(
    id: 'd_three',
    type: QuestType.daily,
    title: 'Triple Threat',
    description: 'Complete 3 habits today',
    target: 3,
    xp: 40,
    gold: 30,
  );
  static const dailyHard = QuestTemplate(
    id: 'd_hard',
    type: QuestType.daily,
    title: 'Face the Challenge',
    description: 'Complete a Hard or Epic habit today',
    target: 1,
    xp: 40,
    gold: 30,
  );
  static const dailyAll = QuestTemplate(
    id: 'd_all',
    type: QuestType.daily,
    title: 'Clean Sweep',
    description: 'Complete every habit scheduled today',
    target: 1,
    xp: 40,
    gold: 30,
  );
  static const dailyBonus = QuestTemplate(
    id: 'bonus',
    type: QuestType.daily,
    title: 'Daily Bonus',
    description: 'Claim all three daily quests',
    target: 3,
    chest: 'wooden',
  );
  static const weeklyDays = QuestTemplate(
    id: 'w_days',
    type: QuestType.weekly,
    title: 'Steady Week',
    description: 'Be active on 5 different days this week',
    target: 5,
    xp: 200,
    gold: 150,
    gems: 5,
  );
  static const weeklyCount = QuestTemplate(
    id: 'w_count',
    type: QuestType.weekly,
    title: 'Habit Machine',
    description: 'Complete 20 habits this week',
    target: 20,
    xp: 200,
    gold: 150,
    gems: 5,
  );
  static const special7 = QuestTemplate(
    id: 's_streak7',
    type: QuestType.special,
    title: 'First Week',
    description: 'Reach a 7-day streak',
    target: 7,
    xp: 300,
    gold: 200,
    gems: 5,
    chest: 'wooden',
  );
  static const special30 = QuestTemplate(
    id: 's_streak30',
    type: QuestType.special,
    title: '30-Day Challenge',
    description: 'Reach a 30-day streak',
    target: 30,
    xp: 1000,
    gold: 600,
    gems: 25,
    chest: 'golden',
  );
  static const special100 = QuestTemplate(
    id: 's_habit100',
    type: QuestType.special,
    title: 'Master of One',
    description: 'Complete the same habit 100 times',
    target: 100,
    xp: 1000,
    gold: 600,
    gems: 25,
    chest: 'golden',
  );

  static const dailyDefs = [dailyThree, dailyHard, dailyAll];
  static const weeklyDefs = [weeklyDays, weeklyCount];
  static const specialDefs = [special7, special30, special100];

  /// Monday of the week containing [d].
  static DateTime weekStart(DateTime d) =>
      addDays(dayStart(d), -(d.weekday - DateTime.monday));

  static List<QuestView> views(GameState s, DateTime now,
      {required QuestType type}) {
    final today = dateKeyOf(now);
    final weekStartKey = dateKeyOf(weekStart(now));
    final weekEndKey = dateKeyOf(addDays(weekStart(now), 6));

    final todays = s.completions.where((c) => c.dateKey == today).toList();
    final week = s.completions
        .where((c) =>
            c.dateKey.compareTo(weekStartKey) >= 0 &&
            c.dateKey.compareTo(weekEndKey) <= 0)
        .toList();

    QuestView mk(QuestTemplate t, String key, int progress, {int? target}) =>
        QuestView(
          template: t,
          key: key,
          progress: progress,
          target: target ?? t.target,
          claimed: s.claimedQuests.contains(key),
        );

    switch (type) {
      case QuestType.daily:
        String kd(QuestTemplate t) => 'daily:$today:${t.id}';
        final hardIds = {
          for (final h in s.habits)
            if (h.difficulty == Difficulty.hard ||
                h.difficulty == Difficulty.epic)
              h.id
        };
        final due = s.habits.where((h) => !h.archived && h.isDueOn(now)).length;
        final list = [
          mk(dailyThree, kd(dailyThree), todays.length),
          mk(dailyHard, kd(dailyHard),
              todays.where((c) => hardIds.contains(c.habitId)).length),
          mk(dailyAll, kd(dailyAll), GameEngine.completedToday(s, now),
              target: max(1, due)),
        ];
        final claimedCount = list.where((v) => v.claimed).length;
        return [
          ...list,
          mk(dailyBonus, kd(dailyBonus), claimedCount),
        ];
      case QuestType.weekly:
        String kw(QuestTemplate t) => 'weekly:$weekStartKey:${t.id}';
        return [
          mk(weeklyDays, kw(weeklyDays), {for (final c in week) c.dateKey}.length),
          mk(weeklyCount, kw(weeklyCount), week.length),
        ];
      case QuestType.special:
        final perHabit = <String, int>{};
        for (final c in s.completions) {
          perHabit[c.habitId] = (perHabit[c.habitId] ?? 0) + 1;
        }
        final best = perHabit.values.fold<int>(0, max);
        final streak = max(s.streak.longest, GameEngine.currentStreak(s, now));
        return [
          mk(special7, 'special:${special7.id}', streak),
          mk(special30, 'special:${special30.id}', streak),
          mk(special100, 'special:${special100.id}', best),
        ];
    }
  }

  static List<QuestView> all(GameState s, DateTime now) => [
        for (final t in QuestType.values) ...views(s, now, type: t),
      ];

  /// Claims the quest identified by [key] and pays its rewards.
  static ClaimOutcome claim(GameState s, String key, DateTime now) {
    final view = all(s, now).where((v) => v.key == key).firstOrNull;
    if (view == null) return ClaimOutcome(s, ClaimStatus.notFound);
    if (view.claimed) return ClaimOutcome(s, ClaimStatus.alreadyClaimed);
    if (!view.complete) return ClaimOutcome(s, ClaimStatus.notReady);

    final t = view.template;
    var next = s.copyWith(
      gold: s.gold + t.gold,
      gems: s.gems + t.gems,
      chests: t.chest == null ? s.chests : [...s.chests, t.chest!],
      claimedQuests: {...s.claimedQuests, key},
    );
    var events = <GameEvent>[];
    if (t.xp > 0) {
      final (g, e) = GameEngine.grantXp(next, t.xp);
      next = g;
      events = e;
    }
    return ClaimOutcome(next, ClaimStatus.ok, events: events);
  }
}
