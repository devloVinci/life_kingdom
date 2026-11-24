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
  });

  static const schemaVersion = 1;

  final String playerName;
  final int totalXp;
  final int gold;
  final int gems;
  final List<Habit> habits;
  final List<Completion> completions;
  final StreakState streak;

  /// Unopened chests ('wooden', 'silver', 'golden', 'legendary').
  final List<String> chests;

  GameState copyWith({
    String? playerName,
    int? totalXp,
    int? gold,
    int? gems,
    List<Habit>? habits,
    List<Completion>? completions,
    StreakState? streak,
    List<String>? chests,
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
      );
    } on TypeError catch (e) {
      throw FormatException('Malformed backup: $e');
    } on ArgumentError catch (e) {
      throw FormatException('Malformed backup: $e');
    }
  }
}
