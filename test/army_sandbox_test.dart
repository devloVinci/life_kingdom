import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/world_engine.dart';
import 'package:life_kingdom/core/game/xp_curve.dart';

void main() {
  test('training costs gold + supplies and respects the camp', () {
    var s = const GameState(gold: 1000, world: WorldState(supplies: 100));
    final (t, st) = ArmyEngine.train(s, 'archer', 2);
    expect(st, TrainStatus.ok);
    expect(t.gold, 1000 - 120);
    expect(t.world.supplies, 80);
    expect(t.world.army['archer'], 2);
    expect(ArmyEngine.armyPower(t), ArmyEngine.heroPower(1) + 4);

    s = s.copyWith(gold: 10);
    expect(ArmyEngine.train(s, 'barbarian', 1).$2, TrainStatus.noGold);
    s = const GameState(gold: 99999, world: WorldState(supplies: 99999));
    expect(ArmyEngine.train(s, 'barbarian', 99).$2, TrainStatus.campFull);
  });

  test('landmarks: hidden until revealed, need power and supplies', () {
    final far = ArmyEngine.landmarks.last;
    final near = ArmyEngine.landmarks.first;
    expect(near.distance, lessThan(far.distance));

    var s = GameState(
        totalXp: XpCurve.xpForLevel(100),
        world: const WorldState(supplies: 0));
    expect(ArmyEngine.capture(s, near.id).$2, CaptureStatus.noSupplies);

    s = const GameState(world: WorldState(supplies: 999));
    expect(ArmyEngine.capture(s, far.id).$2, CaptureStatus.notRevealed);

    s = GameState(
        totalXp: XpCurve.xpForLevel(100),
        world: const WorldState(supplies: 999));
    final (taken, st) = ArmyEngine.capture(s, near.id);
    expect(st, CaptureStatus.ok);
    expect(taken.world.captured, contains(near.id));
    expect(taken.gold, near.goldReward);
    expect(ArmyEngine.capture(taken, near.id).$2, CaptureStatus.already);
  });

  test('sandbox edits never touch the real save', () async {
    final real = InMemoryGameRepository();
    final box = InMemoryGameRepository();
    await real.save(const GameState(gold: 7));
    final c = ProviderContainer(overrides: [
      gameRepositoryProvider.overrideWithValue(real),
      sandboxRepositoryProvider.overrideWithValue(box),
      initialGameStateProvider.overrideWithValue(const GameState(gold: 7)),
      clockProvider.overrideWithValue(() => DateTime(2026, 1, 5, 9)),
    ]);
    addTearDown(c.dispose);
    final game = c.read(gameProvider.notifier);

    game.sandboxEdit((s) => s.copyWith(gold: 999)); // ignored outside
    expect(c.read(gameProvider).gold, 7);

    await game.enterSandbox(copyReal: true);
    expect(c.read(sandboxModeProvider), isTrue);
    game.sandboxEdit((s) => s.copyWith(gold: 5000));
    game.sandboxJumpDays(3);
    expect(c.read(gameProvider).gold, 5000);
    expect(c.read(nowProvider)().day, 8);
    expect((await real.load()).gold, 7);
    expect((await box.load()).gold, 5000);

    await game.exitSandbox();
    expect(c.read(sandboxModeProvider), isFalse);
    expect(c.read(gameProvider).gold, 7);
    expect(c.read(nowProvider)().day, 5);
  });
}
