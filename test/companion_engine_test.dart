import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/companion_engine.dart';
import 'package:life_kingdom/core/game/models.dart';

GameState withCamp(int level, {Set<String>? owned}) => GameState(
      owned: owned ?? {...GameState.defaultOwned, 'char_archer', 'char_brute'},
      buildings: {'army_camp': BuildingState(level: level)},
    );

void main() {
  test('slots grow with the Army Camp level and cap at 5', () {
    expect(CompanionEngine.slots(withCamp(1)), 1);
    expect(CompanionEngine.slots(withCamp(2)), 1);
    expect(CompanionEngine.slots(withCamp(3)), 2);
    expect(CompanionEngine.slots(withCamp(5)), 3);
    expect(CompanionEngine.slots(withCamp(9)), 5);
    expect(CompanionEngine.slots(withCamp(10)), 5);
    expect(CompanionEngine.nextSlotLevel(withCamp(1)), 3);
    expect(CompanionEngine.nextSlotLevel(withCamp(9)), isNull);
  });

  test('add respects ownership, duplicates and capacity', () {
    var s = withCamp(1);
    expect(CompanionEngine.add(s, 'char_warlord').status,
        CompanionStatus.notOwned);
    final a = CompanionEngine.add(s, 'char_archer');
    expect(a.ok, isTrue);
    s = a.state;
    expect(s.companions, ['char_archer']);
    expect(CompanionEngine.add(s, 'char_archer').status,
        CompanionStatus.already);
    expect(CompanionEngine.add(s, 'char_brute').status, CompanionStatus.full);
    expect(CompanionEngine.add(s, 'title_focused').status,
        CompanionStatus.notOwned);
  });

  test('remove frees the slot', () {
    var s = CompanionEngine.add(withCamp(1), 'char_archer').state;
    expect(CompanionEngine.remove(s, 'char_brute').status,
        CompanionStatus.notCompanion);
    s = CompanionEngine.remove(s, 'char_archer').state;
    expect(s.companions, isEmpty);
    expect(CompanionEngine.add(s, 'char_brute').ok, isTrue);
  });

  test('companions survive a JSON round trip and old backups load', () {
    final s = CompanionEngine.add(withCamp(1), 'char_archer').state;
    expect(GameState.fromJson(s.toJson()).companions, ['char_archer']);
    final old = s.toJson()..remove('companions');
    expect(GameState.fromJson(old).companions, isEmpty);
  });
}
