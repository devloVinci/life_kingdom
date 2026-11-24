import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/theme/app_colors.dart';

void main() {
  test('rarity labels', () {
    expect(Rarity.legendary.label, 'Legendary');
  });
}
