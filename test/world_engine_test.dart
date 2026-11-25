import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/game_engine.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/task_engine.dart';
import 'package:life_kingdom/core/game/world_engine.dart';

DateTime day(int d, [int h = 10]) => DateTime(2026, 1, d, h); // Jan 5 = Monday

GameState withHabit() => const GameState(habits: [
      Habit(id: 'h', title: 'Read', difficulty: Difficulty.hard),
    ]);

GameState doHabit(GameState s, DateTime now) {
  final o = GameEngine.complete(s, 'h', now);
  expect(o.ok, isTrue);
  return WorldEngine.settle(
      WorldEngine.onWork(o.state, Difficulty.hard, now), now);
}

void main() {
  test('work gives supplies (capped per day) and fills the mine', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    s = doHabit(s, day(5));
    expect(s.world.supplies, WorldConfig.supplies[Difficulty.hard]);
    expect(s.world.pendingHarvest, WorldEngine.mineYield(s));
    for (var i = 0; i < 20; i++) {
      s = WorldEngine.onWork(s, Difficulty.epic, day(5));
    }
    expect(s.world.suppliesToday, WorldConfig.dailySupplyCap);
    final (collected, g) = WorldEngine.collectHarvest(s);
    expect(g, greaterThan(0));
    expect(collected.world.pendingHarvest, 0);
    expect(collected.gold, s.gold + g);
  });

  test('tasks count toward the streak', () {
    var s = const GameState(tasks: [TaskItem(id: 't', title: 'x')]);
    s = TaskEngine.complete(s, 't', day(5)).state;
    expect(GameEngine.currentStreak(s, day(5)), 1);
  });

  test('7 kept days earn a fortification; rest day keeps the streak', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    for (var d = 5; d <= 11; d++) {
      s = doHabit(s, day(d));
    }
    expect(s.streak.freezesHeld, 1);

    // Day 12: rest instead of work.
    s = WorldEngine.settle(s, day(12));
    final (rested, st) = WorldEngine.declareRest(s, day(12));
    expect(st, RestStatus.ok);
    expect(rested.streak.freezesHeld, 0);
    expect(GameEngine.currentStreak(rested, day(13)), 8);
  });

  test('rest is refused without fortifications or after work', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    expect(WorldEngine.declareRest(s, day(5)).$2, RestStatus.noFortification);
    s = s.copyWith(streak: s.streak.copyWith(freezesHeld: 1));
    s = doHabit(s, day(5));
    expect(WorldEngine.declareRest(s, day(5)).$2, RestStatus.alreadyCounted);
  });

  test('fortifications are not spent automatically by default', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    s = doHabit(s, day(5)).copyWith(
        streak: const StreakState(freezesHeld: 2));
    s = GameEngine.rollover(s, day(8));
    expect(s.streak.freezesHeld, 2);
  });

  test('a missed day lets a goblin take part of the uncollected harvest', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    s = doHabit(s, day(5));
    for (var i = 0; i < 10; i++) {
      s = WorldEngine.onWork(s, Difficulty.medium, day(5));
    }
    final before = s.world.pendingHarvest;
    expect(before, greaterThan(20));
    s = WorldEngine.settle(s, day(7)); // day 6 missed
    expect(s.world.goblinLoot, before * WorldConfig.goblinHarvestPct ~/ 100);
    expect(s.world.pendingHarvest, before - s.world.goblinLoot);

    // Chasing needs work today.
    expect(WorldEngine.canChaseGoblin(s, day(7)), isFalse);
    s = doHabit(s, day(7));
    final loot = s.world.goblinLoot;
    final (after, back) = WorldEngine.chaseGoblin(s, day(7));
    expect(back, loot * WorldConfig.goblinWinBackPct ~/ 100);
    expect(after.world.goblinLoot, 0);
  });

  test('daily chest pays yesterday once', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    s = doHabit(s, day(5));
    expect(WorldEngine.pendingChest(s, day(5)), isNull);
    expect(WorldEngine.chestFrame(s, day(5)), 3);
    final c = WorldEngine.pendingChest(s, day(6));
    expect(c, isNotNull);
    final (claimed, got) = WorldEngine.claimChest(s, day(6));
    expect(got!.gold, c!.gold);
    expect(WorldEngine.pendingChest(claimed, day(6)), isNull);
  });

  test('weekly report for last week, claimable once; record tower', () {
    var s = WorldEngine.settle(withHabit(), day(5));
    for (var d = 5; d <= 9; d++) {
      s = doHabit(s, day(d));
    }
    expect(s.world.bestWeek, 15);
    expect(WorldEngine.towerLevel(s.world.bestWeek), 1);
    s = WorldEngine.settle(s, day(12)); // next Monday
    final r = WorldEngine.pendingReport(s, day(12));
    expect(r!.score, 15);
    expect(r.activeDays, 5);
    expect(r.tier, 1);
    final (claimed, _) = WorldEngine.claimReport(s, day(12));
    expect(WorldEngine.pendingReport(claimed, day(12)), isNull);
    expect(claimed.gold, s.gold + r.reward.gold);
  });

  test('world radius grows with level and stays bounded', () {
    expect(WorldEngine.worldRadius(1), 2);
    expect(WorldEngine.worldRadius(10), 7);
    expect(WorldEngine.worldRadius(100), 15);
    expect(WorldEngine.worldRadius(30), greaterThan(WorldEngine.worldRadius(25)));
    expect(WorldEngine.levelForRadius(7), 10);
  });

  test('main task gives a foundation stone', () {
    var s = const GameState(tasks: [TaskItem(id: 't', title: 'x')]);
    s = WorldEngine.setMainTask(s, 't', day(5));
    s = WorldEngine.onWork(s, Difficulty.medium, day(5), taskId: 't');
    expect(s.world.stones, 1);
    expect(s.world.mainTaskId, isNull);
  });

  test('v1 saves load and v2 round-trips the world', () {
    final v1 = const GameState().toJson()
      ..['schemaVersion'] = 1
      ..remove('world');
    expect(GameState.fromJson(v1).world.supplies, 0);
    final s = const GameState()
        .copyWith(world: const WorldState(supplies: 9, stones: 2));
    final back = GameState.fromJson(s.toJson());
    expect(back.world.supplies, 9);
    expect(back.world.stones, 2);
  });
}
