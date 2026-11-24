import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/game_config.dart';
import 'package:life_kingdom/core/game/game_engine.dart';
import 'package:life_kingdom/core/game/models.dart';

GameState withHabit({Set<int>? weekdays, Difficulty d = Difficulty.medium}) {
  return GameEngine.addHabit(
    const GameState(),
    Habit(
      id: 'h1',
      title: 'Read',
      difficulty: d,
      weekdays: weekdays ?? const {1, 2, 3, 4, 5, 6, 7},
    ),
  );
}

// 2026-01-01 is a Thursday.
DateTime day(int n) => DateTime(2026, 1, n, 9);

void main() {
  test('first completion pays xp, gold and level-up bonus', () {
    final o = GameEngine.complete(withHabit(), 'h1', day(1));
    expect(o.ok, isTrue);
    expect(o.xpGained, 20);
    expect(o.goldGained, 10);
    expect(o.state.totalXp, 20);
    expect(GameEngine.level(o.state), 2);
    expect(o.state.gold, 10 + 20); // habit + level 2 reward (10 * 2)
    expect(o.events.whereType<LevelUp>().single.level, 2);
  });

  test('same habit cannot be paid twice in one day', () {
    final first = GameEngine.complete(withHabit(), 'h1', day(1));
    final again = GameEngine.complete(first.state, 'h1', day(1));
    expect(again.status, CompletionStatus.alreadyCompleted);
    expect(again.state.totalXp, first.state.totalXp);
    expect(again.state.gold, first.state.gold);
  });

  test('habit not due today is rejected', () {
    final s = withHabit(weekdays: {DateTime.monday});
    final o = GameEngine.complete(s, 'h1', DateTime(2026, 1, 6)); // Tuesday
    expect(o.status, CompletionStatus.notDue);
    expect(o.state.totalXp, 0);
    final ok = GameEngine.complete(s, 'h1', DateTime(2026, 1, 5)); // Monday
    expect(ok.ok, isTrue);
  });

  test('unknown habit', () {
    expect(GameEngine.complete(const GameState(), 'x', day(1)).status,
        CompletionStatus.notFound);
  });

  test('undo reverses rewards but never drops below level start', () {
    final done = GameEngine.complete(withHabit(), 'h1', day(1));
    final undone = GameEngine.undo(done.state, 'h1', day(1));
    expect(undone.ok, isTrue);
    expect(undone.state.completions, isEmpty);
    // XP 20 is exactly the start of level 2, so it stays at 20.
    expect(undone.state.totalXp, 20);
    expect(undone.state.gold, 20); // 30 - 10 (level reward stays)
    // Can be completed again afterwards.
    expect(GameEngine.complete(undone.state, 'h1', day(1)).ok, isTrue);
  });

  test('undo without completion', () {
    expect(GameEngine.undo(withHabit(), 'h1', day(1)).status,
        CompletionStatus.notCompleted);
  });

  test('streak, 7-day milestone and later xp bonus', () {
    var s = withHabit();
    CompletionOutcome? last;
    for (var d = 1; d <= 7; d++) {
      last = GameEngine.complete(s, 'h1', day(d));
      s = last.state;
    }
    expect(GameEngine.currentStreak(s, day(7)), 7);
    expect(last!.events.whereType<StreakMilestone>().single.days, 7);
    expect(s.gems, 2); // milestone gems only (level 4 at 140 XP)
    expect(s.streak.longest, 7);

    final day8 = GameEngine.complete(s, 'h1', day(8));
    expect(day8.xpGained, 21); // 20 * 1.05
    expect(day8.events.whereType<StreakMilestone>(), isEmpty);
  });

  test('missing a day resets the streak', () {
    var s = withHabit();
    s = GameEngine.complete(s, 'h1', day(1)).state;
    s = GameEngine.complete(s, 'h1', day(2)).state;
    expect(GameEngine.currentStreak(s, day(2)), 2);
    expect(GameEngine.currentStreak(s, day(3)), 2); // still alive today
    expect(GameEngine.currentStreak(s, day(4)), 0); // day 3 missed
    s = GameEngine.complete(s, 'h1', day(4)).state;
    expect(GameEngine.currentStreak(s, day(4)), 1);
    expect(s.streak.longest, 2); // longest preserved
  });

  test('streak freeze covers one missed day', () {
    var s = withHabit();
    s = GameEngine.complete(s, 'h1', day(1)).state;
    s = s.copyWith(gold: 200);
    s = GameEngine.buyFreeze(s)!;
    expect(s.streak.freezesHeld, 1);
    expect(s.gold, 50);
    // Day 2 missed, complete on day 3.
    s = GameEngine.complete(s, 'h1', day(3)).state;
    expect(s.streak.freezesHeld, 0);
    expect(GameEngine.currentStreak(s, day(3)), 3);
  });

  test('freeze purchase limits', () {
    var s = const GameState(gold: 1000);
    s = GameEngine.buyFreeze(s)!;
    s = GameEngine.buyFreeze(s)!;
    expect(GameEngine.buyFreeze(s), isNull); // cap of 2
    expect(GameEngine.buyFreeze(const GameState(gold: 10)), isNull);
  });

  test('reaching level 10 gives rank D rewards', () {
    final s = withHabit().copyWith(totalXp: 1275); // level 9, 10 XP short
    final o = GameEngine.complete(s, 'h1', day(1)); // +20 XP -> 1295
    expect(GameEngine.level(o.state), 10);
    expect(o.events.whereType<RankUp>().single.rank, 'D');
    expect(o.state.gems, 25 + 5); // rank reward + every-5th-level gems
    expect(o.state.chests, ['wooden']);
    expect(o.state.gold, 10 + 100); // habit + level reward 10 * 10
  });

  test('active habit limit', () {
    var s = const GameState();
    for (var i = 0; i < GameConfig.maxActiveHabits; i++) {
      s = GameEngine.addHabit(s, Habit(id: 'h$i', title: 'x'));
    }
    expect(() => GameEngine.addHabit(s, const Habit(id: 'z', title: 'z')),
        throwsA(isA<HabitLimitException>()));
  });

  test('deleting a habit keeps its history', () {
    final done = GameEngine.complete(withHabit(), 'h1', day(1));
    final del = GameEngine.deleteHabit(done.state, 'h1');
    expect(del.habits, isEmpty);
    expect(del.completions, hasLength(1));
  });

  test('json roundtrip and backup validation', () {
    final done = GameEngine.complete(withHabit(), 'h1', day(1)).state;
    final restored =
        GameState.fromJson(jsonDecode(jsonEncode(done.toJson())));
    expect(restored.totalXp, done.totalXp);
    expect(restored.gold, done.gold);
    expect(restored.habits.single.title, 'Read');
    expect(restored.completions.single.dateKey, '2026-01-01');

    final bad = done.toJson()..['schemaVersion'] = 99;
    expect(() => GameState.fromJson(bad), throwsFormatException);
    expect(() => GameState.fromJson({'schemaVersion': 1}),
        throwsFormatException);
  });
}
