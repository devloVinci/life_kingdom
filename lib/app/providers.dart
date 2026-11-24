import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/game_repository.dart';
import '../core/game/game_engine.dart';
import '../core/game/models.dart';

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
  GameState build() => GameEngine.rollover(
      ref.read(initialGameStateProvider), ref.read(clockProvider)());

  DateTime get _now => ref.read(clockProvider)();

  void _set(GameState s) {
    state = s;
    ref.read(gameRepositoryProvider).save(s);
  }

  CompletionOutcome complete(String habitId) {
    final o = GameEngine.complete(state, habitId, _now);
    if (o.ok) _set(o.state);
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
}
