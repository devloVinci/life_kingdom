import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/achievement_engine.dart';
import 'package:life_kingdom/core/game/game_config.dart';
import 'package:life_kingdom/core/game/game_engine.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/quest_engine.dart';

DateTime day(int n) => DateTime(2026, 1, n, 9); // 2026-01-01 is a Thursday

GameState threeHabits() {
  var s = const GameState();
  s = GameEngine.addHabit(s, const Habit(id: 'h1', title: 'Read'));
  s = GameEngine.addHabit(s,
      const Habit(id: 'h2', title: 'Run', difficulty: Difficulty.hard));
  s = GameEngine.addHabit(s,
      const Habit(id: 'h3', title: 'Water', difficulty: Difficulty.easy));
  return s;
}

GameState completeAll(GameState s, DateTime now) {
  for (final id in ['h1', 'h2', 'h3']) {
    s = GameEngine.complete(s, id, now).state;
  }
  return s;
}

QuestView find(GameState s, DateTime now, String templateId) =>
    QuestEngine.all(s, now).firstWhere((v) => v.template.id == templateId);

void main() {
  test('daily progress is derived from completions', () {
    var s = threeHabits();
    expect(find(s, day(1), 'd_three').progress, 0);
    s = completeAll(s, day(1));
    expect(find(s, day(1), 'd_three').progress, 3);
    expect(find(s, day(1), 'd_hard').progress, 1);
    final all = find(s, day(1), 'd_all');
    expect(all.target, 3);
    expect(all.progress, 3);
    expect(all.claimable, isTrue);
  });

  test('claim pays rewards once', () {
    var s = completeAll(threeHabits(), day(1));
    final v = find(s, day(1), 'd_three');
    final goldBefore = s.gold;
    final xpBefore = s.totalXp;
    final o = QuestEngine.claim(s, v.key, day(1));
    expect(o.ok, isTrue);
    expect(o.state.gold, goldBefore + 30);
    expect(o.state.totalXp, xpBefore + 40);
    final again = QuestEngine.claim(o.state, v.key, day(1));
    expect(again.status, ClaimStatus.alreadyClaimed);
    expect(again.state.gold, o.state.gold);
  });

  test('claim rejects unfinished and unknown quests', () {
    final s = threeHabits();
    final v = find(s, day(1), 'd_three');
    expect(QuestEngine.claim(s, v.key, day(1)).status, ClaimStatus.notReady);
    expect(QuestEngine.claim(s, 'nope', day(1)).status, ClaimStatus.notFound);
  });

  test('daily bonus chest after claiming all three dailies', () {
    var s = completeAll(threeHabits(), day(1));
    expect(find(s, day(1), 'bonus').claimable, isFalse);
    for (final id in ['d_three', 'd_hard', 'd_all']) {
      s = QuestEngine.claim(s, find(s, day(1), id).key, day(1)).state;
    }
    final bonus = find(s, day(1), 'bonus');
    expect(bonus.progress, 3);
    expect(bonus.claimable, isTrue);
    s = QuestEngine.claim(s, bonus.key, day(1)).state;
    expect(s.chests, ['wooden']);
  });

  test('daily quests renew the next day', () {
    var s = completeAll(threeHabits(), day(1));
    s = QuestEngine.claim(s, find(s, day(1), 'd_three').key, day(1)).state;
    final next = find(s, day(2), 'd_three');
    expect(next.progress, 0);
    expect(next.claimed, isFalse);
  });

  test('weekly quest counts distinct active days in the week', () {
    var s = GameEngine.addHabit(
        const GameState(), const Habit(id: 'h1', title: 'Read'));
    // Week of Mon 2025-12-29 .. Sun 2026-01-04: five active days.
    final days = [
      DateTime(2025, 12, 30, 9),
      DateTime(2025, 12, 31, 9),
      DateTime(2026, 1, 1, 9),
      DateTime(2026, 1, 2, 9),
      DateTime(2026, 1, 3, 9),
    ];
    for (final d in days) {
      s = GameEngine.complete(s, 'h1', d).state;
    }
    final now = days.last;
    final w = find(s, now, 'w_days');
    expect(w.progress, 5);
    expect(w.claimable, isTrue);
    expect(find(s, now, 'w_count').progress, 5);
    final before = s;
    final o = QuestEngine.claim(s, w.key, now);
    expect(o.ok, isTrue);
    expect(o.state.gold - before.gold, greaterThanOrEqualTo(150));
    expect(o.state.gems - before.gems, greaterThanOrEqualTo(5));
    // Next week starts fresh.
    expect(find(o.state, DateTime(2026, 1, 5, 9), 'w_days').progress, 0);
  });

  test('special streak quest pays a chest and stays claimed', () {
    var s = GameEngine.addHabit(
        const GameState(), const Habit(id: 'h1', title: 'Read'));
    for (var d = 1; d <= 7; d++) {
      s = GameEngine.complete(s, 'h1', day(d)).state;
    }
    final v = find(s, day(7), 's_streak7');
    expect(v.claimable, isTrue);
    final o = QuestEngine.claim(s, v.key, day(7));
    expect(o.state.chests, ['wooden']);
    expect(find(o.state, day(20), 's_streak7').claimed, isTrue);
  });

  test('daily all-habits quest with no habits is never claimable', () {
    final v = find(const GameState(), day(1), 'd_all');
    expect(v.target, 1);
    expect(v.claimable, isFalse);
  });

  test('quest claim fields survive json', () {
    final s = const GameState(
        claimedQuests: {'daily:2026-01-01:d_three'},
        achievements: {'first_habit': '2026-01-01'},
        settings: {'notif_level_up': false});
    final r = GameState.fromJson(s.toJson());
    expect(r.claimedQuests, s.claimedQuests);
    expect(r.achievements['first_habit'], '2026-01-01');
    expect(r.setting('notif_level_up'), isFalse);
    expect(r.setting('notif_app_open'), isTrue); // default
  });

  group('achievements', () {
    test('first habit unlocks once and pays its reward', () {
      var s = GameEngine.addHabit(
          const GameState(), const Habit(id: 'h1', title: 'Read'));
      expect(AchievementEngine.evaluate(s, day(1)).unlocked, isEmpty);
      s = GameEngine.complete(s, 'h1', day(1)).state;
      final goldBefore = s.gold;
      final r = AchievementEngine.evaluate(s, day(1));
      expect(r.unlocked.map((a) => a.id), contains('first_habit'));
      expect(r.state.gold, greaterThan(goldBefore));
      expect(r.state.achievements['first_habit'], '2026-01-01');
      expect(AchievementEngine.evaluate(r.state, day(1)).unlocked, isEmpty);
    });

    test('unlocked achievements are kept after undo', () {
      var s = GameEngine.addHabit(
          const GameState(), const Habit(id: 'h1', title: 'Read'));
      s = GameEngine.complete(s, 'h1', day(1)).state;
      s = AchievementEngine.evaluate(s, day(1)).state;
      s = GameEngine.undo(s, 'h1', day(1)).state;
      s = AchievementEngine.evaluate(s, day(1)).state;
      expect(s.achievements.containsKey('first_habit'), isTrue);
    });

    test('ids are unique', () {
      final ids = achievementDefs.map((a) => a.id).toSet();
      expect(ids.length, achievementDefs.length);
      expect(GameConfig.maxLevel, 100);
    });
  });
}
