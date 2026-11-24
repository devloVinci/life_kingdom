import 'dart:math';

import 'catalog.dart';
import 'models.dart';

enum CompanionStatus { ok, notOwned, full, already, notCompanion }

class CompanionOutcome {
  const CompanionOutcome(this.status, this.state);

  final CompanionStatus status;
  final GameState state;
  bool get ok => status == CompanionStatus.ok;
}

/// Companions: owned heroes that accompany the player. The Army Camp level
/// decides how many can be active at once.
class CompanionEngine {
  CompanionEngine._();

  static const maxSlots = 5;

  /// Army Camp level 1 -> 1 slot, 3 -> 2, 5 -> 3, 7 -> 4, 9 -> 5.
  static int slots(GameState s) =>
      min(maxSlots, 1 + (s.buildingLevel('army_camp') - 1) ~/ 2);

  /// Level at which the next slot opens, or null when all are unlocked.
  static int? nextSlotLevel(GameState s) {
    final n = slots(s);
    return n >= maxSlots ? null : 2 * n + 1;
  }

  static CompanionOutcome add(GameState s, String id) {
    final item = Catalog.byId[id];
    if (item == null || item.type != ItemType.character || !s.owned.contains(id)) {
      return CompanionOutcome(CompanionStatus.notOwned, s);
    }
    if (s.companions.contains(id)) {
      return CompanionOutcome(CompanionStatus.already, s);
    }
    if (s.companions.length >= slots(s)) {
      return CompanionOutcome(CompanionStatus.full, s);
    }
    return CompanionOutcome(
        CompanionStatus.ok, s.copyWith(companions: [...s.companions, id]));
  }

  static CompanionOutcome remove(GameState s, String id) {
    if (!s.companions.contains(id)) {
      return CompanionOutcome(CompanionStatus.notCompanion, s);
    }
    return CompanionOutcome(CompanionStatus.ok,
        s.copyWith(companions: s.companions.where((c) => c != id).toList()));
  }
}
