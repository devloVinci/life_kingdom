import 'dart:math';

import 'game_config.dart';
import 'models.dart';
import 'xp_curve.dart';

sealed class GameEvent {
  const GameEvent();
}

class LevelUp extends GameEvent {
  const LevelUp(this.level);
  final int level;
}

class RankUp extends GameEvent {
  const RankUp(this.rank);
  final String rank;
}

class StreakMilestone extends GameEvent {
  const StreakMilestone(this.days);
  final int days;
}

enum CompletionStatus {
  done,
  alreadyCompleted,
  notDue,
  notFound,
  archived,
  notCompleted,
}

class CompletionOutcome {
  const CompletionOutcome(
    this.state,
    this.status, {
    this.events = const [],
    this.xpGained = 0,
    this.goldGained = 0,
  });

  final GameState state;
  final CompletionStatus status;
  final List<GameEvent> events;

  /// XP/gold from the habit itself (excluding level/streak bonuses).
  final int xpGained;
  final int goldGained;

  bool get ok => status == CompletionStatus.done;
}

class HabitLimitException implements Exception {
  @override
  String toString() =>
      'Maximum of ${GameConfig.maxActiveHabits} active habits reached';
}

/// Pure game logic: no I/O, no Flutter. Every method returns a new state.
class GameEngine {
  GameEngine._();

  // ---- Streak (derived from completions + freeze dates) ----

  static Set<String> countedDates(GameState s) => {
        for (final c in s.completions) c.dateKey,
        ...s.streak.freezeDates,
      };

  static int _runEndingAt(Set<String> counted, DateTime end) {
    var n = 0;
    var d = dayStart(end);
    while (counted.contains(dateKeyOf(d))) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  /// Current streak: run ending today, or ending yesterday if today is
  /// not yet counted (the streak is still alive until the day ends).
  static int currentStreak(GameState s, DateTime now) {
    final counted = countedDates(s);
    final today = dayStart(now);
    if (counted.contains(dateKeyOf(today))) {
      return _runEndingAt(counted, today);
    }
    return _runEndingAt(counted, addDays(today, -1));
  }

  /// Applies streak freezes to missed days. Call whenever the app opens
  /// and before every completion.
  static GameState rollover(GameState s, DateTime now) {
    final counted = countedDates(s);
    if (counted.isEmpty) return s;
    final today = dayStart(now);
    final last = parseKey(counted.reduce((a, b) => a.compareTo(b) >= 0 ? a : b));
    var freezes = s.streak.freezesHeld;
    final used = <String>{};
    var d = addDays(last, 1);
    while (d.isBefore(today)) {
      final run = _runEndingAt({...counted, ...used}, addDays(d, -1));
      if (run > 0 && freezes > 0) {
        used.add(dateKeyOf(d));
        freezes--;
        d = addDays(d, 1);
      } else {
        break;
      }
    }
    if (used.isEmpty) return s;
    return s.copyWith(
      streak: s.streak.copyWith(
        freezesHeld: freezes,
        freezeDates: {...s.streak.freezeDates, ...used},
      ),
    );
  }

  static DateTime parseKey(String k) {
    final p = k.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  /// Buys one streak freeze. Returns null if unaffordable or at the cap.
  static GameState? buyFreeze(GameState s) {
    if (s.gold < GameConfig.freezeCost) return null;
    if (s.streak.freezesHeld >= GameConfig.maxFreezes) return null;
    return s.copyWith(
      gold: s.gold - GameConfig.freezeCost,
      streak: s.streak.copyWith(freezesHeld: s.streak.freezesHeld + 1),
    );
  }

  // ---- Habits CRUD ----

  static GameState addHabit(GameState s, Habit h) {
    final active = s.habits.where((x) => !x.archived).length;
    if (active >= GameConfig.maxActiveHabits) throw HabitLimitException();
    return s.copyWith(habits: [...s.habits, h]);
  }

  static GameState updateHabit(GameState s, Habit h) => s.copyWith(
        habits: [for (final x in s.habits) x.id == h.id ? h : x],
      );

  /// Deletes the habit; its past completions (history) are kept.
  static GameState deleteHabit(GameState s, String id) =>
      s.copyWith(habits: s.habits.where((x) => x.id != id).toList());

  /// Adds [xp] and pays level-up / rank-up rewards (gold, gems, chests,
  /// titles). Used by habits and quest claims.
  static (GameState, List<GameEvent>) grantXp(GameState s, int xp) {
    final totalXp = s.totalXp + xp;
    var gold = s.gold;
    var gems = s.gems;
    final chests = [...s.chests];
    final owned = {...s.owned};
    final events = <GameEvent>[];
    final oldLevel = XpCurve.levelForXp(s.totalXp);
    final newLevel = XpCurve.levelForXp(totalXp);
    for (var l = oldLevel + 1; l <= newLevel; l++) {
      events.add(LevelUp(l));
      gold += GameConfig.levelUpGoldPerLevel * l;
      if (l % GameConfig.levelUpGemsEvery == 0) gems += GameConfig.levelUpGems;
      for (final r in GameConfig.ranks.where((r) => r.fromLevel == l)) {
        if (r.fromLevel > 1) {
          events.add(RankUp(r.name));
          gems += r.reward.gems;
          gold += r.reward.gold;
          if (r.reward.chest != null) chests.add(r.reward.chest!);
          final t = GameConfig.rankTitles[r.name];
          if (t != null) owned.add(t);
        }
      }
    }
    return (
      s.copyWith(
          totalXp: totalXp, gold: gold, gems: gems, chests: chests, owned: owned),
      events
    );
  }

  // ---- Completing and undoing ----

  static CompletionOutcome complete(
      GameState input, String habitId, DateTime now) {
    final s = rollover(input, now);
    final idx = s.habits.indexWhere((h) => h.id == habitId);
    if (idx < 0) return CompletionOutcome(s, CompletionStatus.notFound);
    final habit = s.habits[idx];
    if (habit.archived) return CompletionOutcome(s, CompletionStatus.archived);
    if (!habit.isDueOn(now)) return CompletionOutcome(s, CompletionStatus.notDue);

    final key = dateKeyOf(now);
    if (s.completions.any((c) => c.habitId == habitId && c.dateKey == key)) {
      return CompletionOutcome(s, CompletionStatus.alreadyCompleted);
    }

    final counted = countedDates(s);
    final wasCountedToday = counted.contains(key);
    final streakBefore = _runEndingAt(counted, addDays(dayStart(now), -1));
    final bonusPct = min(
      streakBefore ~/ 7 * GameConfig.streakBonusPercentPerWeek,
      GameConfig.streakBonusCapPercent,
    );

    final baseXp = GameConfig.habitXp[habit.difficulty]!;
    final xp = (baseXp * (100 + bonusPct) + 50) ~/ 100;
    final baseGold = GameConfig.habitGold[habit.difficulty]!;
    final treasuryPct = (s.buildingLevel('treasury') - 1) * 2;
    final gold = (baseGold * (100 + treasuryPct) + 50) ~/ 100;

    final (gs, levelEvents) = grantXp(s.copyWith(gold: s.gold + gold), xp);
    var goldTotal = gs.gold;
    var gems = gs.gems;
    final chests = [...gs.chests];
    final owned = {...gs.owned};
    final events = <GameEvent>[...levelEvents];

    // Streak milestone.
    var streak = s.streak;
    final current = _runEndingAt({...counted, key}, dayStart(now));
    if (!wasCountedToday) {
      final m = GameConfig.streakMilestones[current];
      if (m != null && !streak.milestonesClaimed.contains(current)) {
        events.add(StreakMilestone(current));
        goldTotal += m.gold;
        gems += m.gems;
        if (m.chest != null) chests.add(m.chest!);
        final t = GameConfig.milestoneTitles[current];
        if (t != null) owned.add(t);
        streak = streak.copyWith(
            milestonesClaimed: {...streak.milestonesClaimed, current});
      }
    }
    streak = streak.copyWith(longest: max(streak.longest, current));

    final next = s.copyWith(
      totalXp: gs.totalXp,
      gold: goldTotal,
      gems: gems,
      chests: chests,
      owned: owned,
      streak: streak,
      completions: [
        ...s.completions,
        Completion(habitId: habitId, dateKey: key, xp: xp, gold: gold),
      ],
    );
    return CompletionOutcome(next, CompletionStatus.done,
        events: events, xpGained: xp, goldGained: gold);
  }

  /// Reverses today's completion of [habitId]. Level-up/milestone rewards
  /// already granted stay; XP never drops below the current level's start.
  static CompletionOutcome undo(GameState s, String habitId, DateTime now) {
    final key = dateKeyOf(now);
    final i = s.completions
        .indexWhere((c) => c.habitId == habitId && c.dateKey == key);
    if (i < 0) return CompletionOutcome(s, CompletionStatus.notCompleted);
    final c = s.completions[i];
    final floorXp = XpCurve.xpForLevel(XpCurve.levelForXp(s.totalXp));
    final next = s.copyWith(
      totalXp: max(floorXp, s.totalXp - c.xp),
      gold: max(0, s.gold - c.gold),
      completions: [...s.completions]..removeAt(i),
    );
    return CompletionOutcome(next, CompletionStatus.done);
  }

  // ---- Convenience reads ----

  static int level(GameState s) => XpCurve.levelForXp(s.totalXp);
  static RankInfo rank(GameState s) => XpCurve.rankForLevel(level(s));

  static int completedToday(GameState s, DateTime now) {
    final key = dateKeyOf(now);
    final dueIds = s.habits
        .where((h) => !h.archived && h.isDueOn(now))
        .map((h) => h.id)
        .toSet();
    return s.completions
        .where((c) => c.dateKey == key && dueIds.contains(c.habitId))
        .length;
  }
}
