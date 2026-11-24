import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/game_repository.dart';
import '../core/game/achievement_engine.dart';
import '../core/game/economy_engine.dart';
import '../core/game/game_engine.dart';
import '../core/game/models.dart';
import '../core/game/quest_engine.dart';

/// Overridden in main() / tests.
final gameRepositoryProvider =
    Provider<GameRepository>((ref) => throw UnimplementedError());
final initialGameStateProvider =
    Provider<GameState>((ref) => throw UnimplementedError());

/// Injectable clock (tests override it).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final gameProvider =
    NotifierProvider<GameController, GameState>(GameController.new);

class GameController extends Notifier<GameState> {
  @override
  GameState build() => EconomyEngine.settleBuildings(GameEngine.rollover(
      ref.read(initialGameStateProvider), ref.read(clockProvider)()));

  DateTime get _now => ref.read(clockProvider)();

  final List<AchievementDef> _unlocked = [];

  void _set(GameState s) {
    final r = AchievementEngine.evaluate(s, _now);
    _unlocked.addAll(r.unlocked);
    state = r.state;
    ref.read(gameRepositoryProvider).save(r.state);
  }

  /// Achievements unlocked since the last call (for a snackbar).
  List<AchievementDef> takeUnlocked() {
    final l = [..._unlocked];
    _unlocked.clear();
    return l;
  }

  CompletionOutcome complete(String habitId) {
    final o = GameEngine.complete(state, habitId, _now);
    if (o.ok) _set(EconomyEngine.settleBuildings(o.state));
    return o;
  }

  CompletionOutcome undo(String habitId) {
    final o = GameEngine.undo(state, habitId, _now);
    if (o.ok) _set(o.state);
    return o;
  }

  /// Throws [HabitLimitException] when 20 active habits already exist.
  void addHabit(Habit h) => _set(GameEngine.addHabit(state, h));
  void updateHabit(Habit h) => _set(GameEngine.updateHabit(state, h));
  void deleteHabit(String id) => _set(GameEngine.deleteHabit(state, id));

  String newHabitId() => _now.microsecondsSinceEpoch.toString();

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
