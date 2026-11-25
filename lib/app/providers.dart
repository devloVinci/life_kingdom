import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/game_repository.dart';
import '../core/game/achievement_engine.dart';
import '../core/game/companion_engine.dart';
import '../core/game/economy_engine.dart';
import '../core/game/game_engine.dart';
import '../core/game/models.dart';
import '../core/game/quest_engine.dart';
import '../core/game/task_engine.dart';
import '../core/game/world_engine.dart';

/// Overridden in main() / tests.
final gameRepositoryProvider =
    Provider<GameRepository>((ref) => throw UnimplementedError());
final initialGameStateProvider =
    Provider<GameState>((ref) => throw UnimplementedError());

/// Injectable clock (tests override it).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Sandbox save (separate from the real one). Overridden in main().
final sandboxRepositoryProvider =
    Provider<GameRepository>((ref) => InMemoryGameRepository());

/// True while the sandbox (try-anything mode) is active.
final sandboxModeProvider = StateProvider<bool>((ref) => false);

/// Days the sandbox has jumped forward (always 0 outside the sandbox).
final sandboxDaysProvider = StateProvider<int>((ref) => 0);

/// The game's "now": the real clock plus the sandbox time jump.
final nowProvider = Provider<DateTime Function()>((ref) {
  final clock = ref.watch(clockProvider);
  final days = ref.watch(sandboxDaysProvider);
  return () => clock().add(Duration(days: days));
});

final gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  @override
  GameState build() {
    final now = ref.read(nowProvider)();
    return WorldEngine.settle(
        EconomyEngine.settleBuildings(
            GameEngine.rollover(ref.read(initialGameStateProvider), now)),
        now);
  }

  DateTime get _now => ref.read(nowProvider)();

  bool get _sandbox => ref.read(sandboxModeProvider);

  final List<AchievementDef> _unlocked = [];

  void _set(GameState input) {
    final s = WorldEngine.settle(input, _now);
    final r = AchievementEngine.evaluate(s, _now);
    _unlocked.addAll(r.unlocked);
    state = r.state;
    (_sandbox ? ref.read(sandboxRepositoryProvider) : ref.read(gameRepositoryProvider))
        .save(r.state);
  }

  /// Achievements unlocked since the last call (for a snackbar).
  List<AchievementDef> takeUnlocked() {
    final l = [..._unlocked];
    _unlocked.clear();
    return l;
  }

  CompletionOutcome complete(String habitId) {
    final o = GameEngine.complete(state, habitId, _now);
    if (o.ok) {
      final h = state.habits.firstWhere((x) => x.id == habitId);
      _set(EconomyEngine.settleBuildings(
          WorldEngine.onWork(o.state, h.difficulty, _now)));
    }
    return o;
  }

  CompletionOutcome undo(String habitId) {
    final o = GameEngine.undo(state, habitId, _now);
    if (o.ok) {
      final h = state.habits.firstWhere((x) => x.id == habitId);
      _set(WorldEngine.onUndo(o.state, h.difficulty, _now));
    }
    return o;
  }

  /// Throws [HabitLimitException] when 20 active habits already exist.
  void addHabit(Habit h) => _set(GameEngine.addHabit(state, h));
  void updateHabit(Habit h) => _set(GameEngine.updateHabit(state, h));
  void deleteHabit(String id) => _set(GameEngine.deleteHabit(state, id));

  String newHabitId() => _now.microsecondsSinceEpoch.toString();

  // ---- Tasks (one-off to-dos) ----

  void addTask(TaskItem t) => _set(TaskEngine.add(state, t));
  void deleteTask(String id) => _set(TaskEngine.delete(state, id));
  void clearDoneTasks() => _set(TaskEngine.clearDone(state));

  CompletionOutcome completeTask(String id) {
    final o = TaskEngine.complete(state, id, _now);
    if (o.ok) {
      final t = state.tasks.firstWhere((x) => x.id == id);
      _set(o.goldGained > 0
          ? WorldEngine.onWork(o.state, t.difficulty, _now, taskId: id)
          : o.state);
    }
    return o;
  }

  // ---- Open world ----

  void setMainTask(String id) => _set(WorldEngine.setMainTask(state, id, _now));

  int collectHarvest() {
    final (s, g) = WorldEngine.collectHarvest(state);
    if (g > 0) _set(s);
    return g;
  }

  /// Gold won back from the goblin, or -1 if he cannot be chased yet.
  int chaseGoblin() {
    if (!WorldEngine.canChaseGoblin(state, _now)) return -1;
    final (s, g) = WorldEngine.chaseGoblin(state, _now);
    _set(s);
    return g;
  }

  DailyChest? claimChest() {
    final (s, c) = WorldEngine.claimChest(state, _now);
    if (c != null) _set(s);
    return c;
  }

  WeeklyReport? claimReport() {
    final (s, r) = WorldEngine.claimReport(state, _now);
    if (r != null) _set(s);
    return r;
  }

  TrainStatus train(String unitId, int count) {
    final (s, st) = ArmyEngine.train(state, unitId, count);
    if (st == TrainStatus.ok) _set(s);
    return st;
  }

  CaptureStatus capture(String landmarkId) {
    final (s, st) = ArmyEngine.capture(state, landmarkId);
    if (st == CaptureStatus.ok) _set(s);
    return st;
  }

  // ---- Sandbox (a separate save to try anything) ----

  /// Enters the sandbox. [fresh] starts empty, [copyReal] copies the real
  /// progress, otherwise the last sandbox save is resumed.
  Future<void> enterSandbox({bool fresh = false, bool copyReal = false}) async {
    final real =
        _sandbox ? await ref.read(gameRepositoryProvider).load() : state;
    final box = ref.read(sandboxRepositoryProvider);
    var s = fresh
        ? const GameState(playerName: 'تجربة')
        : copyReal
            ? real
            : await box.load();
    if (!fresh && !copyReal && s.totalXp == 0 && s.habits.isEmpty &&
        s.tasks.isEmpty) {
      s = real; // first visit: start from a copy of the real progress
    }
    if (!_sandbox) {
      ref.read(sandboxDaysProvider.notifier).state = 0;
      ref.read(sandboxModeProvider.notifier).state = true;
    }
    _set(s);
  }

  Future<void> exitSandbox() async {
    if (!_sandbox) return;
    ref.read(sandboxModeProvider.notifier).state = false;
    ref.read(sandboxDaysProvider.notifier).state = 0;
    final real = await ref.read(gameRepositoryProvider).load();
    state = WorldEngine.settle(real, _now);
  }

  /// Any change at all, sandbox only.
  void sandboxEdit(GameState Function(GameState s) change) {
    if (!_sandbox) return;
    _set(change(state));
  }

  void sandboxJumpDays(int days) {
    if (!_sandbox) return;
    ref.read(sandboxDaysProvider.notifier).state += days;
    _set(state);
  }

  RestStatus declareRest() {
    final (s, st) = WorldEngine.declareRest(state, _now);
    if (st == RestStatus.ok) _set(s);
    return st;
  }

  // ---- Shop ----

  PurchaseOutcome buy(String itemId, {required bool useGems}) {
    final o = EconomyEngine.buy(state, itemId, useGems: useGems);
    if (o.ok) _set(o.state);
    return o;
  }

  bool equip(String itemId) {
    final next = EconomyEngine.equip(state, itemId);
    if (next == null) return false;
    _set(next);
    return true;
  }

  bool buyFreeze() {
    final next = GameEngine.buyFreeze(state);
    if (next == null) return false;
    _set(next);
    return true;
  }

  // ---- Custom rewards ----

  void addCustomReward(String title, int priceGold) => _set(
      EconomyEngine.addCustomReward(state, newHabitId(), title, priceGold));

  RewardStatus redeemCustomReward(String id) {
    final (next, status) = EconomyEngine.redeemCustomReward(state, id);
    if (status == RewardStatus.ok) _set(next);
    return status;
  }

  void deleteCustomReward(String id) =>
      _set(EconomyEngine.deleteCustomReward(state, id));

  // ---- Buildings ----

  UpgradeOutcome startUpgrade(String id) {
    final o = EconomyEngine.startUpgrade(state, id, _now);
    if (o.ok) _set(o.state);
    return o;
  }

  UpgradeOutcome skipUpgradeDays(String id) {
    final o = EconomyEngine.skipDays(state, id);
    if (o.ok) _set(o.state);
    return o;
  }

  // ---- Companions ----

  CompanionStatus addCompanion(String id) {
    final o = CompanionEngine.add(state, id);
    if (o.ok) _set(o.state);
    return o.status;
  }

  CompanionStatus removeCompanion(String id) {
    final o = CompanionEngine.remove(state, id);
    if (o.ok) _set(o.state);
    return o.status;
  }

  // ---- Chests ----

  ChestResult? openChest(String type, {Random? random}) {
    final r = EconomyEngine.openChest(state, type, random ?? Random());
    if (r != null) _set(r.state);
    return r;
  }

  // ---- Quests ----

  ClaimOutcome claimQuest(String key) {
    final o = QuestEngine.claim(state, key, _now);
    if (o.ok) _set(o.state);
    return o;
  }

  // ---- Profile / settings / backup ----

  void setPlayerName(String name) =>
      _set(state.copyWith(playerName: name.trim().isEmpty ? 'Hero' : name.trim()));

  void setSetting(String key, bool value) =>
      _set(state.copyWith(settings: {...state.settings, key: value}));

  /// Replaces everything (backup restore / reset).
  void replaceState(GameState s) => _set(s);
}
