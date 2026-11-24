import 'dart:math';

import 'catalog.dart';
import 'game_config.dart';
import 'models.dart';
import 'xp_curve.dart';

enum PurchaseStatus {
  ok,
  notFound,
  alreadyOwned,
  notForSale,
  insufficientGold,
  insufficientGems,
}

class PurchaseOutcome {
  const PurchaseOutcome(this.state, this.status, {this.missing = 0});
  final GameState state;
  final PurchaseStatus status;

  /// How much more of the currency was needed.
  final int missing;
  bool get ok => status == PurchaseStatus.ok;
}

enum UpgradeStatus {
  ok,
  notFound,
  alreadyUpgrading,
  maxLevel,
  keepTooLow,
  playerLevelTooLow,
  noBuilderFree,
  insufficientGold,
  insufficientGems,
  notUpgrading,
}

class UpgradeOutcome {
  const UpgradeOutcome(this.state, this.status);
  final GameState state;
  final UpgradeStatus status;
  bool get ok => status == UpgradeStatus.ok;
}

class ChestResult {
  const ChestResult({
    required this.state,
    required this.gold,
    required this.gems,
    this.itemId,
    this.duplicate = false,
  });

  final GameState state;

  /// Total gold/gems added (including duplicate conversion).
  final int gold;
  final int gems;
  final String? itemId;
  final bool duplicate;
}

enum RewardStatus { ok, notFound, insufficientGold }

class EconomyEngine {
  EconomyEngine._();

  // ---- Shop ----

  static PurchaseOutcome buy(GameState s, String itemId,
      {required bool useGems}) {
    final item = Catalog.byId[itemId];
    if (item == null) return PurchaseOutcome(s, PurchaseStatus.notFound);
    if (s.owned.contains(itemId)) {
      return PurchaseOutcome(s, PurchaseStatus.alreadyOwned);
    }
    final price = useGems ? item.gemPrice : item.goldPrice;
    if (price == null) return PurchaseOutcome(s, PurchaseStatus.notForSale);
    final balance = useGems ? s.gems : s.gold;
    if (balance < price) {
      return PurchaseOutcome(
        s,
        useGems
            ? PurchaseStatus.insufficientGems
            : PurchaseStatus.insufficientGold,
        missing: price - balance,
      );
    }
    return PurchaseOutcome(
      s.copyWith(
        gold: useGems ? s.gold : s.gold - price,
        gems: useGems ? s.gems - price : s.gems,
        owned: {...s.owned, itemId},
      ),
      PurchaseStatus.ok,
    );
  }

  /// Returns null if the item does not exist or is not owned.
  static GameState? equip(GameState s, String itemId) {
    final item = Catalog.byId[itemId];
    if (item == null || !s.owned.contains(itemId)) return null;
    return s.copyWith(equipped: {...s.equipped, item.slot: itemId});
  }

  // ---- Custom rewards ----

  static GameState addCustomReward(
          GameState s, String id, String title, int priceGold) =>
      s.copyWith(customRewards: [
        ...s.customRewards,
        CustomReward(id: id, title: title, priceGold: priceGold),
      ]);

  static GameState deleteCustomReward(GameState s, String id) => s.copyWith(
      customRewards: s.customRewards.where((r) => r.id != id).toList());

  static (GameState, RewardStatus) redeemCustomReward(GameState s, String id) {
    final i = s.customRewards.indexWhere((r) => r.id == id);
    if (i < 0) return (s, RewardStatus.notFound);
    final r = s.customRewards[i];
    if (s.gold < r.priceGold) return (s, RewardStatus.insufficientGold);
    final list = [...s.customRewards];
    list[i] = r.copyWith(timesRedeemed: r.timesRedeemed + 1);
    return (
      s.copyWith(gold: s.gold - r.priceGold, customRewards: list),
      RewardStatus.ok
    );
  }

  // ---- Buildings ----

  /// Gold cost to reach [targetLevel]: round10(100 * 1.6^(L-1)).
  static int upgradeCost(int targetLevel) {
    final x = 100 * pow(1.6, targetLevel - 1) / 10;
    return (x + 0.5).floor() * 10;
  }

  /// Work days needed to reach [targetLevel]: 1 to 5.
  static int workDaysFor(int targetLevel) => min(5, (targetLevel + 1) ~/ 2);

  /// Parallel upgrades allowed by the Builder's Hut.
  static int builderSlots(GameState s) {
    final l = s.buildingLevel('builders_hut');
    return 1 + (l >= 5 ? 1 : 0) + (l >= 10 ? 1 : 0);
  }

  static int busyBuilders(GameState s) =>
      s.buildings.values.where((b) => b.upgrading).length;

  /// Player level needed to raise the Keep to [targetLevel].
  static int keepPlayerLevelRequirement(int targetLevel) => 5 * targetLevel;

  /// Days of work done on the current upgrade (active days + skipped days).
  static int progressDays(GameState s, String id) {
    final b = s.building(id);
    final start = b.upgradeStartKey;
    if (start == null) return 0;
    final days = {
      for (final c in s.completions)
        if (c.dateKey.compareTo(start) >= 0) c.dateKey
    };
    return days.length + b.skippedDays;
  }

  static int daysLeft(GameState s, String id) {
    final b = s.building(id);
    if (!b.upgrading) return 0;
    return max(0, b.workDaysNeeded - progressDays(s, id));
  }

  static UpgradeOutcome startUpgrade(GameState s, String id, DateTime now) {
    if (!Catalog.buildingById.containsKey(id)) {
      return UpgradeOutcome(s, UpgradeStatus.notFound);
    }
    final b = s.building(id);
    if (b.upgrading) return UpgradeOutcome(s, UpgradeStatus.alreadyUpgrading);
    final target = b.level + 1;
    if (target > GameConfig.maxBuildingLevel) {
      return UpgradeOutcome(s, UpgradeStatus.maxLevel);
    }
    if (id == 'keep') {
      if (XpCurve.levelForXp(s.totalXp) < keepPlayerLevelRequirement(target)) {
        return UpgradeOutcome(s, UpgradeStatus.playerLevelTooLow);
      }
    } else if (target > s.buildingLevel('keep')) {
      return UpgradeOutcome(s, UpgradeStatus.keepTooLow);
    }
    if (busyBuilders(s) >= builderSlots(s)) {
      return UpgradeOutcome(s, UpgradeStatus.noBuilderFree);
    }
    final cost = upgradeCost(target);
    if (s.gold < cost) return UpgradeOutcome(s, UpgradeStatus.insufficientGold);
    return UpgradeOutcome(
      s.copyWith(
        gold: s.gold - cost,
        buildings: {
          ...s.buildings,
          id: BuildingState(
            level: b.level,
            upgradeTarget: target,
            upgradeStartKey: dateKeyOf(now),
            workDaysNeeded: workDaysFor(target),
          ),
        },
      ),
      UpgradeStatus.ok,
    );
  }

  /// Spends 1 gem per remaining work day to finish the upgrade now.
  static UpgradeOutcome skipDays(GameState s, String id) {
    final b = s.building(id);
    if (!b.upgrading) return UpgradeOutcome(s, UpgradeStatus.notUpgrading);
    final left = daysLeft(s, id);
    if (s.gems < left) return UpgradeOutcome(s, UpgradeStatus.insufficientGems);
    final next = s.copyWith(
      gems: s.gems - left,
      buildings: {...s.buildings, id: b.copyWith(skippedDays: b.skippedDays + left)},
    );
    return UpgradeOutcome(settleBuildings(next), UpgradeStatus.ok);
  }

  /// Finishes every upgrade whose work days are done. Safe to call anytime.
  static GameState settleBuildings(GameState s) {
    var buildings = s.buildings;
    for (final e in s.buildings.entries) {
      final b = e.value;
      if (!b.upgrading) continue;
      if (progressDays(s, e.key) >= b.workDaysNeeded) {
        buildings = {
          ...buildings,
          e.key: b.copyWith(level: b.upgradeTarget, clearUpgrade: true),
        };
      }
    }
    return identical(buildings, s.buildings)
        ? s
        : s.copyWith(buildings: buildings);
  }

  // ---- Chests ----

  /// Opens one chest of [type]. Returns null if none is held.
  static ChestResult? openChest(GameState s, String type, Random rng) {
    final def = Catalog.chests[type];
    final idx = s.chests.indexOf(type);
    if (def == null || idx < 0) return null;
    final chests = [...s.chests]..removeAt(idx);

    var gold = def.goldMin + rng.nextInt(def.goldMax - def.goldMin + 1);
    var gems = def.gemsMin + rng.nextInt(def.gemsMax - def.gemsMin + 1);
    var owned = s.owned;
    String? itemId;
    var duplicate = false;

    final roll = rng.nextInt(100);
    var acc = 0;
    ItemRarity? hit;
    for (final (rarity, pct) in def.drops) {
      acc += pct;
      if (roll < acc) {
        hit = rarity;
        break;
      }
    }
    if (hit != null) {
      final pool = Catalog.items
          .where((i) =>
              i.type == ItemType.character && i.forSale && i.rarity == hit)
          .toList();
      if (pool.isNotEmpty) {
        final item = pool[rng.nextInt(pool.length)];
        itemId = item.id;
        if (owned.contains(item.id)) {
          duplicate = true;
          if (item.goldPrice != null) {
            gold += item.goldPrice! ~/ 2;
          } else {
            gems += item.gemPrice! ~/ 2;
          }
        } else {
          owned = {...owned, item.id};
        }
      }
    }

    return ChestResult(
      state: s.copyWith(
        gold: s.gold + gold,
        gems: s.gems + gems,
        chests: chests,
        owned: owned,
      ),
      gold: gold,
      gems: gems,
      itemId: itemId,
      duplicate: duplicate,
    );
  }
}
