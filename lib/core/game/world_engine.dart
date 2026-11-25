import 'dart:math';

import 'game_engine.dart';
import 'models.dart';

/// Tunable numbers for the open-world layer (see docs/open_world.md).
class WorldConfig {
  WorldConfig._();

  /// Supplies per finished habit/task, capped per day.
  static const supplies = {
    Difficulty.easy: 2,
    Difficulty.medium: 4,
    Difficulty.hard: 7,
    Difficulty.epic: 10,
  };
  static const dailySupplyCap = 40;

  /// Weekly score points (record tower, scout reports).
  static const points = {
    Difficulty.easy: 1,
    Difficulty.medium: 2,
    Difficulty.hard: 3,
    Difficulty.epic: 4,
  };

  /// Best-week score needed for each floor of the record tower (1..8).
  static const towerThresholds = [10, 25, 45, 70, 100, 140, 190, 250];

  /// Fortifications: one per full 7 kept days, at most 3 held.
  static const fortifyEvery = 7;
  static const maxFortifications = 3;
  static const maxRestInARow = 2;

  /// Light penalty for a missed day: a goblin takes part of the gold left
  /// uncollected above the mine and a little supply. Half can be won back.
  static const goblinHarvestPct = 30;
  static const goblinSuppliesPct = 10;
  static const goblinWinBackPct = 50;

  /// Weekly chest tiers by score: wooden, iron, golden, royal.
  static const reportTierScores = [1, 15, 35, 70];
  static const reportRewards = [
    (gold: 60, gems: 0, supplies: 20),
    (gold: 150, gems: 2, supplies: 40),
    (gold: 300, gems: 5, supplies: 80),
    (gold: 600, gems: 10, supplies: 150),
  ];

  /// World radius (tiles) unlocked at a player level; linear between points.
  static const radiusByLevel = [
    (level: 1, radius: 2.0),
    (level: 10, radius: 7.0),
    (level: 25, radius: 10.0),
    (level: 45, radius: 13.0),
    (level: 70, radius: 15.0),
  ];
  static const worldHalfSize = 15;

  /// Regions as rings around the castle: outer edge distance and the level
  /// whose radius first reaches them.
  static const regions = [
    (id: 'grass', name: 'المروج الخضراء', edge: 6),
    (id: 'snow', name: 'الشمال الثلجي', edge: 9),
    (id: 'volcanic', name: 'أرض البراكين', edge: 12),
    (id: 'shadow', name: 'أرض الظلال', edge: 15),
  ];
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekKey,
    required this.score,
    required this.activeDays,
    required this.habitsDone,
    required this.tasksDone,
    required this.tier,
    required this.isRecord,
  });

  final String weekKey;
  final int score;
  final int activeDays;
  final int habitsDone;
  final int tasksDone;

  /// 0 wooden, 1 iron, 2 golden, 3 royal.
  final int tier;
  final bool isRecord;

  ({int gold, int gems, int supplies}) get reward =>
      WorldConfig.reportRewards[tier];
}

class DailyChest {
  const DailyChest(this.dayKey, this.score);
  final String dayKey;
  final int score;

  int get gold => 10 + score * 5;
  int get supplies => score * 2;
  int get gems => score >= 8 ? 1 : 0;
}

enum RestStatus { ok, noFortification, alreadyCounted, tooManyInARow }

/// Pure open-world rules. Every method returns a new state.
class WorldEngine {
  WorldEngine._();

  // ---- Scores ----

  static int _habitPoints(GameState s, String habitId) {
    for (final h in s.habits) {
      if (h.id == habitId) return WorldConfig.points[h.difficulty]!;
    }
    return 1;
  }

  static int dayScore(GameState s, String key) {
    var n = 0;
    for (final c in s.completions) {
      if (c.dateKey == key) n += _habitPoints(s, c.habitId);
    }
    for (final t in s.tasks) {
      if (t.doneKey == key) n += WorldConfig.points[t.difficulty]!;
    }
    return n;
  }

  static DateTime weekStart(DateTime d) =>
      addDays(dayStart(d), -(d.weekday - DateTime.monday));

  static int weekScore(GameState s, DateTime start) {
    var n = 0;
    for (var i = 0; i < 7; i++) {
      n += dayScore(s, dateKeyOf(addDays(start, i)));
    }
    return n;
  }

  static int towerLevel(int best) =>
      WorldConfig.towerThresholds.where((t) => best >= t).length;

  /// Score needed for the next floor, or null at the top.
  static int? nextTowerThreshold(int best) {
    for (final t in WorldConfig.towerThresholds) {
      if (best < t) return t;
    }
    return null;
  }

  static int totalWork(GameState s) =>
      s.completions.length + s.tasks.where((t) => t.done).length;

  /// Gold mine look: 64 stages (4 tiers x 16), grows with lifetime work.
  static int mineStage(GameState s) => min(63, totalWork(s) ~/ 4);
  static int mineTier(GameState s) => mineStage(s) ~/ 16;
  static int mineYield(GameState s) => 3 + mineTier(s) * 2;

  /// Town hall look from player level: 16 wood + 16 stone + 13 dark stages.
  static const townHallStages = 45;
  static int townHallStage(int level) =>
      min(townHallStages - 1, ((level - 1) * townHallStages) ~/ 100);

  static bool workedOn(GameState s, String key) =>
      s.completions.any((c) => c.dateKey == key) ||
      s.tasks.any((t) => t.doneKey == key);

  // ---- World size ----

  static double worldRadius(int level) {
    final pts = WorldConfig.radiusByLevel;
    if (level <= pts.first.level) return pts.first.radius;
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      if (level <= b.level) {
        final t = (level - a.level) / (b.level - a.level);
        return a.radius + (b.radius - a.radius) * t;
      }
    }
    return pts.last.radius;
  }

  /// First level whose radius reaches [distance] tiles.
  static int levelForRadius(double distance) {
    for (var l = 1; l <= 100; l++) {
      if (worldRadius(l) >= distance) return l;
    }
    return 100;
  }

  static int regionIndexAt(double distance) {
    for (var i = 0; i < WorldConfig.regions.length; i++) {
      if (distance <= WorldConfig.regions[i].edge + 0.5) return i;
    }
    return WorldConfig.regions.length - 1;
  }

  // ---- Settling (open app / after every action) ----

  static GameState settle(GameState input, DateTime now) {
    var s = input;
    if (!s.settings.containsKey('auto_fortify')) {
      s = s.copyWith(settings: {...s.settings, 'auto_fortify': false});
    }
    var w = s.world;
    final todayKey = dateKeyOf(now);
    final today = dayStart(now);
    final yesterdayKey = dateKeyOf(addDays(today, -1));

    // Fortifications for every 7th kept day.
    final counted = GameEngine.countedDates(s);
    var held = s.streak.freezesHeld;
    final awards = {...w.fortifyAwardKeys};
    for (var i = 9; i >= 0; i--) {
      final d = addDays(today, -i);
      final k = dateKeyOf(d);
      if (!counted.contains(k) || awards.contains(k)) continue;
      final run = _runEndingAt(counted, d);
      if (run > 0 && run % WorldConfig.fortifyEvery == 0) {
        awards.add(k);
        if (held < WorldConfig.maxFortifications) held++;
      }
    }

    // Missed days: light goblin raid on uncollected harvest.
    if (w.lastSettledKey == null) {
      w = w.copyWith(lastSettledKey: yesterdayKey);
    } else if (w.lastSettledKey!.compareTo(yesterdayKey) < 0) {
      final hasHistory = counted.isNotEmpty;
      var d = addDays(GameEngine.parseKey(w.lastSettledKey!), 1);
      var missed = 0;
      while (!d.isAfter(addDays(today, -1))) {
        if (hasHistory && !counted.contains(dateKeyOf(d))) missed++;
        d = addDays(d, 1);
      }
      if (missed > 0) {
        var harvest = w.pendingHarvest, loot = w.goblinLoot;
        var supplies = w.supplies;
        for (var i = 0; i < min(missed, 3); i++) {
          final take = harvest * WorldConfig.goblinHarvestPct ~/ 100;
          harvest -= take;
          loot += take;
          supplies -= supplies * WorldConfig.goblinSuppliesPct ~/ 100;
        }
        w = w.copyWith(
          pendingHarvest: harvest,
          goblinLoot: loot,
          supplies: supplies,
          goblinDateKey: todayKey,
        );
      }
      w = w.copyWith(lastSettledKey: yesterdayKey);
    }

    // Record week (live for the current week, and last week if missed).
    for (final start in [weekStart(now), addDays(weekStart(now), -7)]) {
      final score = weekScore(s, start);
      if (score > w.bestWeek) {
        w = w.copyWith(bestWeek: score, bestWeekKey: dateKeyOf(start));
      }
    }

    if (w.mainTaskKey != null && w.mainTaskKey != todayKey) {
      w = w.copyWith(clearMainTask: true);
    }

    return s.copyWith(
      world: w.copyWith(fortifyAwardKeys: awards),
      streak: s.streak.copyWith(freezesHeld: held),
    );
  }

  static int _runEndingAt(Set<String> counted, DateTime end) {
    var n = 0;
    var d = end;
    while (counted.contains(dateKeyOf(d))) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  // ---- Work hooks ----

  /// Call after a paid habit/task completion.
  static GameState onWork(GameState s, Difficulty difficulty, DateTime now,
      {String? taskId}) {
    final key = dateKeyOf(now);
    var w = s.world;
    final usedToday = w.suppliesDayKey == key ? w.suppliesToday : 0;
    final add = min(WorldConfig.supplies[difficulty]!,
        max(0, WorldConfig.dailySupplyCap - usedToday));
    w = w.copyWith(
      supplies: w.supplies + add,
      suppliesDayKey: key,
      suppliesToday: usedToday + add,
      pendingHarvest: w.pendingHarvest + mineYield(s),
    );
    if (taskId != null && w.mainTaskId == taskId && w.mainTaskKey == key) {
      w = w.copyWith(stones: w.stones + 1, clearMainTask: true);
    }
    return s.copyWith(world: w);
  }

  /// Call after a habit completion is undone (takes the supplies back).
  static GameState onUndo(GameState s, Difficulty difficulty, DateTime now) {
    final key = dateKeyOf(now);
    final w = s.world;
    final back = WorldConfig.supplies[difficulty]!;
    return s.copyWith(
      world: w.copyWith(
        supplies: max(0, w.supplies - back),
        suppliesToday: w.suppliesDayKey == key
            ? max(0, w.suppliesToday - back)
            : w.suppliesToday,
      ),
    );
  }

  static GameState setMainTask(GameState s, String taskId, DateTime now) =>
      s.copyWith(
        world: s.world.copyWith(mainTaskId: taskId, mainTaskKey: dateKeyOf(now)),
      );

  // ---- Harvest & goblin ----

  static (GameState, int) collectHarvest(GameState s) {
    final g = s.world.pendingHarvest;
    if (g <= 0) return (s, 0);
    return (
      s.copyWith(gold: s.gold + g, world: s.world.copyWith(pendingHarvest: 0)),
      g
    );
  }

  /// The goblin can be chased only on a day with real work done.
  static bool canChaseGoblin(GameState s, DateTime now) =>
      s.world.goblinLoot > 0 && workedOn(s, dateKeyOf(now));

  static (GameState, int) chaseGoblin(GameState s, DateTime now) {
    if (!canChaseGoblin(s, now)) return (s, 0);
    final back = s.world.goblinLoot * WorldConfig.goblinWinBackPct ~/ 100;
    return (
      s.copyWith(gold: s.gold + back, world: s.world.copyWith(goblinLoot: 0)),
      back
    );
  }

  // ---- Daily chest (yesterday's work, claimed in the morning) ----

  static DailyChest? pendingChest(GameState s, DateTime now) {
    final key = dateKeyOf(addDays(dayStart(now), -1));
    if (s.world.chestClaimedKey == key) return null;
    final score = dayScore(s, key);
    if (score <= 0) return null;
    return DailyChest(key, score);
  }

  /// 0..6 while today's work fills it, 7 when yesterday's chest is ready.
  static int chestFrame(GameState s, DateTime now) {
    if (pendingChest(s, now) != null) return 7;
    return min(6, dayScore(s, dateKeyOf(now)));
  }

  static (GameState, DailyChest?) claimChest(GameState s, DateTime now) {
    final c = pendingChest(s, now);
    if (c == null) return (s, null);
    return (
      s.copyWith(
        gold: s.gold + c.gold,
        gems: s.gems + c.gems,
        world: s.world.copyWith(
          supplies: s.world.supplies + c.supplies,
          chestClaimedKey: c.dayKey,
        ),
      ),
      c
    );
  }

  // ---- Weekly scout report ----

  static WeeklyReport reportFor(GameState s, DateTime start) {
    final keys = {for (var i = 0; i < 7; i++) dateKeyOf(addDays(start, i))};
    final habits = s.completions.where((c) => keys.contains(c.dateKey)).length;
    final tasks = s.tasks.where((t) => keys.contains(t.doneKey)).length;
    final active = keys.where((k) => workedOn(s, k)).length;
    final score = weekScore(s, start);
    var tier = 0;
    for (var i = 0; i < WorldConfig.reportTierScores.length; i++) {
      if (score >= WorldConfig.reportTierScores[i]) tier = i;
    }
    final weekKey = dateKeyOf(start);
    return WeeklyReport(
      weekKey: weekKey,
      score: score,
      activeDays: active,
      habitsDone: habits,
      tasksDone: tasks,
      tier: tier,
      isRecord: score > 0 &&
          score >= s.world.bestWeek &&
          s.world.bestWeekKey == weekKey,
    );
  }

  /// Last week's report while it is unclaimed and had any work.
  static WeeklyReport? pendingReport(GameState s, DateTime now) {
    final start = addDays(weekStart(now), -7);
    if (s.world.reportsClaimed.contains(dateKeyOf(start))) return null;
    final r = reportFor(s, start);
    return r.score > 0 ? r : null;
  }

  static (GameState, WeeklyReport?) claimReport(GameState s, DateTime now) {
    final r = pendingReport(s, now);
    if (r == null) return (s, null);
    final g = r.reward;
    return (
      s.copyWith(
        gold: s.gold + g.gold,
        gems: s.gems + g.gems,
        world: s.world.copyWith(
          supplies: s.world.supplies + g.supplies,
          reportsClaimed: {...s.world.reportsClaimed, r.weekKey},
        ),
      ),
      r
    );
  }

  // ---- Fortifications / rest days ----

  /// Days kept toward the next fortification (0..6).
  static int fortifyProgress(GameState s, DateTime now) =>
      GameEngine.currentStreak(s, now) % WorldConfig.fortifyEvery;

  static (GameState, RestStatus) declareRest(GameState s, DateTime now) {
    final today = dayStart(now);
    final key = dateKeyOf(today);
    if (s.streak.freezesHeld <= 0) return (s, RestStatus.noFortification);
    if (GameEngine.countedDates(s).contains(key)) {
      return (s, RestStatus.alreadyCounted);
    }
    var inARow = 0;
    for (var i = 1; i <= WorldConfig.maxRestInARow; i++) {
      if (s.streak.freezeDates.contains(dateKeyOf(addDays(today, -i)))) {
        inARow++;
      }
    }
    if (inARow >= WorldConfig.maxRestInARow) {
      return (s, RestStatus.tooManyInARow);
    }
    return (
      s.copyWith(
        streak: s.streak.copyWith(
          freezesHeld: s.streak.freezesHeld - 1,
          freezeDates: {...s.streak.freezeDates, key},
        ),
      ),
      RestStatus.ok
    );
  }

  static bool isRestDay(GameState s, DateTime now) =>
      s.streak.freezeDates.contains(dateKeyOf(now));
}
