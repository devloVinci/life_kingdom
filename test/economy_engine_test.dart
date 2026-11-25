import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/game/catalog.dart';
import 'package:life_kingdom/core/game/economy_engine.dart';
import 'package:life_kingdom/core/game/game_engine.dart';
import 'package:life_kingdom/core/game/models.dart';

/// Feeds predetermined values to nextInt (each taken modulo max).
class FixedRandom implements Random {
  FixedRandom(this.values);
  final List<int> values;
  var _i = 0;

  @override
  int nextInt(int max) => values[_i++] % max;

  @override
  bool nextBool() => throw UnimplementedError();
  @override
  double nextDouble() => throw UnimplementedError();
}

DateTime day(int n) => DateTime(2026, 1, n, 9);

GameState withHabit([GameState base = const GameState()]) =>
    GameEngine.addHabit(base, const Habit(id: 'h1', title: 'Read'));

GameState doDay(GameState s, int n) =>
    GameEngine.complete(s, 'h1', day(n)).state;

void main() {
  group('shop', () {
    test('buy with gold', () {
      final o = EconomyEngine.buy(const GameState(gold: 500), 'char_archer',
          useGems: false);
      expect(o.ok, isTrue);
      expect(o.state.gold, 300);
      expect(o.state.owned, contains('char_archer'));
    });

    test('insufficient gold reports how much is missing', () {
      final o = EconomyEngine.buy(const GameState(gold: 150), 'char_archer',
          useGems: false);
      expect(o.status, PurchaseStatus.insufficientGold);
      expect(o.missing, 50);
      expect(o.state.gold, 150);
    });

    test('epic can be bought with gems, legendary only with gems', () {
      final epic = EconomyEngine.buy(const GameState(gems: 30), 'char_drake',
          useGems: true);
      expect(epic.ok, isTrue);
      expect(epic.state.gems, 0);
      final leg = EconomyEngine.buy(const GameState(gold: 99999),
          'char_warlord', useGems: false);
      expect(leg.status, PurchaseStatus.notForSale);
    });

    test('already owned and unknown items', () {
      expect(
          EconomyEngine.buy(const GameState(gold: 999), 'char_raider',
                  useGems: false)
              .status,
          PurchaseStatus.alreadyOwned);
      expect(
          EconomyEngine.buy(const GameState(), 'nope', useGems: false).status,
          PurchaseStatus.notFound);
    });

    test('equip requires ownership', () {
      expect(EconomyEngine.equip(const GameState(), 'char_archer'), isNull);
      final s = EconomyEngine.buy(const GameState(gold: 500), 'char_archer',
              useGems: false)
          .state;
      final e = EconomyEngine.equip(s, 'char_archer')!;
      expect(e.equipped['character'], 'char_archer');
    });
  });

  group('custom rewards', () {
    test('add, redeem, delete', () {
      var s = EconomyEngine.addCustomReward(
          const GameState(gold: 300), 'r1', 'Ice cream', 120);
      final (s2, st) = EconomyEngine.redeemCustomReward(s, 'r1');
      expect(st, RewardStatus.ok);
      expect(s2.gold, 180);
      expect(s2.customRewards.single.timesRedeemed, 1);
      final (_, st2) = EconomyEngine.redeemCustomReward(
          s2.copyWith(gold: 10), 'r1');
      expect(st2, RewardStatus.insufficientGold);
      s = EconomyEngine.deleteCustomReward(s2, 'r1');
      expect(s.customRewards, isEmpty);
    });
  });

  group('buildings', () {
    test('costs and work days follow the rules', () {
      expect(EconomyEngine.upgradeCost(2), 160);
      expect(EconomyEngine.upgradeCost(3), 260);
      expect(EconomyEngine.upgradeCost(10), 6870);
      expect([for (var l = 2; l <= 10; l++) EconomyEngine.workDaysFor(l)],
          [1, 2, 2, 3, 3, 4, 4, 5, 5]);
    });

    test('upgrade finishes only after active days of work', () {
      var s = withHabit(const GameState(gold: 1000, totalXp: 6255));
      // Keep level 1 caps others at level 1 -> raise keep first.
      final start =
          EconomyEngine.startUpgrade(s, 'keep', day(1)); // needs player lvl 10
      expect(start.ok, isTrue);
      s = start.state;
      expect(s.gold, 1000 - 160);
      expect(EconomyEngine.daysLeft(s, 'keep'), 1);
      expect(s.buildingLevel('keep'), 1);

      s = EconomyEngine.settleBuildings(s);
      expect(s.buildingLevel('keep'), 1); // no work yet

      s = doDay(s, 1);
      s = EconomyEngine.settleBuildings(s);
      expect(s.buildingLevel('keep'), 2);
      expect(s.building('keep').upgrading, isFalse);
    });

    test('inactive days do not advance work', () {
      var s = withHabit(const GameState(gold: 5000, totalXp: 6255));
      s = EconomyEngine.startUpgrade(s, 'keep', day(1)).state;
      s = doDay(s, 1);
      s = EconomyEngine.settleBuildings(s);
      expect(s.buildingLevel('keep'), 2);
      // Level 3 needs 2 work days, and player level 15 (5 * 3).
      s = s.copyWith(totalXp: 12000);
      s = EconomyEngine.startUpgrade(s, 'keep', day(2)).state;
      expect(EconomyEngine.daysLeft(s, 'keep'), 2);
      s = doDay(s, 2);
      expect(EconomyEngine.daysLeft(s, 'keep'), 1);
      // Day 3 and 4 skipped: still 1 left.
      s = doDay(s, 5);
      s = EconomyEngine.settleBuildings(s);
      expect(s.buildingLevel('keep'), 3);
    });

    test('keep gating and player level requirement', () {
      const s = GameState(gold: 5000);
      expect(EconomyEngine.startUpgrade(s, 'treasury', day(1)).status,
          UpgradeStatus.keepTooLow);
      expect(EconomyEngine.startUpgrade(s, 'keep', day(1)).status,
          UpgradeStatus.playerLevelTooLow);
    });

    test('only one builder at level 1 hut', () {
      var s = const GameState(
          gold: 5000, totalXp: 6255, buildings: {'keep': BuildingState(level: 3)});
      s = EconomyEngine.startUpgrade(s, 'treasury', day(1)).state;
      expect(EconomyEngine.busyBuilders(s), 1);
      expect(EconomyEngine.startUpgrade(s, 'laboratory', day(1)).status,
          UpgradeStatus.noBuilderFree);
      expect(EconomyEngine.builderSlots(s), 1);
      expect(
          EconomyEngine.builderSlots(const GameState(
              buildings: {'builders_hut': BuildingState(level: 5)})),
          2);
    });

    test('insufficient gold', () {
      const s = GameState(gold: 10, buildings: {'keep': BuildingState(level: 3)});
      expect(EconomyEngine.startUpgrade(s, 'treasury', day(1)).status,
          UpgradeStatus.insufficientGold);
    });

    test('skip days with gems', () {
      var s = const GameState(
          gold: 5000,
          gems: 5,
          buildings: {'keep': BuildingState(level: 5)});
      s = EconomyEngine.startUpgrade(s, 'treasury', day(1)).state;
      final left = EconomyEngine.daysLeft(s, 'treasury');
      expect(left, 1);
      final o = EconomyEngine.skipDays(s, 'treasury');
      expect(o.ok, isTrue);
      expect(o.state.gems, 4);
      expect(o.state.buildingLevel('treasury'), 2);
      expect(
          EconomyEngine.skipDays(o.state, 'treasury').status,
          UpgradeStatus.notUpgrading);
    });

    test('treasury raises gold from habits', () {
      var s = withHabit(const GameState(
          buildings: {'treasury': BuildingState(level: 6)})); // +10%
      final o = GameEngine.complete(s, 'h1', day(1));
      expect(o.goldGained, 11); // 10 * 1.10
    });
  });

  group('chests', () {
    test('opening consumes a chest and pays out (duplicate converts to gold)',
        () {
      const s = GameState(
        chests: ['wooden', 'silver'],
        owned: {'char_raider', 'char_builder', 'char_archer'},
      );
      // gold roll 0 -> 50, gems roll 0 -> 0, drop roll 0 (<5 -> common),
      // pick index 0 -> Archer (first common for sale), already owned.
      final r = EconomyEngine.openChest(s, 'wooden', FixedRandom([0, 0, 0, 0]))!;
      expect(r.state.chests, ['silver']);
      expect(r.duplicate, isTrue);
      expect(r.itemId, 'char_archer');
      expect(r.gold, 50 + 100); // 50% of the 200 gold price
      expect(r.state.gold, 150);
    });

    test('new character is added to the collection', () {
      const s = GameState(chests: ['wooden']);
      // pick index 1 -> Gremlin (not owned)
      final r = EconomyEngine.openChest(s, 'wooden', FixedRandom([0, 0, 0, 1]))!;
      expect(r.itemId, 'char_gremlin');
      expect(r.duplicate, isFalse);
      expect(r.state.owned, contains('char_gremlin'));
    });

    test('no item when the drop roll misses', () {
      const s = GameState(chests: ['wooden']);
      final r =
          EconomyEngine.openChest(s, 'wooden', FixedRandom([10, 1, 50]))!;
      expect(r.itemId, isNull);
      expect(r.gold, 60);
      expect(r.gems, 1);
    });

    test('missing chest returns null', () {
      expect(EconomyEngine.openChest(const GameState(), 'wooden', Random(1)),
          isNull);
    });
  });

  test('catalog sanity', () {
    final ids = Catalog.items.map((i) => i.id).toSet();
    expect(ids.length, Catalog.items.length); // unique ids
    expect(GameState.defaultOwned.every(ids.contains), isTrue);
    for (final i in Catalog.items.where((i) => i.type == ItemType.background)) {
      expect(i.gradient, hasLength(2));
    }
  });

  test('new economy fields survive a json roundtrip', () {
    final s = const GameState(
      gold: 5,
      owned: {'char_raider', 'char_archer'},
      equipped: {'character': 'char_archer'},
      buildings: {
        'keep': BuildingState(
            level: 2, upgradeTarget: 3, upgradeStartKey: '2026-01-02',
            workDaysNeeded: 2, skippedDays: 1)
      },
      customRewards: [CustomReward(id: 'r', title: 'Treat', priceGold: 50)],
    );
    final r = GameState.fromJson(s.toJson());
    // Starter cosmetics are merged in on load; nothing else changes.
    expect(r.owned, {...s.owned, ...Catalog.starterIds});
    expect(r.equipped['character'], 'char_archer');
    expect(r.building('keep').upgradeTarget, 3);
    expect(r.building('keep').skippedDays, 1);
    expect(r.customRewards.single.title, 'Treat');
  });
}
