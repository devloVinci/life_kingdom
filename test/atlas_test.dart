import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_kingdom/game/atlas/sprite_atlas.dart';

const _json = '''
{"frames": {
  "idle_r1_f1.png": {"frame": {"x": 2, "y": 2, "w": 64, "h": 66},
    "spriteSourceSize": {"x": 0, "y": 0, "w": 64, "h": 66},
    "sourceSize": {"w": 64, "h": 66}, "pivot": {"x": 0.5, "y": 1.0}},
  "idle_r1_f2.png": {"frame": {"x": 68, "y": 2, "w": 64, "h": 66},
    "sourceSize": {"w": 64, "h": 66}, "pivot": {"x": 0.5, "y": 1.0}},
  "idle_r2_f1.png": {"frame": {"x": 2, "y": 70, "w": 64, "h": 66},
    "sourceSize": {"w": 64, "h": 66}, "pivot": {"x": 0.5, "y": 1.0}}
 },
 "animations": {"idle_r1": ["idle_r1_f1.png", "idle_r1_f2.png"],
                "idle_r2": ["idle_r2_f1.png"]},
 "meta": {"image": "x.png"}}
''';

void main() {
  test('parses frames, animations and groups', () {
    final a = AtlasData.parse(_json);
    expect(a.frames.length, 3);
    expect(a.animations['idle_r1'], hasLength(2));
    expect(a.group('idle'), ['idle_r1_f1.png', 'idle_r1_f2.png', 'idle_r2_f1.png']);
  });

  test('pivot places the feet on the anchor point', () {
    final f = AtlasData.parse(_json).frames['idle_r1_f1.png']!;
    final r = f.destRect(const Offset(100, 200), 2);
    expect(r.bottom, 200);
    expect(r.center.dx, 100);
    expect(r.width, 128);
  });
}
