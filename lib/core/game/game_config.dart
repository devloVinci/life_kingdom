/// All tunable numbers live here (see docs/game_rules.md).
class GameConfig {
  GameConfig._();

  static const maxLevel = 100;
  static const maxActiveHabits = 20;

  // Habit rewards by difficulty.
  static const habitXp = {
    Difficulty.easy: 10,
    Difficulty.medium: 20,
    Difficulty.hard: 35,
    Difficulty.epic: 60,
  };
  static const habitGold = {
    Difficulty.easy: 5,
    Difficulty.medium: 10,
    Difficulty.hard: 18,
    Difficulty.epic: 30,
  };

  // Streak.
  static const streakBonusPercentPerWeek = 5;
  static const streakBonusCapPercent = 25;
  static const freezeCost = 150;
  static const maxFreezes = 2;
  static const streakMilestones = <int, Reward>{
    7: Reward(gold: 50, gems: 2),
    14: Reward(gold: 100, gems: 3),
    30: Reward(gold: 300, gems: 10),
    60: Reward(gold: 600, gems: 20, chest: 'silver'),
    100: Reward(gold: 1000, gems: 50, chest: 'legendary'),
  };

  // Level-up: 10 * level gold, 5 gems on every 5th level.
  static const levelUpGoldPerLevel = 10;
  static const levelUpGemsEvery = 5;
  static const levelUpGems = 5;

  // Rank thresholds (first level of each rank) and rank-up rewards.
  static const ranks = <RankInfo>[
    RankInfo('E', 1, Reward()),
    RankInfo('D', 10, Reward(gems: 25, chest: 'wooden')),
    RankInfo('C', 20, Reward(gems: 25, chest: 'silver')),
    RankInfo('B', 35, Reward(gems: 40, chest: 'silver')),
    RankInfo('A', 55, Reward(gems: 60, chest: 'golden')),
    RankInfo('S', 80, Reward(gems: 100, chest: 'golden')),
    RankInfo('National Level', 100, Reward(gems: 200, chest: 'legendary')),
  ];
}

enum Difficulty { easy, medium, hard, epic }

class Reward {
  const Reward({this.gold = 0, this.gems = 0, this.chest});
  final int gold;
  final int gems;
  final String? chest;
}

class RankInfo {
  const RankInfo(this.name, this.fromLevel, this.reward);
  final String name;
  final int fromLevel;
  final Reward reward;
}
