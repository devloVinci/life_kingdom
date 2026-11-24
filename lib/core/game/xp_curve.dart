import 'dart:math';

import 'game_config.dart';

/// XP curve: cost(n) = round5(20 * n^1.2) to go from level n to n+1.
class XpCurve {
  XpCurve._();

  /// XP needed to advance from [level] to [level] + 1.
  static int costOfLevel(int level) {
    final x = 20 * pow(level.toDouble(), 1.2) / 5;
    return (x + 0.5).floor() * 5;
  }

  static final List<int> _cumulative = _build();

  static List<int> _build() {
    // _cumulative[L] = total XP needed to reach level L (index 0 unused).
    final list = List<int>.filled(GameConfig.maxLevel + 1, 0);
    var sum = 0;
    for (var l = 1; l < GameConfig.maxLevel; l++) {
      list[l] = sum;
      sum += costOfLevel(l);
    }
    list[GameConfig.maxLevel] = sum;
    return list;
  }

  /// Total XP at which [level] starts.
  static int xpForLevel(int level) =>
      _cumulative[level.clamp(1, GameConfig.maxLevel)];

  static int levelForXp(int totalXp) {
    var lo = 1, hi = GameConfig.maxLevel;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_cumulative[mid] <= totalXp) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  /// (xp into current level, xp needed for this level). At max level: (0, 0).
  static (int, int) progress(int totalXp) {
    final l = levelForXp(totalXp);
    if (l >= GameConfig.maxLevel) return (0, 0);
    return (totalXp - _cumulative[l], costOfLevel(l));
  }

  static RankInfo rankForLevel(int level) {
    var r = GameConfig.ranks.first;
    for (final info in GameConfig.ranks) {
      if (level >= info.fromLevel) r = info;
    }
    return r;
  }
}
