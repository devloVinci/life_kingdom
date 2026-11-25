import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/app/providers.dart';
import 'package:life_kingdom/core/data/game_repository.dart';
import 'package:life_kingdom/core/game/models.dart';
import 'package:life_kingdom/core/game/world_growth.dart';
import 'package:life_kingdom/core/game/xp_curve.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/core/world/tile_map.dart';
import 'package:life_kingdom/features/kingdom/tile_world/land_journal.dart';
import 'package:life_kingdom/features/kingdom/tile_world/world_painter.dart';
import 'package:life_kingdom/features/kingdom/tile_world/world_props.dart';

final _now = DateTime(2026, 3, 10, 9);

List<Completion> _completions(int n) => [
      for (var i = 0; i < n; i++)
        Completion(habitId: 'h$i', dateKey: '2025-01-${(i % 28 + 1).toString().padLeft(2, '0')}', xp: 0, gold: 0),
    ];

void main() {
  group('WorldGrowth', () {
    test('a new player starts with only the clearing', () {
      final p = WorldGrowth.progress(const GameState(), _now);
      expect(p.count, 0);
      expect(p.next!.id, 'first_habit');
      expect(WorldGrowth.radiusFor(0), lessThan(4));
    });

    test('habits, tasks and levels each open land', () {
      final s = GameState(
        completions: _completions(10),
        tasks: const [TaskItem(id: 't', title: 'Call bank', doneKey: '2026-03-01')],
        totalXp: XpCurve.xpForLevel(4),
      );
      final p = WorldGrowth.progress(s, _now);
      expect(p.reached, containsAll(['first_habit', 'first_task', 'level_2', 'habits_10', 'level_4']));
      expect(p.reached, isNot(contains('streak_3')));
      expect(p.next!.id, 'streak_3');
    });

    test('best streak counts even after the streak breaks', () {
      const s = GameState(streak: StreakState(longest: 7));
      final p = WorldGrowth.progress(s, _now);
      expect(p.reached, containsAll(['streak_3', 'streak_7']));
    });

    test('land already seen stays open', () {
      const s = GameState(settings: {'world_seen_tasks_10': true});
      expect(WorldGrowth.progress(s, _now).reached, contains('tasks_10'));
    });

    test('radius grows with every milestone and covers the map at the end', () {
      for (var i = 1; i <= WorldGrowth.milestones.length; i++) {
        expect(WorldGrowth.radiusFor(i), greaterThan(WorldGrowth.radiusFor(i - 1)));
      }
      // Farthest map corner from home, in tiles, plus the soft edge.
      const far = Offset(0, 0);
      final d = (far - GrassLandLayout.home).distance / 32;
      expect(WorldGrowth.radiusFor(WorldGrowth.milestones.length), greaterThan(d + 2));
    });

    test('milestone ids are unique', () {
      expect(WorldGrowth.byId.length, WorldGrowth.milestones.length);
    });
  });

  group('fog', () {
    test('home is open, far land is hidden at the start', () {
      final r = WorldGrowth.radiusFor(0);
      expect(fogAlpha(GrassLandLayout.home, GrassLandLayout.home, r), 0);
      expect(fogAlpha(const Offset(10, 10), GrassLandLayout.home, r), 1);
    });
  });

  // The pack files are imported locally (see docs/tile_world.md), not kept
  // in git, so this check only runs where they exist.
  final packMissing = !File('assets/world/grassland.tmx').existsSync();

  test('the Grass Land map and tileset parse', skip: packMissing, () {
    final map = TileMapData.parse(
      File('assets/world/grassland.tmx').readAsStringSync(),
      File('assets/world/grassland_tiles.tsx').readAsStringSync(),
    );
    expect(map.width, 30);
    expect(map.height, 20);
    expect(map.tileWidth, 32);
    expect(map.columns, 26);
    expect(map.layers, hasLength(7));
    expect(File('assets/world/${map.imageSource}').existsSync(), isTrue);
    for (final l in map.layers) {
      for (final g in l.gids) {
        expect(g == 0 || (g >= map.firstGid && g < map.firstGid + 546), isTrue);
      }
    }
    // Every prop sits on the map.
    final bounds = Rect.fromLTWH(0, 0, map.pixelWidth, map.pixelHeight);
    for (final p in GrassLandLayout.props) {
      expect(bounds.contains(p.foot), isTrue, reason: p.id);
    }
  });

  test('markLandSeen stores milestones once', () {
    final container = ProviderContainer(overrides: [
      gameRepositoryProvider.overrideWithValue(InMemoryGameRepository()),
      initialGameStateProvider.overrideWithValue(const GameState()),
      clockProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
    container.read(gameProvider.notifier).markLandSeen(['first_habit']);
    expect(WorldGrowth.seen(container.read(gameProvider)), {'first_habit'});
  });

  testWidgets('next-land card shows the goal and opens the journal',
      (tester) async {
    AppText.useGoogleFonts = false;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        gameRepositoryProvider.overrideWithValue(InMemoryGameRepository()),
        initialGameStateProvider.overrideWithValue(GameState(completions: _completions(1))),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: const MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: NextLandCard())),
      ),
    ));
    expect(find.text('Next land: Plateau Steps'), findsOneWidget);
    expect(find.text('1/12'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next_land_card')));
    await tester.pumpAndSettle();
    expect(find.text('Land Journal'), findsOneWidget);
    expect(find.text('The Old Well'), findsOneWidget);
  });
}
