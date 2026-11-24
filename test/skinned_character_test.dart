import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/characters/skinned/skinned_character.dart';
import 'package:life_kingdom/core/characters/skinned/skinned_pose.dart';
import 'package:life_kingdom/core/characters/skinned/skinned_rig.dart';
import 'package:life_kingdom/core/theme/app_text.dart';
import 'package:life_kingdom/features/character_lab/character_lab_screen.dart';

const _folder = 'assets/heroes/hero_knight';

SkinnedRig _rig() => SkinnedRig.fromJson(
    jsonDecode(File('$_folder/rig.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('hero rig data', () {
    test('rig.json parses and references existing textures', () {
      final rig = _rig();
      expect(rig.slug, 'hero_knight');
      expect(rig.layers.map((l) => l.name), ['body', 'sword', 'shield']);
      for (final l in rig.layers) {
        expect(File('$_folder/${l.image}').existsSync(), isTrue,
            reason: l.image);
      }
      for (final c in ['idle', 'walk', 'victory', 'levelUp', 'hit', 'skill']) {
        expect(rig.clips.containsKey(c), isTrue, reason: c);
      }
    });

    test('meshes are valid and weights are normalised', () {
      final rig = _rig();
      for (final l in rig.layers) {
        expect(l.triangles.length % 3, 0);
        for (final i in l.triangles) {
          expect(i, lessThan(l.vertexCount));
        }
        for (var v = 0; v < l.vertexCount; v++) {
          var sum = 0.0;
          for (var k = 0; k < l.influences; k++) {
            final b = l.boneIds[v * l.influences + k];
            expect(b, inInclusiveRange(0, rig.bones.length - 1));
            sum += l.boneWeights[v * l.influences + k];
          }
          expect(sum, closeTo(1, 0.01), reason: '${l.name} vertex $v');
        }
      }
    });

    test('an empty clip leaves the mesh in its rest pose', () {
      final rig = _rig();
      final rest = RigClip(
          name: 'rest',
          duration: 1,
          loop: true,
          blink: false,
          tracks: const {},
          fx: const {});
      final pose = RigPose.sample(rig, rest, 0.3);
      for (final l in rig.layers) {
        final out = Float32List(l.positions.length);
        pose.skin(l, out);
        for (var i = 0; i < out.length; i++) {
          expect(out[i], closeTo(l.positions[i], 1e-3));
        }
      }
    });

    test('loops are seamless', () {
      final rig = _rig();
      for (final clip in rig.clips.values.where((c) => c.loop)) {
        for (final e in clip.tracks.entries) {
          for (final ch in e.value.entries) {
            expect(ch.value.values.last, closeTo(ch.value.values.first, 1e-9),
                reason: '${clip.name} ${e.key}.${ch.key}');
          }
        }
      }
    });

    test('Dart skinning matches the verified Python reference renderer', () {
      final rig = _rig();
      final ref = jsonDecode(File('test/fixtures/hero_knight_reference_poses.json')
          .readAsStringSync()) as List;
      for (final r in ref) {
        final clip = rig.clips[r['clip']]!;
        final pose = RigPose.sample(rig, clip, (r['t'] as num).toDouble());
        final layer = rig.layers[r['layer'] as int];
        final out = Float32List(layer.positions.length);
        pose.skin(layer, out);
        final ids = (r['vertices'] as List).cast<int>();
        final xy = r['xy'] as List;
        for (var i = 0; i < ids.length; i++) {
          final p = xy[i] as List;
          expect(out[2 * ids[i]], closeTo((p[0] as num).toDouble(), 0.01));
          expect(out[2 * ids[i] + 1], closeTo((p[1] as num).toDouble(), 0.01));
        }
      }
    });
  });

  group('widgets', () {
    setUpAll(() => AppText.useGoogleFonts = false);

    testWidgets('SkinnedCharacter loads, animates and plays one-shots',
        (tester) async {
      await tester.runAsync(() => SkinnedRigLoader.load(_folder));
      final c = CharacterAnimController();
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
              width: 200, height: 300, child: SkinnedCharacter(controller: c)),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(CustomPaint), findsWidgets);
      for (final clip in ['victory', 'levelUp', 'hit', 'skill']) {
        c.play(clip);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
      c.setLoop('walk');
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      c.dispose();
    });

    testWidgets('Character Lab screen renders', (tester) async {
      await tester.runAsync(() => SkinnedRigLoader.load(_folder));
      await tester.pumpWidget(const MaterialApp(home: CharacterLabScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Character Lab'), findsOneWidget);
      await tester.tap(find.text('Victory'));
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull);
    });
  });
}
