// Screenshots of the tile-world home for review (not run by `flutter
// test`). Run with:  flutter test --update-goldens test_visual
// The PNGs land in test_visual/goldens/.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/world_growth.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/core/widgets/character_rig.dart';
import 'package:life_kingdom/main.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '';
  final dir = '$root/bin/cache/artifacts/material_fonts';
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var any = false;
    for (final f in files) {
      final file = File('$dir/$f');
      if (!file.existsSync()) continue;
      any = true;
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
    }
    if (any) await loader.load();
  }

  const roboto = ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf'];
  for (final fam in ['Inter', 'Cinzel', 'Nunito', 'LilitaOne', 'Roboto']) {
    await load(fam, roboto);
  }
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// A save where the first [count] lands are already open (no reveal plays).
GameState _grown(int count, {int completions = 0}) => GameState(
      playerName: 'Khash',
      totalXp: 2600,
      gold: 1240,
      gems: 18,
      habits: const [Habit(id: 'h1', title: 'Read 20 pages')],
      completions: [
        for (var i = 0; i < completions; i++)
          Completion(habitId: 'h1', dateKey: '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}', xp: 0, gold: 0),
      ],
      settings: {
        for (final m in WorldGrowth.milestones.take(count))
          '${WorldGrowth.seenPrefix}${m.id}': true,
      },
    );

void main() {
  setUpAll(() async {
    AppText.useGoogleFonts = false;
    CharacterRig.enableAnimation = false;
    await _loadFonts();
  });

  Future<void> shot(WidgetTester tester, String name, GameState s,
      {Future<void> Function(WidgetTester)? before}) async {
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(InMemoryGameRepository()),
        initialGameStateProvider.overrideWithValue(s),
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 25, 9)),
      ],
      child: const LifeKingdomApp(),
    ));
    await _settle(tester);
    if (before != null) {
      await before(tester);
      await _settle(tester);
    }
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('tile world: new player', (t) => shot(t, 'tile_world_0', const GameState(playerName: 'Khash')));
  testWidgets('tile world: some land', (t) => shot(t, 'tile_world_5', _grown(5)));
  testWidgets('tile world: whole valley', (t) => shot(t, 'tile_world_12', _grown(12)));
  testWidgets('tile world: land just opened', (t) => shot(t, 'tile_world_reveal', _grown(0, completions: 1)));
  testWidgets('land journal', (t) => shot(t, 'land_journal', _grown(3), before: (t) async {
        await t.tap(find.byKey(const Key('next_land_card')));
      }));
}
