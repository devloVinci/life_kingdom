import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/game_engine.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/task_engine.dart';

void main() {
  final now = DateTime(2026, 1, 5, 10);

  GameState withTasks(int n) => GameState(tasks: [
        for (var i = 0; i < n; i++) TaskItem(id: 't$i', title: 'Task $i'),
      ]);

  test('completing a task pays XP and gold once', () {
    final o = TaskEngine.complete(withTasks(1), 't0', now);
    expect(o.ok, isTrue);
    expect(o.state.totalXp, 20);
    // The task itself pays 10 gold; reaching level 2 adds the level-up bonus.
    expect(o.goldGained, 10);
    expect(o.state.gold, greaterThanOrEqualTo(10));
    expect(o.state.tasks.first.done, isTrue);

    final again = TaskEngine.complete(o.state, 't0', now);
    expect(again.status, CompletionStatus.alreadyCompleted);
    expect(again.state.totalXp, 20);
  });

  test('tasks do not change the habit streak or completions', () {
    final o = TaskEngine.complete(withTasks(1), 't0', now);
    expect(o.state.completions, isEmpty);
    expect(o.state.streak.longest, 0);
  });

  test('rewards stop after the daily cap but tasks still complete', () {
    var s = withTasks(TaskEngine.dailyRewardCap + 2);
    for (var i = 0; i < TaskEngine.dailyRewardCap + 2; i++) {
      s = TaskEngine.complete(s, 't$i', now).state;
    }
    expect(s.tasks.every((t) => t.done), isTrue);
    expect(s.totalXp, 20 * TaskEngine.dailyRewardCap);
    expect(TaskEngine.rewardedToday(s, now), TaskEngine.dailyRewardCap);

    // A new day pays again.
    final next = now.add(const Duration(days: 1));
    s = TaskEngine.add(s, const TaskItem(id: 'n', title: 'New'));
    expect(TaskEngine.complete(s, 'n', next).totalXpGainedOk, isTrue);
  });

  test('delete, clear done and unknown ids', () {
    var s = withTasks(2);
    s = TaskEngine.complete(s, 't0', now).state;
    s = TaskEngine.clearDone(s);
    expect(s.tasks.map((t) => t.id), ['t1']);
    expect(TaskEngine.delete(s, 't1').tasks, isEmpty);
    expect(TaskEngine.complete(s, 'nope', now).status, CompletionStatus.notFound);
  });

  test('tasks survive a JSON round trip and old backups load', () {
    final s = TaskEngine.complete(
            GameState(tasks: [
              const TaskItem(id: 'a', title: 'A', dueKey: '2026-01-06'),
              const TaskItem(id: 'b', title: 'B'),
            ]),
            'a',
            now)
        .state;
    final back = GameState.fromJson(s.toJson());
    expect(back.tasks.length, 2);
    expect(back.tasks.first.done, isTrue);
    expect(back.tasks.first.dueKey, '2026-01-06');

    final old = s.toJson()..remove('tasks');
    expect(GameState.fromJson(old).tasks, isEmpty);
  });

  test('open task limit', () {
    final s = withTasks(TaskEngine.maxOpenTasks);
    expect(() => TaskEngine.add(s, const TaskItem(id: 'x', title: 'x')),
        throwsStateError);
  });
}

extension on CompletionOutcome {
  bool get totalXpGainedOk => ok && xpGained == 20;
}
