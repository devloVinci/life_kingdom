import 'dart:math';

import 'game_engine.dart';
import 'models.dart';

/// What a land milestone measures. Every metric only counts real-life
/// progress: habits kept, tasks finished, levels earned and streaks held.
enum GrowthMetric { habitsDone, tasksDone, level, bestStreak }

/// One piece of land. Reaching it pushes the edge of the world outwards.
class LandMilestone {
  const LandMilestone({
    required this.id,
    required this.land,
    required this.goal,
    required this.metric,
    required this.target,
  });

  final String id;

  /// Name of the land that opens up.
  final String land;

  /// What the player has to do in real life.
  final String goal;
  final GrowthMetric metric;
  final int target;
}

class WorldProgress {
  const WorldProgress({
    required this.reached,
    required this.next,
    required this.nextValue,
  });

  /// Milestones reached (stored ones included, so land never shrinks).
  final Set<String> reached;

  /// The next milestone in list order that is not reached yet.
  final LandMilestone? next;

  /// Current value of [next]'s metric.
  final int nextValue;

  int get count => reached.length;
  bool get complete => next == null;
}

/// The home world starts as a tiny clearing and opens up, ring by ring, as
/// the player makes progress in real life.
class WorldGrowth {
  WorldGrowth._();

  /// Settings key prefix that records milestones the player has already
  /// watched open up. Stored in [GameState.settings], so the save schema does
  /// not change and land stays open even if a task list is cleared later.
  static const seenPrefix = 'world_seen_';

  static const milestones = <LandMilestone>[
    LandMilestone(id: 'first_habit', land: 'The Old Well', goal: 'Complete your first habit', metric: GrowthMetric.habitsDone, target: 1),
    LandMilestone(id: 'first_task', land: 'Plateau Steps', goal: 'Finish a one-off task', metric: GrowthMetric.tasksDone, target: 1),
    LandMilestone(id: 'level_2', land: 'Mossy Rocks', goal: 'Reach level 2', metric: GrowthMetric.level, target: 2),
    LandMilestone(id: 'streak_3', land: 'Shaded Grove', goal: 'Hold a 3-day streak', metric: GrowthMetric.bestStreak, target: 3),
    LandMilestone(id: 'habits_10', land: 'Lone Oak', goal: 'Complete 10 habits', metric: GrowthMetric.habitsDone, target: 10),
    LandMilestone(id: 'level_4', land: 'Stone Ring', goal: 'Reach level 4', metric: GrowthMetric.level, target: 4),
    LandMilestone(id: 'streak_7', land: 'Eastern Woods', goal: 'Hold a 7-day streak', metric: GrowthMetric.bestStreak, target: 7),
    LandMilestone(id: 'tasks_10', land: 'Dirt Road', goal: 'Finish 10 tasks', metric: GrowthMetric.tasksDone, target: 10),
    LandMilestone(id: 'habits_30', land: 'Western Meadow', goal: 'Complete 30 habits', metric: GrowthMetric.habitsDone, target: 30),
    LandMilestone(id: 'level_7', land: 'High Cliffs', goal: 'Reach level 7', metric: GrowthMetric.level, target: 7),
    LandMilestone(id: 'streak_14', land: 'Northern Fields', goal: 'Hold a 14-day streak', metric: GrowthMetric.bestStreak, target: 14),
    LandMilestone(id: 'level_10', land: 'The Whole Valley', goal: 'Reach level 10', metric: GrowthMetric.level, target: 10),
  ];

  static final Map<String, LandMilestone> byId = {
    for (final m in milestones) m.id: m,
  };

  static int value(GameState s, DateTime now, GrowthMetric metric) =>
      switch (metric) {
        GrowthMetric.habitsDone => s.completions.length,
        GrowthMetric.tasksDone => s.tasks.where((t) => t.done).length,
        GrowthMetric.level => GameEngine.level(s),
        GrowthMetric.bestStreak =>
          max(s.streak.longest, GameEngine.currentStreak(s, now)),
      };

  /// Milestones the player has already seen open (stored in settings).
  static Set<String> seen(GameState s) => {
        for (final m in milestones)
          if (s.settings['$seenPrefix${m.id}'] == true) m.id,
      };

  static WorldProgress progress(GameState s, DateTime now) {
    final reached = <String>{...seen(s)};
    LandMilestone? next;
    for (final m in milestones) {
      if (value(s, now, m.metric) >= m.target) reached.add(m.id);
    }
    for (final m in milestones) {
      if (!reached.contains(m.id)) {
        next = m;
        break;
      }
    }
    return WorldProgress(
      reached: reached,
      next: next,
      nextValue: next == null ? 0 : value(s, now, next.metric),
    );
  }

  /// Radius of open land, in tiles, after [count] milestones.
  /// Starts as a small clearing and covers the whole map at the end.
  static double radiusFor(int count) {
    if (count >= milestones.length) return 26;
    return 3.2 + count * 1.45;
  }
}
