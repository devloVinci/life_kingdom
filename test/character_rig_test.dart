import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/core/characters/rig_data.dart';
import 'package:life_kingdom/core/characters/rig_poses.dart';
import 'package:life_kingdom/core/widgets/character_rig.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('rig data', () {
    test('builder rig.json is consistent with its svg files', () {
      final dir = Directory('assets/characters/builder');
      final rig = RigData.fromJson(
          jsonDecode(File('${dir.path}/rig.json').readAsStringSync())
              as Map<String, dynamic>);
      expect(rig.slug, 'builder');
      expect(rig.parts.length, greaterThan(5));
      for (final p in rig.parts) {
        expect(File('${dir.path}/${p.file}').existsSync(), isTrue,
            reason: p.file);
      }
      for (final role in ['legL', 'legR', 'armL', 'armR', 'head', 'body']) {
        expect(rig.pivots.containsKey(role), isTrue, reason: role);
      }
    });

    test('every rigged character has complete assets', () {
      for (final slug in riggedCharacterSlugs) {
        final dir = Directory('assets/characters/$slug');
        final rig = RigData.fromJson(
            jsonDecode(File('${dir.path}/rig.json').readAsStringSync())
                as Map<String, dynamic>);
        expect(rig.parts, isNotEmpty, reason: slug);
        for (final p in rig.parts) {
          expect(File('${dir.path}/${p.file}').existsSync(), isTrue,
              reason: '$slug/${p.file}');
          expect(rig.pivots.containsKey(p.role), isTrue, reason: '$slug ${p.role}');
        }
      }
    });

    test('rigSlugForItemId', () {
      expect(rigSlugForItemId('char_builder'), 'builder');
      expect(rigSlugForItemId('char_raider'), 'raider');
      expect(rigSlugForItemId('char_boar_rider'), 'boar_rider');
      expect(rigSlugForItemId('char_nobody'), isNull);
      expect(rigSlugForItemId('bg_forest'), isNull);
    });
  });

  group('poses', () {
    test('every animation is a seamless loop', () {
      for (final a in RigAnim.values) {
        for (final role in [...rigRoles, 'shadow']) {
          final p0 = resolvePose(a, 0, role);
          final p1 = resolvePose(a, 0.999999, role);
          expect(p1.rot, closeTo(p0.rot, 1e-3), reason: '$a $role rot');
          expect(p1.dy, closeTo(p0.dy, 1e-3), reason: '$a $role dy');
          expect(p1.sy, closeTo(p0.sy, 1e-3), reason: '$a $role sy');
        }
      }
    });

    test('work swings the right arm through a large range', () {
      final rots = [
        for (var i = 0; i < 20; i++) resolvePose(RigAnim.work, i / 20, 'armR').rot
      ];
      final range = rots.reduce((a, b) => a > b ? a : b) -
          rots.reduce((a, b) => a < b ? a : b);
      expect(range, greaterThan(1.5));
    });

    test('celebrate raises the free arm above the shoulder', () {
      expect(resolvePose(RigAnim.celebrate, 0.25, 'armL').rot, greaterThan(2));
    });
  });

  testWidgets('CharacterRig renders the builder parts', (tester) async {
    CharacterRig.enableAnimation = false;
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: CharacterRig(slug: 'builder')))));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterRig), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
