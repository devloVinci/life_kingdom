import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/characters/sprite/sprite_hero.dart';
import 'package:life_kingdom/core/game/catalog.dart';

void main() {
  test('every sprite hero is a catalog character with its frames on disk', () {
    for (final def in spriteHeroes.values) {
      final item = Catalog.byId[def.itemId];
      expect(item, isNotNull, reason: def.itemId);
      expect(item!.type, ItemType.character);
      expect(File(def.portrait).existsSync(), isTrue, reason: def.portrait);

      final sets = [def.combat, if (def.flight != null) def.flight!];
      for (final set in sets) {
        final meta = jsonDecode(
            File('${def.folder}/$set/frames.json').readAsStringSync()) as Map;
        final frames = (meta['frames'] as List).cast<String>();
        for (final f in frames) {
          expect(File('${def.folder}/$set/$f.png').existsSync(), isTrue,
              reason: '${def.folder}/$set/$f.png');
        }
        if (set == def.combat) {
          expect(frames, contains(def.idle));
          for (final step in def.attack) {
            expect(frames, contains(step.frame), reason: step.frame);
          }
        } else {
          expect(frames, containsAll(['up', 'down']));
        }
      }
    }
  });

  test('pubspec lists every sprite hero asset folder', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final def in spriteHeroes.values) {
      expect(pubspec, contains('${def.folder}/\n'));
      expect(pubspec, contains('${def.folder}/${def.combat}/\n'));
      if (def.flight != null) {
        expect(pubspec, contains('${def.folder}/${def.flight}/\n'));
      }
    }
  });
}
