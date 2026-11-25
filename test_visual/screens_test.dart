// Screenshot test for reviewing the look of the app (not run by `flutter
// test`). Run with:  flutter test --update-goldens test_visual
// The PNGs land in test_visual/goldens/.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/characters/rig_data.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
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

GameState _state({Map<String, String> equipped = const {}}) => GameState(
      playerName: 'Khash',
      totalXp: 2600,
      gold: 1240,
      gems: 18,
      habits: const [
        Habit(id: 'h1', title: 'Read 20 pages'),
        Habit(id: 'h2', title: 'Workout'),
        Habit(id: 'h3', title: 'Arabic poetry'),
      ],
      owned: {
        ...GameState.defaultOwned,
        'char_archer',
        'char_sorcerer',
        'season_winter',
        'season_autumn',
        'season_spring',
        'dragon_frost',
        'ui_arcane',
      },
      equipped: {'character': 'char_raider', ...equipped},
      chests: const ['silver', 'golden'],
    );

void main() {
  setUpAll(() async {
    AppText.useGoogleFonts = false;
    CharacterRig.enableAnimation = false;
    await _loadFonts();
  });

  Future<void> shot(WidgetTester tester, String name, GameState s,
      {Future<void> Function(WidgetTester)? before}) async {
    RigData.clearCache();
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

  for (final season in ['summer', 'spring', 'autumn', 'winter']) {
    testWidgets('home $season', (t) => shot(t, 'home_$season', _state(equipped: {'season': 'season_$season'})));
  }
  testWidgets('home ivory', (t) => shot(t, 'home_ivory_ui', _state(equipped: {'uiTheme': 'ui_ivory', 'season': 'season_autumn'})));
  testWidgets('home classic', (t) => shot(t, 'home_classic_ui', _state(equipped: {'uiTheme': 'ui_classic'})));
  testWidgets('zoom on hero', (t) => shot(t, 'home_zoom', _state(equipped: {'dragonSkin': 'dragon_frost'}), before: (t) async {
        await t.tap(find.byKey(const Key('map_recenter')));
      }));
  testWidgets('overview', (t) => shot(t, 'home_overview', _state(equipped: {'season': 'season_spring'}), before: (t) async {
        await t.tap(find.byKey(const Key('map_overview')));
      }));
  for (final ui in ['ui_obsidian', 'ui_ivory', 'ui_arcane']) {
    testWidgets('shop world $ui', (t) => shot(t, 'shop_world_$ui', _state(equipped: {'uiTheme': ui}), before: (t) async {
          await t.tap(find.text('Shop').last);
          await _settle(t);
          await t.tap(find.text('World'));
        }));
  }
  testWidgets('habits obsidian', (t) => shot(t, 'habits_obsidian', _state(), before: (t) async {
        await t.tap(find.text('Today').last);
      }));
  testWidgets('quests ivory', (t) => shot(t, 'quests_ivory', _state(equipped: {'uiTheme': 'ui_ivory'}), before: (t) async {
        await t.tap(find.text('Quests').last);
      }));
}
