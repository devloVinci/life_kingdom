import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/main.dart';

void main() {
  setUpAll(() => AppText.useGoogleFonts = false);

  testWidgets('create a habit, complete it, see level up', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
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

    // Empty state on the home screen.
    await tester.tap(find.text('Create your first habit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('habit_title')), 'Read');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Go to the habits tab and complete it.
    await tester.tap(find.text('Habits').last);
    await tester.pumpAndSettle();
    expect(find.text('Read'), findsOneWidget);

    await tester.tap(find.byKey(const Key('complete_button')));
    await tester.pumpAndSettle();
    expect(find.text('LEVEL UP!'), findsOneWidget);

    final saved = await repo.load();
    expect(saved.completions, hasLength(1));
    expect(saved.totalXp, 20);
  });
}
