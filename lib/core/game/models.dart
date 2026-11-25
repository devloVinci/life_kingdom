import 'catalog.dart';
import 'game_config.dart';

String dateKeyOf(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar-safe day arithmetic (no DST drift).
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

class Habit {
  const Habit({
    required this.id,
    required this.title,
    this.description = '',
    this.difficulty = Difficulty.medium,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.reminderMinutes,
    this.archived = false,
  });

  final String id;
  final String title;
  final String description;
  final Difficulty difficulty;

  /// DateTime.weekday values (1 = Monday ... 7 = Sunday). All 7 = daily.
  final Set<int> weekdays;

  /// Reminder time as minutes after midnight, or null for none.
  final int? reminderMinutes;
  final bool archived;

  bool isDueOn(DateTime d) => weekdays.contains(d.weekday);

  Habit copyWith({
    String? title,
    String? description,
    Difficulty? difficulty,
    Set<int>? weekdays,
    int? reminderMinutes,
    bool clearReminder = false,
    bool? archived,
  }) =>
      Habit(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        difficulty: difficulty ?? this.difficulty,
        weekdays: weekdays ?? this.weekdays,
        reminderMinutes:
            clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
        archived: archived ?? this.archived,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficulty': difficulty.name,
        'weekdays': (weekdays.toList()..sort()),
        'reminderMinutes': reminderMinutes,
        'archived': archived,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        title: j['title'] as String,
        description: (j['description'] as String?) ?? '',
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        weekdays: ((j['weekdays'] as List).cast<int>()).toSet(),
        reminderMinutes: j['reminderMinutes'] as int?,
        archived: (j['archived'] as bool?) ?? false,
      );
}

/// One paid completion. Unique per (habitId, dateKey).
class Completion {
  const Completion({
    required this.habitId,
    required this.dateKey,
    required this.xp,
    required this.gold,
  });

  final String habitId;
  final String dateKey;
  final int xp;
  final int gold;

  Map<String, dynamic> toJson() =>
      {'habitId': habitId, 'dateKey': dateKey, 'xp': xp, 'gold': gold};

  factory Completion.fromJson(Map<String, dynamic> j) => Completion(
        habitId: j['habitId'] as String,
        dateKey: j['dateKey'] as String,
        xp: j['xp'] as int,
        gold: j['gold'] as int,
      );
}

/// Stored streak data. The current streak is derived from completions.
class StreakState {
  const StreakState({
    this.longest = 0,
    this.freezesHeld = 0,
    this.freezeDates = const {},
    this.milestonesClaimed = const {},
  });

  final int longest;
  final int freezesHeld;

  /// Dates covered by a streak freeze (count as kept days).
  final Set<String> freezeDates;
  final Set<int> milestonesClaimed;

  StreakState copyWith({
    int? longest,
    int? freezesHeld,
    Set<String>? freezeDates,
    Set<int>? milestonesClaimed,
  }) =>
      StreakState(
        longest: longest ?? this.longest,
        freezesHeld: freezesHeld ?? this.freezesHeld,
        freezeDates: freezeDates ?? this.freezeDates,
        milestonesClaimed: milestonesClaimed ?? this.milestonesClaimed,
      );

  Map<String, dynamic> toJson() => {
        'longest': longest,
        'freezesHeld': freezesHeld,
        'freezeDates': (freezeDates.toList()..sort()),
        'milestonesClaimed': (milestonesClaimed.toList()..sort()),
      };

  factory StreakState.fromJson(Map<String, dynamic> j) => StreakState(
        longest: (j['longest'] as int?) ?? 0,
        freezesHeld: (j['freezesHeld'] as int?) ?? 0,
        freezeDates: ((j['freezeDates'] as List?) ?? const [])
            .cast<String>()
            .toSet(),
        milestonesClaimed: ((j['milestonesClaimed'] as List?) ?? const [])
            .cast<int>()
            .toSet(),
      );
}

class BuildingState {
  const BuildingState({
    this.level = 1,
    this.upgradeTarget,
    this.upgradeStartKey,
    this.workDaysNeeded = 0,
    this.skippedDays = 0,
  });

  final int level;

  /// Level being built, or null when idle.
  final int? upgradeTarget;
  final String? upgradeStartKey;
  final int workDaysNeeded;
  final int skippedDays;

  bool get upgrading => upgradeTarget != null;

  BuildingState copyWith({
    int? level,
    int? skippedDays,
    bool clearUpgrade = false,
  }) =>
      BuildingState(
        level: level ?? this.level,
        upgradeTarget: clearUpgrade ? null : upgradeTarget,
        upgradeStartKey: clearUpgrade ? null : upgradeStartKey,
        workDaysNeeded: clearUpgrade ? 0 : workDaysNeeded,
        skippedDays: clearUpgrade ? 0 : (skippedDays ?? this.skippedDays),
      );

  Map<String, dynamic> toJson() => {
        'level': level,
        'upgradeTarget': upgradeTarget,
        'upgradeStartKey': upgradeStartKey,
        'workDaysNeeded': workDaysNeeded,
        'skippedDays': skippedDays,
      };

  factory BuildingState.fromJson(Map<String, dynamic> j) => BuildingState(
        level: (j['level'] as int?) ?? 1,
        upgradeTarget: j['upgradeTarget'] as int?,
        upgradeStartKey: j['upgradeStartKey'] as String?,
        workDaysNeeded: (j['workDaysNeeded'] as int?) ?? 0,
        skippedDays: (j['skippedDays'] as int?) ?? 0,
      );
}

/// A reward the user defines (a real-life treat) and buys with gold.
class CustomReward {
  const CustomReward({
    required this.id,
    required this.title,
    required this.priceGold,
    this.timesRedeemed = 0,
  });

  final String id;
  final String title;
  final int priceGold;
  final int timesRedeemed;

  CustomReward copyWith({int? timesRedeemed}) => CustomReward(
        id: id,
        title: title,
        priceGold: priceGold,
        timesRedeemed: timesRedeemed ?? this.timesRedeemed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'priceGold': priceGold,
        'timesRedeemed': timesRedeemed,
      };

  factory CustomReward.fromJson(Map<String, dynamic> j) => CustomReward(
        id: j['id'] as String,
        title: j['title'] as String,
        priceGold: j['priceGold'] as int,
        timesRedeemed: (j['timesRedeemed'] as int?) ?? 0,
      );
}

/// A one-off to-do (as opposed to a repeating [Habit]).
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.difficulty = Difficulty.medium,
    this.dueKey,
    this.doneKey,
    this.rewarded = false,
  });

  final String id;
  final String title;
  final Difficulty difficulty;

  /// Due date as yyyy-MM-dd, or null for "whenever".
  final String? dueKey;

  /// Date it was completed, or null while open.
  final String? doneKey;

  /// False when it was finished after the daily reward cap was reached.
  final bool rewarded;

  bool get done => doneKey != null;

  TaskItem copyWith({String? doneKey, bool? rewarded}) => TaskItem(
        id: id,
        title: title,
        difficulty: difficulty,
        dueKey: dueKey,
        doneKey: doneKey ?? this.doneKey,
        rewarded: rewarded ?? this.rewarded,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'difficulty': difficulty.name,
        if (dueKey != null) 'dueKey': dueKey,
        if (doneKey != null) 'doneKey': doneKey,
        'rewarded': rewarded,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'] as String,
        title: j['title'] as String,
        difficulty: Difficulty.values.byName(j['difficulty'] as String),
        dueKey: j['dueKey'] as String?,
        doneKey: j['doneKey'] as String?,
        rewarded: (j['rewarded'] as bool?) ?? false,
      );
}

class GameState {
  const GameState({
    this.playerName = 'Hero',
    this.totalXp = 0,
    this.gold = 0,
    this.gems = 0,
    this.habits = const [],
    this.completions = const [],
    this.streak = const StreakState(),
    this.chests = const [],
    this.owned = defaultOwned,
    this.equipped = defaultEquipped,
    this.buildings = const {},
    this.customRewards = const [],
    this.claimedQuests = const {},
    this.achievements = const {},
    this.settings = const {},
    this.companions = const [],
    this.tasks = const [],
  });

  static const schemaVersion = 1;
  static const defaultOwned = {
    'char_raider',
    'char_builder',
    ...Catalog.starterIds,
  };
  static const defaultEquipped = {'character': 'char_raider'};

  /// What each equip slot shows when nothing was chosen yet.
  static const slotDefaults = {
    'character': 'char_raider',
    'uiTheme': 'ui_obsidian',
    'season': 'season_summer',
    'dragonSkin': 'dragon_ember',
  };

  /// Equipped item for [slot], falling back to the slot's default.
  String? equippedIn(String slot) => equipped[slot] ?? slotDefaults[slot];

  final String playerName;
  final List<TaskItem> tasks;
  final int totalXp;
  final int gold;
  final int gems;
  final List<Habit> habits;
  final List<Completion> completions;
  final StreakState streak;

  /// Unopened chests ('wooden', 'silver', 'golden', 'legendary').
  final List<String> chests;

  /// Owned shop item ids.
  final Set<String> owned;

  /// slot ('character' | 'title' | 'background' | 'uiTheme' | 'season' |
  /// 'dragonSkin') -> item id. Missing slots use the defaults.
  final Map<String, String> equipped;

  /// Missing entries mean level 1, idle.
  final Map<String, BuildingState> buildings;
  final List<CustomReward> customRewards;

  /// Claimed quest instance keys (e.g. 'daily:2026-01-01:d_three').
  final Set<String> claimedQuests;

  /// Unlocked achievement id -> date key it was unlocked.
  final Map<String, String> achievements;

  /// User settings (notification toggles etc.).
  final Map<String, bool> settings;

  /// Owned character ids that follow the player (limited by the Army Camp).
  final List<String> companions;

  bool setting(String key, {bool fallback = true}) =>
      settings[key] ?? fallback;

  BuildingState building(String id) => buildings[id] ?? const BuildingState();
  int buildingLevel(String id) => building(id).level;

  GameState copyWith({
    String? playerName,
    int? totalXp,
    int? gold,
    int? gems,
    List<Habit>? habits,
    List<Completion>? completions,
    StreakState? streak,
    List<String>? chests,
    Set<String>? owned,
    Map<String, String>? equipped,
    Map<String, BuildingState>? buildings,
    List<CustomReward>? customRewards,
    Set<String>? claimedQuests,
    Map<String, String>? achievements,
    Map<String, bool>? settings,
    List<String>? companions,
    List<TaskItem>? tasks,
  }) =>
      GameState(
        playerName: playerName ?? this.playerName,
        totalXp: totalXp ?? this.totalXp,
        gold: gold ?? this.gold,
        gems: gems ?? this.gems,
        habits: habits ?? this.habits,
        completions: completions ?? this.completions,
        streak: streak ?? this.streak,
        chests: chests ?? this.chests,
        owned: owned ?? this.owned,
        equipped: equipped ?? this.equipped,
        buildings: buildings ?? this.buildings,
        customRewards: customRewards ?? this.customRewards,
        claimedQuests: claimedQuests ?? this.claimedQuests,
        achievements: achievements ?? this.achievements,
        settings: settings ?? this.settings,
        companions: companions ?? this.companions,
        tasks: tasks ?? this.tasks,
      );

  /// Full backup document (also used for local persistence).
  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'playerName': playerName,
        'totalXp': totalXp,
        'gold': gold,
        'gems': gems,
        'habits': habits.map((h) => h.toJson()).toList(),
        'completions': completions.map((c) => c.toJson()).toList(),
        'streak': streak.toJson(),
        'chests': chests,
        'owned': (owned.toList()..sort()),
        'equipped': equipped,
        'buildings': buildings.map((k, v) => MapEntry(k, v.toJson())),
        'customRewards': customRewards.map((c) => c.toJson()).toList(),
        'claimedQuests': (claimedQuests.toList()..sort()),
        'achievements': achievements,
        'settings': settings,
        'companions': companions,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };

  /// Throws [FormatException] for unknown versions or malformed data.
  factory GameState.fromJson(Map<String, dynamic> j) {
    final v = j['schemaVersion'];
    if (v != schemaVersion) {
      throw FormatException('Unsupported backup version: $v');
    }
    try {
      return GameState(
        playerName: (j['playerName'] as String?) ?? 'Hero',
        totalXp: j['totalXp'] as int,
        gold: j['gold'] as int,
        gems: j['gems'] as int,
        habits: (j['habits'] as List)
            .map((e) => Habit.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        completions: (j['completions'] as List)
            .map((e) =>
                Completion.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        streak: StreakState.fromJson(
            Map<String, dynamic>.from(j['streak'] as Map)),
        chests: ((j['chests'] as List?) ?? const []).cast<String>(),
        // Starter cosmetics are merged into older saves; nothing owned is
        // ever removed.
        owned: j['owned'] == null
            ? defaultOwned
            : {...Catalog.starterIds, ...(j['owned'] as List).cast<String>()},
        equipped: j['equipped'] == null
            ? defaultEquipped
            : Map<String, String>.from(j['equipped'] as Map),
        buildings: ((j['buildings'] as Map?) ?? const {}).map((k, v) =>
            MapEntry(k as String,
                BuildingState.fromJson(Map<String, dynamic>.from(v as Map)))),
        customRewards: ((j['customRewards'] as List?) ?? const [])
            .map((e) =>
                CustomReward.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        claimedQuests:
            ((j['claimedQuests'] as List?) ?? const []).cast<String>().toSet(),
        achievements: Map<String, String>.from(
            (j['achievements'] as Map?) ?? const {}),
        settings:
            Map<String, bool>.from((j['settings'] as Map?) ?? const {}),
        companions: ((j['companions'] as List?) ?? const []).cast<String>(),
        tasks: ((j['tasks'] as List?) ?? const [])
            .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed backup: $e');
    } on ArgumentError catch (e) {
      throw FormatException('Malformed backup: $e');
    }
  }
}
