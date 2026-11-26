import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/game/atlas/catalog.dart';
import 'package:life_kingdom/game/atlas/character_anims.dart';
import 'package:life_kingdom/game/atlas/sprite_atlas.dart';
import 'package:life_kingdom/core/game/world_engine.dart';

/// Metadata of the real pack (names and counts only; no art), written by
/// `import_pack.py --fixture`. Lets CI catch a wrong name in the catalog.
AtlasData _atlas(String id) {
  final j = jsonDecode(File('test/fixtures/pack_index.json').readAsStringSync())
      as Map<String, dynamic>;
  final asset = (j['assets'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((a) => a['id'] == id, orElse: () => throw 'no asset $id');
  final frames = <String, AtlasFrame>{};
  final anims = <String, List<String>>{};
  (asset['animations'] as Map).forEach((k, v) {
    final n = (v as Map)['frames'] as int;
    anims[k as String] = [for (var i = 0; i < n; i++) '$k#$i'];
    for (final f in anims[k]!) {
      frames[f] = const AtlasFrame(
          src: Rect.fromLTWH(0, 0, 1, 1),
          sourceSize: Size(1, 1),
          trimOffset: Offset.zero,
          pivot: Offset(0.5, 1));
    }
  });
  return AtlasData(frames, anims);
}

void main() {
  group('catalog names exist in the pack', () {
    test('town hall spreads 45 stages over the build-up frames', () {
      final a = _atlas('town_hall_idle_upgrade');
      final seen = <String>{};
      for (var s = 0; s <= 44; s++) {
        final f = Catalog.townHall(a, s);
        expect(f, isNotNull, reason: 'stage $s');
        seen.add(f!);
      }
      expect(seen.length, greaterThan(30));
      expect(Catalog.townHall(a, 0), isNot(Catalog.townHall(a, 44)));
      expect(Catalog.townHall(a, 999), Catalog.townHall(a, 44));
    });

    test('gold mine has four tiers of 16', () {
      final a = _atlas('resource_extractors');
      for (final g in Catalog.goldMineGroups) {
        expect(a.group(g), hasLength(16), reason: g);
      }
      expect(Catalog.goldMine(a, 0), isNotNull);
      expect(Catalog.goldMine(a, 63), isNotNull);
      expect(Catalog.goldMine(a, 0), isNot(Catalog.goldMine(a, 63)));
    });

    test('record tower has the eight levels the engine counts', () {
      final a = _atlas('record_tower');
      expect(a.anim('levels'), hasLength(WorldConfig.towerThresholds.length));
      expect(Catalog.recordTower(a, 1), isNot(Catalog.recordTower(a, 8)));
      expect(Catalog.recordTower(a, 99), Catalog.recordTower(a, 8));
      expect(Catalog.recordFx(a, 0), isNotNull);
      expect(Catalog.recordBanner(a, 0), isNotNull);
    });

    test('daily chest has eight fill stages', () {
      final a = _atlas('daily_chest');
      expect(a.anim('fill_stages'), hasLength(8));
      expect(Catalog.dailyChest(a, 7), isNot(Catalog.dailyChest(a, 0)));
    });

    test('walls, nature, landmarks, ground, icons', () {
      final walls = _atlas('walls');
      for (final g in Catalog.wallGroups) {
        expect(walls.group(g), isNotEmpty, reason: g);
      }
      final flora = _atlas('flora_rocks_resources');
      for (final g in [
        ...Catalog.treeGroups,
        Catalog.rockGroup,
        Catalog.bushGroup,
      ]) {
        expect(flora.group(g), isNotEmpty, reason: g);
      }
      final lm = _atlas('world_landmarks');
      for (final g in Catalog.landmarkGroups) {
        expect(lm.group(g), isNotEmpty, reason: g);
      }
      final grass = _atlas('terrain_grass_dirt_mud');
      for (final g in Catalog.grassGroups) {
        expect(grass.group(g), isNotEmpty, reason: g);
      }
      expect(_atlas('terrain_snow_ice_shadow').group(Catalog.snowGroup),
          isNotEmpty);
      expect(_atlas('terrain_snow_ice_shadow').group(Catalog.shadowGroup),
          isNotEmpty);
      expect(_atlas('terrain_volcanic_lava').group(Catalog.volcanicGroup),
          isNotEmpty);
      expect(Catalog.coinIcon(_atlas('ui_elements')), isNotNull);
      expect(_atlas('battlefield_scars').group('conquest_banners'),
          isNotEmpty);
      expect(_atlas('military_buildings').group('barracks_wood'), isNotEmpty);
      expect(_atlas('military_buildings').group('army_camp'), isNotEmpty);
    });
  });

  group('characters from the pack', () {
    final lib = CharacterLibrary.parse(
        File('test/fixtures/characters.json').readAsStringSync());

    test('the knight walks and idles on all four sides', () {
      for (final d in ['down', 'up', 'left', 'right']) {
        final w = lib.resolve('knight', 'walk', d)!;
        expect(w.atlasId, 'knight');
        expect(w.key, 'walk_$d');
        expect(w.flipX, isFalse);
        expect(lib.resolve('knight', 'idle', d)!.key, 'idle_$d');
      }
    });

    test('the barbarian uses its alternate takes where the plain one is missing',
        () {
      expect(lib.resolve('barbarian_v2', 'walk', 'down')!.key, 'walk_down_alt');
      expect(lib.resolve('barbarian_v2', 'walk', 'up')!.key, 'walk_up_alt');
      expect(lib.resolve('barbarian_v2', 'walk', 'left')!.key, 'walk_left');
      // idle is only drawn front and back; combat_idle has every side.
      expect(lib.resolve('barbarian_v2', 'combat_idle', 'right')!.key,
          'combat_idle_right');
    });

    test('goblin profile art faces right; left is the same flipped', () {
      final r = lib.resolve('goblin', 'walk', 'right')!;
      final l = lib.resolve('goblin', 'walk', 'left')!;
      expect(r.flipX, isFalse);
      expect(l.flipX, isTrue);
      expect(l.key, r.key);
    });

    test('the builder works and idles', () {
      expect(lib.has('builder', 'building'), isTrue);
      expect(lib.has('builder', 'idle'), isTrue);
      final left = lib.resolve('builder', 'building', 'left')!;
      expect(left.atlasId, 'builder');
      expect(left.flipX, isTrue); // side art is drawn facing right
      expect(lib.resolve('builder', 'building', 'down')!.flipX, isFalse);
    });

    test('archer walks toward the camera with its 3/4 view', () {
      expect(lib.resolve('archer', 'walk', 'down'), isNotNull);
    });

    test('the special characters and bosses are listed', () {
      for (final c in [
        'scout_reporter',
        'royal_monthly_herald',
        'wandering_merchant_walk',
        'hero_warlord_commander',
        'forest_guardian',
        'frost_lord',
      ]) {
        expect(lib.characters, contains(c));
      }
    });
  });
}
