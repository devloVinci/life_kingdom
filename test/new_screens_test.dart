import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/core/widgets/character_rig.dart';
import 'package:life_kingdom/core/widgets/game_button.dart';
import 'package:life_kingdom/main.dart';

void main() {
  setUpAll(() {
    AppText.useGoogleFonts = false;
    CharacterRig.enableAnimation = false;
  });

  Future<ProviderContainer> boot(WidgetTester tester, GameState s) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(InMemoryGameRepository()),
        initialGameStateProvider.overrideWithValue(s),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 9)),
      ],
      child: const LifeKingdomApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  }

  testWidgets('hero collection, detail, equip and companions', (tester) async {
    final c = await boot(tester, const GameState());

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(GameButton, 'Heroes'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 15'), findsOneWidget);

    // Owned hero: detail with animations, make it a companion.
    await tester.tap(find.text('Raider'));
    await tester.pumpAndSettle();
    expect(find.text('Animations'), findsOneWidget);
    await tester.tap(find.byKey(const Key('anim_walk')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('companion_button')));
    await tester.pumpAndSettle();
    expect(c.read(gameProvider).companions, ['char_raider']);
    await back(tester);

    // Locked hero: shows the price and a Buy button.
    await tester.tap(find.text('Archer'));
    await tester.pumpAndSettle();
    expect(find.text('Locked'), findsOneWidget);
    expect(find.byKey(const Key('buy_button')), findsOneWidget);
    await back(tester);
    await back(tester);

    // Companions screen lists it and can remove it.
    await tester.tap(find.widgetWithText(GameButton, 'Companions'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('remove_char_raider')));
    await tester.pumpAndSettle();
    expect(c.read(gameProvider).companions, isEmpty);
    expect(find.byKey(const Key('empty_slot')), findsOneWidget);
  });

  testWidgets('quest detail opens from the list', (tester) async {
    await boot(tester, const GameState());
    await tester.tap(find.text('Quests').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Triple Threat'));
    await tester.pumpAndSettle();
    expect(find.text('Rewards'), findsOneWidget);
    expect(find.byKey(const Key('quest_progress')), findsOneWidget);
    await back(tester);
    expect(find.text('Triple Threat'), findsOneWidget);
  });

  testWidgets('shop preview sheet opens for styles', (tester) async {
    await boot(tester, const GameState(gold: 5000));
    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Style'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('item_bg_meadow')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('preview_buy')), findsOneWidget);
  });
}
