/// Open-world game data stored next to the productivity data (schema v2).
///
/// Everything here is earned from real work (see `world_engine.dart`);
/// none of it can be bought.
class WorldState {
  const WorldState({
    this.supplies = 0,
    this.suppliesDayKey,
    this.suppliesToday = 0,
    this.stones = 0,
    this.mainTaskId,
    this.mainTaskKey,
    this.pendingHarvest = 0,
    this.goblinLoot = 0,
    this.goblinDateKey,
    this.lastSettledKey,
    this.chestClaimedKey,
    this.reportsClaimed = const {},
    this.fortifyAwardKeys = const {},
    this.bestWeek = 0,
    this.bestWeekKey,
    this.army = const {},
    this.captured = const {},
  });

  /// Fuel for the open world (marches, bosses, freeing villages).
  final int supplies;

  /// Daily supply cap bookkeeping.
  final String? suppliesDayKey;
  final int suppliesToday;

  /// Foundation stones: only from the day's "most important" task.
  final int stones;

  /// Task chosen as today's most important one (and the day it was chosen).
  final String? mainTaskId;
  final String? mainTaskKey;

  /// Gold waiting above the gold mine; collected by tapping it.
  final int pendingHarvest;

  /// Gold a goblin carried off after a missed day; can be won back.
  final int goblinLoot;
  final String? goblinDateKey;

  /// Last day that missed-day checks ran for.
  final String? lastSettledKey;

  /// Day whose work was paid out by the daily chest.
  final String? chestClaimedKey;

  /// Week keys (Monday date) whose scout report was claimed.
  final Set<String> reportsClaimed;

  /// Days on which a 7-day streak earned a fortification.
  final Set<String> fortifyAwardKeys;

  /// Best weekly score and the week it happened (record tower).
  final int bestWeek;
  final String? bestWeekKey;

  /// Trained units: unit id -> count.
  final Map<String, int> army;

  /// Landmark ids taken on the world map.
  final Set<String> captured;

  WorldState copyWith({
    int? supplies,
    String? suppliesDayKey,
    int? suppliesToday,
    int? stones,
    String? mainTaskId,
    String? mainTaskKey,
    bool clearMainTask = false,
    int? pendingHarvest,
    int? goblinLoot,
    String? goblinDateKey,
    String? lastSettledKey,
    String? chestClaimedKey,
    Set<String>? reportsClaimed,
    Set<String>? fortifyAwardKeys,
    int? bestWeek,
    String? bestWeekKey,
    Map<String, int>? army,
    Set<String>? captured,
  }) =>
      WorldState(
        supplies: supplies ?? this.supplies,
        suppliesDayKey: suppliesDayKey ?? this.suppliesDayKey,
        suppliesToday: suppliesToday ?? this.suppliesToday,
        stones: stones ?? this.stones,
        mainTaskId: clearMainTask ? null : (mainTaskId ?? this.mainTaskId),
        mainTaskKey: clearMainTask ? null : (mainTaskKey ?? this.mainTaskKey),
        pendingHarvest: pendingHarvest ?? this.pendingHarvest,
        goblinLoot: goblinLoot ?? this.goblinLoot,
        goblinDateKey: goblinDateKey ?? this.goblinDateKey,
        lastSettledKey: lastSettledKey ?? this.lastSettledKey,
        chestClaimedKey: chestClaimedKey ?? this.chestClaimedKey,
        reportsClaimed: reportsClaimed ?? this.reportsClaimed,
        fortifyAwardKeys: fortifyAwardKeys ?? this.fortifyAwardKeys,
        bestWeek: bestWeek ?? this.bestWeek,
        bestWeekKey: bestWeekKey ?? this.bestWeekKey,
        army: army ?? this.army,
        captured: captured ?? this.captured,
      );

  Map<String, dynamic> toJson() => {
        'supplies': supplies,
        if (suppliesDayKey != null) 'suppliesDayKey': suppliesDayKey,
        'suppliesToday': suppliesToday,
        'stones': stones,
        if (mainTaskId != null) 'mainTaskId': mainTaskId,
        if (mainTaskKey != null) 'mainTaskKey': mainTaskKey,
        'pendingHarvest': pendingHarvest,
        'goblinLoot': goblinLoot,
        if (goblinDateKey != null) 'goblinDateKey': goblinDateKey,
        if (lastSettledKey != null) 'lastSettledKey': lastSettledKey,
        if (chestClaimedKey != null) 'chestClaimedKey': chestClaimedKey,
        'reportsClaimed': (reportsClaimed.toList()..sort()),
        'fortifyAwardKeys': (fortifyAwardKeys.toList()..sort()),
        'bestWeek': bestWeek,
        if (bestWeekKey != null) 'bestWeekKey': bestWeekKey,
        'army': army,
        'captured': (captured.toList()..sort()),
      };

  factory WorldState.fromJson(Map<String, dynamic> j) => WorldState(
        supplies: (j['supplies'] as int?) ?? 0,
        suppliesDayKey: j['suppliesDayKey'] as String?,
        suppliesToday: (j['suppliesToday'] as int?) ?? 0,
        stones: (j['stones'] as int?) ?? 0,
        mainTaskId: j['mainTaskId'] as String?,
        mainTaskKey: j['mainTaskKey'] as String?,
        pendingHarvest: (j['pendingHarvest'] as int?) ?? 0,
        goblinLoot: (j['goblinLoot'] as int?) ?? 0,
        goblinDateKey: j['goblinDateKey'] as String?,
        lastSettledKey: j['lastSettledKey'] as String?,
        chestClaimedKey: j['chestClaimedKey'] as String?,
        reportsClaimed:
            ((j['reportsClaimed'] as List?) ?? const []).cast<String>().toSet(),
        fortifyAwardKeys: ((j['fortifyAwardKeys'] as List?) ?? const [])
            .cast<String>()
            .toSet(),
        bestWeek: (j['bestWeek'] as int?) ?? 0,
        bestWeekKey: j['bestWeekKey'] as String?,
        army: Map<String, int>.from((j['army'] as Map?) ?? const {}),
        captured:
            ((j['captured'] as List?) ?? const []).cast<String>().toSet(),
      );
}
