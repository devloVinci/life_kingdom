import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/characters/rig_data.dart';
import 'package:life_kingdom/core/world/world_layout.dart';
import 'package:life_kingdom/core/game/catalog.dart';
import 'package:life_kingdom/core/game/economy_engine.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/theme/ui_palette.dart';
import 'package:life_kingdom/core/world/season.dart';

void main() {
  test('old saves keep their data and gain the starter cosmetics', () {
    final old = const GameState(
      gold: 40,
      owned: {'char_raider', 'char_builder', 'bg_sunset'},
    ).toJson();
    final s = GameState.fromJson(old);
    expect(s.owned, containsAll(['bg_sunset', ...Catalog.starterIds]));
    expect(s.gold, 40);
  });

  test('every season, UI theme and dragon skin has a catalog item', () {
    for (final p in UiPalette.all) {
      expect(Catalog.byId[p.id]?.type, ItemType.uiTheme, reason: p.id);
    }
    for (final s in SeasonPack.all) {
      expect(Catalog.byId[s.id]?.type, ItemType.season, reason: s.id);
    }
    for (final id in ['ember', 'frost', 'verdant', 'shadow', 'gilded']) {
      expect(Catalog.byId['dragon_$id']?.type, ItemType.dragonSkin);
    }
  });

  test('cosmetics are bought once with earned currency and equipped by slot',
      () {
    var s = const GameState(gold: 1000);
    final o = EconomyEngine.buy(s, 'season_winter', useGems: false);
    expect(o.ok, isTrue);
    s = o.state;
    expect(s.gold, 100);
    // No duplicate purchase.
    expect(EconomyEngine.buy(s, 'season_winter', useGems: false).status,
        PurchaseStatus.alreadyOwned);
    s = EconomyEngine.equip(s, 'season_winter')!;
    expect(s.equipped['season'], 'season_winter');
    // Changing the season leaves the UI theme alone.
    s = EconomyEngine.equip(s, 'ui_ivory')!;
    expect(s.equipped['season'], 'season_winter');
    expect(s.equipped['uiTheme'], 'ui_ivory');
    // Unowned items cannot be equipped.
    expect(EconomyEngine.equip(s, 'dragon_gilded'), isNull);
  });

  test('starter cosmetics are free and never for sale', () {
    for (final id in Catalog.starterIds) {
      expect(Catalog.byId[id]!.forSale, isFalse, reason: id);
    }
  });

  test('hero and dragon rigs have every part and pivot', () {
    for (final slug in [
      'warden',
      'dragon_ember',
      'dragon_frost',
      'dragon_verdant',
      'dragon_shadow',
      'dragon_gilded',
    ]) {
      final dir = Directory('assets/characters/$slug');
      final rig = RigData.fromJson(
          jsonDecode(File('${dir.path}/rig.json').readAsStringSync())
              as Map<String, dynamic>);
      expect(rig.parts.length, greaterThanOrEqualTo(8), reason: slug);
      for (final p in rig.parts) {
        expect(File('${dir.path}/${p.file}').existsSync(), isTrue, reason: '$slug/${p.file}');
        expect(rig.pivots.containsKey(p.role), isTrue, reason: '$slug ${p.role}');
      }
    }
  });

  test('every building on the map has art and a winter overlay', () {
    for (final id in WorldLayout.buildings.keys) {
      expect(File('assets/buildings/$id.svg').existsSync(), isTrue, reason: id);
      expect(File('assets/buildings/${id}_snow.svg').existsSync(), isTrue, reason: id);
    }
  });

  test('world layout keeps decor off roads and buildings', () {
    expect(WorldLayout.decor, isNotEmpty);
    for (final d in WorldLayout.decor) {
      expect((d.pos - WorldLayout.plaza).distance, greaterThan(WorldLayout.plazaRadius),
          reason: '$d');
    }
    // Regions unlock in order.
    final levels = [for (final r in WorldLayout.regions) r.unlockLevel];
    expect(levels, orderedEquals([...levels]..sort()));
  });
}
