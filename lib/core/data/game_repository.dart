import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';

abstract class GameRepository {
  Future<GameState> load();
  Future<void> save(GameState state);

  /// Backup document as pretty JSON text.
  Future<String> exportBackup();

  /// Replaces all data. Throws [FormatException] for invalid/old backups
  /// (existing data is left untouched in that case).
  Future<void> importBackup(String json);
}

class SharedPrefsGameRepository implements GameRepository {
  static const _key = 'life_kingdom_state_v1';

  @override
  Future<GameState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const GameState();
    try {
      return GameState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const GameState();
    }
  }

  @override
  Future<void> save(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  @override
  Future<String> exportBackup() async {
    final state = await load();
    return const JsonEncoder.withIndent('  ').convert(state.toJson());
  }

  @override
  Future<void> importBackup(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup is not a JSON object');
    }
    final state = GameState.fromJson(decoded); // validates first
    await save(state);
  }
}

/// For tests.
class InMemoryGameRepository implements GameRepository {
  GameState _state = const GameState();

  @override
  Future<GameState> load() async => _state;

  @override
  Future<void> save(GameState state) async => _state = state;

  @override
  Future<String> exportBackup() async => jsonEncode(_state.toJson());

  @override
  Future<void> importBackup(String json) async {
    _state = GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }
}
