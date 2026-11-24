import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/widgets/character_rig.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/core/widgets/game_button.dart';
import 'package:life_kingdom/main.dart';

void main() {
  setUpAll(() {
    AppText.useGoogleFonts = false;
    CharacterRig.enableAnimation = false;
  });

  testWidgets('every main screen builds and backup restore works',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = InMemoryGameRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(repo),
        initialGameStateProvider.overrideWithValue(const GameState()),
        clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 9)),
      ],
      child: const LifeKingdomApp(),
    ));
    await tester.pumpAndSettle();

    Future<void> back() async {
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }

    // Quests tab.
    await tester.tap(find.text('Quests').last);
    await tester.pumpAndSettle();
    expect(find.text('Triple Threat'), findsOneWidget);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(find.text('Steady Week'), findsOneWidget);
    await tester.tap(find.text('Special'));
    await tester.pumpAndSettle();
    expect(find.text('30-Day Challenge'), findsOneWidget);

    // Shop tab (all three tabs).
    await tester.tap(find.text('Shop').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Style'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.text('Your own rewards'), findsOneWidget);

    // Profile and sub screens.
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Ranks'), findsOneWidget);

    await tester.tap(find.widgetWithText(GameButton, 'Achievements'));
    await tester.pumpAndSettle();
    expect(find.text('First Step'), findsOneWidget);
    await back();

    await tester.tap(find.widgetWithText(GameButton, 'Calendar & Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Last 7 days'), findsOneWidget);
    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();
    expect(find.text('No habits completed'), findsOneWidget);
    await back();

    await tester.tap(find.widgetWithText(GameButton, 'Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    // Restore a backup that has 777 gold.
    await tester.tap(find.widgetWithText(GameButton, 'Restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import_field')),
        jsonEncode(const GameState(gold: 777).toJson()));
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    expect((await repo.load()).gold, 777);

    // Invalid backup is rejected and does not change data.
    await tester.tap(find.widgetWithText(GameButton, 'Restore'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('import_field')), 'not json');
    await tester.tap(find.widgetWithText(TextButton, 'Restore'));
    await tester.pumpAndSettle();
    expect((await repo.load()).gold, 777);
  });
}
