import 'game_config.dart';
import 'game_engine.dart';
import 'models.dart';

/// One-off to-dos. They pay XP and gold like habits (so the player is
/// rewarded for real work of any kind) but do not touch habit streaks, and
/// only [dailyRewardCap] completions per day are paid, so tiny tasks cannot
/// be farmed.
class TaskEngine {
  TaskEngine._();

  static const dailyRewardCap = 5;
  static const maxOpenTasks = 50;

  static int rewardedToday(GameState s, DateTime now) {
    final key = dateKeyOf(now);
    return s.tasks.where((t) => t.doneKey == key && t.rewarded).length;
  }

  static GameState add(GameState s, TaskItem t) {
    if (s.tasks.where((x) => !x.done).length >= maxOpenTasks) {
      throw StateError('Too many open tasks');
    }
    return s.copyWith(tasks: [...s.tasks, t]);
  }

  static GameState delete(GameState s, String id) =>
      s.copyWith(tasks: s.tasks.where((t) => t.id != id).toList());

  static GameState clearDone(GameState s) =>
      s.copyWith(tasks: s.tasks.where((t) => !t.done).toList());

  static CompletionOutcome complete(GameState input, String id, DateTime now) {
    final s = GameEngine.rollover(input, now);
    final i = s.tasks.indexWhere((t) => t.id == id);
    if (i < 0) return CompletionOutcome(s, CompletionStatus.notFound);
    final task = s.tasks[i];
    if (task.done) return CompletionOutcome(s, CompletionStatus.alreadyCompleted);

    final key = dateKeyOf(now);
    final paid = rewardedToday(s, now) < dailyRewardCap;
    final tasks = [...s.tasks]..[i] = task.copyWith(doneKey: key, rewarded: paid);
    var next = s.copyWith(tasks: tasks);
    if (!paid) return CompletionOutcome(next, CompletionStatus.done);

    final xp = GameConfig.habitXp[task.difficulty]!;
    final treasuryPct = (s.buildingLevel('treasury') - 1) * 2;
    final gold =
        (GameConfig.habitGold[task.difficulty]! * (100 + treasuryPct) + 50) ~/ 100;
    final (gs, events) = GameEngine.grantXp(next.copyWith(gold: next.gold + gold), xp);
    return CompletionOutcome(gs, CompletionStatus.done,
        events: events, xpGained: xp, goldGained: gold);
  }
}
