import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/xp_curve.dart';

void main() {
  test('level costs', () {
    expect([for (var n = 1; n <= 5; n++) XpCurve.costOfLevel(n)],
        [20, 45, 75, 105, 140]);
  });

  test('cumulative XP matches game_rules.md', () {
    const expected = {
      2: 20, 3: 65, 4: 140, 5: 245, 9: 1005, 10: 1285, 20: 6255,
      35: 21955, 55: 60065, 80: 137835, 100: 225835,
    };
    expected.forEach((level, xp) {
      expect(XpCurve.xpForLevel(level), xp, reason: 'level $level');
    });
  });

  test('levelForXp boundaries', () {
    expect(XpCurve.levelForXp(0), 1);
    expect(XpCurve.levelForXp(19), 1);
    expect(XpCurve.levelForXp(20), 2);
    expect(XpCurve.levelForXp(1284), 9);
    expect(XpCurve.levelForXp(1285), 10);
    expect(XpCurve.levelForXp(999999999), 100);
  });

  test('ranks', () {
    expect(XpCurve.rankForLevel(1).name, 'E');
    expect(XpCurve.rankForLevel(9).name, 'E');
    expect(XpCurve.rankForLevel(10).name, 'D');
    expect(XpCurve.rankForLevel(79).name, 'A');
    expect(XpCurve.rankForLevel(80).name, 'S');
    expect(XpCurve.rankForLevel(100).name, 'National Level');
  });

  test('progress within level', () {
    expect(XpCurve.progress(30), (10, 45));
  });
}
