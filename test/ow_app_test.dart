import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/features/ow/kingdom/kingdom_screen.dart';
import 'package:life_kingdom/main.dart';

void main() {
  setUpAll(() {
    AppText.useGoogleFonts = false;
    SceneClock.enabled = false;
  });

  testWidgets('tabs build and a task can be added and finished',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final repo = InMemoryGameRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        initialGameStateProvider.overrideWithValue(const GameState()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 5, 9)),
      ],
      child: const LifeKingdomApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kingdom_scene')), findsOneWidget);
    expect(find.byKey(const Key('hud_level')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('world_scene')), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add_item')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add_title')), 'كتابة التقرير');
    await tester.tap(find.byKey(const Key('add_save')));
    await tester.pumpAndSettle();
    expect(find.text('كتابة التقرير'), findsOneWidget);

    await tester.tap(find.text('كتابة التقرير'));
    await tester.pumpAndSettle();
    final s = (await repo.load());
    expect(s.tasks.single.done, isTrue);
    expect(s.world.supplies, greaterThan(0));
    expect(s.world.pendingHarvest, greaterThan(0));

    await tester.tap(find.byKey(const Key('tab_3')));
    await tester.pumpAndSettle();
    expect(find.text('برج الأرقام القياسية'), findsOneWidget);
  });
}
