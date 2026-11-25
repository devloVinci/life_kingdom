import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/game/atlas/character_anims.dart';

const _json = '''
{"characters": {
  "goblin": {"type": "unit", "animations": {
    "walk": {"category": "movement", "fps": 8, "loop": true, "directions": {
      "right": {"atlas_json": "06_Units/goblin/goblin/goblin_atlas.json",
                "animation_key": "goblin_walk_r1"},
      "left": {"mirror_of": "right", "flip_x": true}}},
    "idle": {"category": "movement", "fps": 6, "directions": {
      "down": {"atlas_json": "06_Units/goblin/goblin/goblin_atlas.json",
               "animation_key": "goblin_idle_r1"}}}
  }},
  "knight": {"animations": {
    "idle": {"category": "movement", "directions": {
      "left": {"atlas_json": "06_Units/knight_hero/knight/knight_atlas.json",
               "animation_key": "knight_set01_r3"}}}}}
}}
''';

void main() {
  final lib = CharacterLibrary.parse(_json);

  test('resolves atlas id, key and fps', () {
    final r = lib.resolve('goblin', 'walk', 'right')!;
    expect(r.atlasId, 'goblin');
    expect(r.key, 'goblin_walk_r1');
    expect(r.fps, 8);
    expect(r.flipX, isFalse);
  });

  test('mirror_of plays the other side flipped', () {
    final r = lib.resolve('goblin', 'walk', 'left')!;
    expect(r.key, 'goblin_walk_r1');
    expect(r.flipX, isTrue);
  });

  test('a missing side is the drawn side flipped; else falls back', () {
    final r = lib.resolve('knight', 'idle', 'right')!;
    expect(r.key, 'knight_set01_r3');
    expect(r.flipX, isTrue);
    expect(lib.resolve('goblin', 'idle', 'up')!.key, 'goblin_idle_r1');
    expect(lib.resolve('goblin', 'nope', 'down'), isNull);
  });

  test('lists animations with categories', () {
    final a = lib.animations('goblin');
    expect(a.map((e) => e.name), containsAll(['walk', 'idle']));
    expect(a.first.category, 'movement');
  });

  test('facing from movement', () {
    expect(facingOf(const Offset(-5, 1)), 'left');
    expect(facingOf(const Offset(0, -3)), 'up');
  });
}
