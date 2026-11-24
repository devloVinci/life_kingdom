import 'dart:math';

import 'models.dart';
import 'xp_curve.dart';

class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.check,
    this.gold = 0,
    this.gems = 0,
  });

  final String id;
  final String title;
  final String description;
  final bool Function(GameState s) check;
  final int gold, gems;
}

int _maxPerHabit(GameState s) {
  final m = <String, int>{};
  for (final c in s.completions) {
    m[c.habitId] = (m[c.habitId] ?? 0) + 1;
  }
  return m.values.fold<int>(0, max);
}

final List<AchievementDef> achievementDefs = [
  AchievementDef(id: 'first_habit', title: 'First Step', description: 'Complete your first habit', gold: 25, check: (s) => s.completions.isNotEmpty),
  AchievementDef(id: 'habits_10', title: 'Getting Going', description: 'Complete 10 habits', gold: 50, check: (s) => s.completions.length >= 10),
  AchievementDef(id: 'habits_50', title: 'On a Roll', description: 'Complete 50 habits', gold: 100, check: (s) => s.completions.length >= 50),
  AchievementDef(id: 'habits_100', title: 'Century', description: 'Complete 100 habits', gold: 200, gems: 2, check: (s) => s.completions.length >= 100),
  AchievementDef(id: 'habits_500', title: 'Habit Hero', description: 'Complete 500 habits', gold: 500, gems: 10, check: (s) => s.completions.length >= 500),
  AchievementDef(id: 'streak_7', title: 'Week Warrior', description: 'Reach a 7-day streak', gold: 100, check: (s) => s.streak.longest >= 7),
  AchievementDef(id: 'streak_30', title: 'Month Master', description: 'Reach a 30-day streak', gold: 300, gems: 5, check: (s) => s.streak.longest >= 30),
  AchievementDef(id: 'streak_100', title: 'Unbreakable', description: 'Reach a 100-day streak', gold: 1000, gems: 25, check: (s) => s.streak.longest >= 100),
  AchievementDef(id: 'level_5', title: 'Apprentice', description: 'Reach level 5', gold: 50, check: (s) => XpCurve.levelForXp(s.totalXp) >= 5),
  AchievementDef(id: 'level_10', title: 'Squire', description: 'Reach level 10', gold: 100, gems: 2, check: (s) => XpCurve.levelForXp(s.totalXp) >= 10),
  AchievementDef(id: 'level_25', title: 'Knight', description: 'Reach level 25', gold: 250, gems: 5, check: (s) => XpCurve.levelForXp(s.totalXp) >= 25),
  AchievementDef(id: 'level_50', title: 'Champion', description: 'Reach level 50', gold: 500, gems: 10, check: (s) => XpCurve.levelForXp(s.totalXp) >= 50),
  AchievementDef(id: 'one_habit_30', title: 'Dedicated', description: 'Complete the same habit 30 times', gold: 150, check: (s) => _maxPerHabit(s) >= 30),
  AchievementDef(id: 'collector_5', title: 'Collector', description: 'Own 5 heroes', gold: 100, gems: 2, check: (s) => s.owned.where((o) => o.startsWith('char_')).length >= 5),
  AchievementDef(id: 'builder_first', title: 'Master Builder', description: 'Finish your first building upgrade', gold: 75, check: (s) => s.buildings.values.any((b) => b.level >= 2)),
  AchievementDef(id: 'quest_first', title: 'Quest Taker', description: 'Claim your first quest', gold: 50, check: (s) => s.claimedQuests.isNotEmpty),
];

class AchievementResult {
  const AchievementResult(this.state, this.unlocked);
  final GameState state;
  final List<AchievementDef> unlocked;
}

class AchievementEngine {
  AchievementEngine._();

  /// Unlocks every achievement whose condition is met and pays its reward.
  /// Unlocked achievements are kept even if the condition later stops
  /// being true (history is never lost).
  static AchievementResult evaluate(GameState s, DateTime now) {
    final unlocked = <AchievementDef>[];
    var gold = s.gold;
    var gems = s.gems;
    final map = {...s.achievements};
    for (final a in achievementDefs) {
      if (map.containsKey(a.id) || !a.check(s)) continue;
      map[a.id] = dateKeyOf(now);
      gold += a.gold;
      gems += a.gems;
      unlocked.add(a);
    }
    if (unlocked.isEmpty) return AchievementResult(s, const []);
    return AchievementResult(
        s.copyWith(gold: gold, gems: gems, achievements: map), unlocked);
  }

  static int get total => achievementDefs.length;
}
