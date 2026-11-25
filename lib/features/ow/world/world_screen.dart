import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/world_engine.dart';
import '../../../game/atlas/catalog.dart';
import '../../../game/atlas/sprite_atlas.dart';
import '../ow_style.dart';

/// The open world: black beyond what your level has revealed.
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  static const tile = 64.0;
  static int get side => WorldConfig.worldHalfSize * 2 + 1;
  static Size get sceneSize => Size(side * tile, side * tile);

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  final _tc = TransformationController();
  bool _centered = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _center(Size view, double radius) {
    if (_centered) return;
    _centered = true;
    final scene = WorldScreen.sceneSize;
    final visible = (radius * 2 + 3) * WorldScreen.tile;
    final scale = (min(view.width, view.height) / visible).clamp(0.25, 2.0);
    _tc.value = Matrix4.identity()
      ..translate(view.width / 2 - scene.width / 2 * scale,
          view.height / 2 - scene.height / 2 * scale + 30)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final level = GameEngine.level(s);
    final radius = WorldEngine.worldRadius(level);
    final atlases =
        ref.watch(atlasSetProvider(Atlases.world.join(','))).valueOrNull ??
            const <String, SpriteAtlas>{};
    final region = WorldEngine.regionIndexAt(radius);
    final nextRegion = region + 1 < WorldConfig.regions.length
        ? WorldConfig.regions[region + 1]
        : null;
    final nextLevel = nextRegion == null
        ? null
        : WorldEngine.levelForRadius(WorldConfig.regions[region].edge + 1.0);

    return LayoutBuilder(builder: (context, c) {
      _center(c.biggest, radius);
      return Stack(children: [
        Positioned.fill(child: Container(color: Colors.black)),
        InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          minScale: 0.15,
          maxScale: 3,
          boundaryMargin: const EdgeInsets.all(400),
          child: RepaintBoundary(
            child: CustomPaint(
              key: const Key('world_scene'),
              size: WorldScreen.sceneSize,
              painter: WorldPainter(atlases, radius,
                  WorldEngine.townHallStage(level)),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: OwPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أنت في: ${WorldConfig.regions[region].name}',
                    style: Ow.title(17, color: Ow.gold)),
                const SizedBox(height: 4),
                Text(
                  nextRegion == null
                      ? 'انكشف لك العالم كله.'
                      : 'تنكشف الأرض حولك كلما ارتفع مستواك. '
                          '${nextRegion.name} يبدأ بالظهور عند المستوى $nextLevel.',
                  style: Ow.body(13, color: Ow.muted),
                ),
              ],
            ),
          ),
        ),
      ]);
    });
  }
}

class WorldPainter extends CustomPainter {
  WorldPainter(this.a, this.radius, this.townHallStage);

  final Map<String, SpriteAtlas> a;
  final double radius;
  final int townHallStage;

  static const _groundAtlas = [
    'grass_dirt_mud',
    'snow_ice_shadow',
    'volcanic_lava_transitions',
    'snow_ice_shadow',
  ];
  static const _groundGroup = [
    'grass_plain',
    Catalog.snowGroup,
    Catalog.volcanicGroup,
    Catalog.shadowGroup,
  ];
  static const _regionColor = [
    Color(0xFF4E8B3A),
    Color(0xFFDDE7F0),
    Color(0xFF4A2E26),
    Color(0xFF2C2238),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const tile = WorldScreen.tile;
    final n = WorldConfig.worldHalfSize;
    final rnd = Random(3);
    final props = <(Offset, int, double)>[]; // position, region, roll

    for (var gy = -n; gy <= n; gy++) {
      for (var gx = -n; gx <= n; gx++) {
        final roll = rnd.nextDouble();
        final variant = rnd.nextInt(1 << 20);
        final d = sqrt((gx * gx + gy * gy).toDouble());
        if (d > radius + 1) continue;
        final fade = d <= radius ? 1.0 : (radius + 1 - d).clamp(0.0, 1.0) * 0.5;
        final region = WorldEngine.regionIndexAt(d);
        final center = Offset((gx + n) * tile + tile / 2, (gy + n) * tile + tile / 2);
        final atlas = a[_groundAtlas[region]];
        final frames = atlas?.group(_groundGroup[region]) ?? const <String>[];
        if (atlas == null || frames.isEmpty) {
          canvas.drawRect(
              Rect.fromCenter(center: center, width: tile, height: tile),
              Paint()..color = _regionColor[region].withValues(alpha: fade));
        } else {
          atlas.draw(canvas, frames[variant % frames.length], center,
              opacity: fade);
        }
        if (d <= radius && d > 1.5 && roll < 0.16) {
          props.add((center + const Offset(0, tile / 2), region, roll));
        }
      }
    }

    // Nature props, y-sorted.
    props.sort((x, y) => x.$1.dy.compareTo(y.$1.dy));
    final f = a['flora_rocks_resources'];
    if (f != null) {
      final decid = f.group(Catalog.treeGroups[0]);
      final pine = f.group(Catalog.treeGroups[1]);
      final rocks = f.group(Catalog.rockGroup);
      for (final p in props) {
        final list = switch (p.$2) {
          0 => decid,
          1 => pine,
          _ => rocks,
        };
        if (list.isEmpty) continue;
        f.draw(canvas, list[(p.$3 * 1000).floor() % list.length], p.$1,
            scale: 1.3);
      }
    }

    // Landmarks on fixed spots, shown once revealed.
    final l = a['landmarks_pois'];
    if (l != null) {
      final r2 = Random(21);
      for (var i = 0; i < 14; i++) {
        final ang = r2.nextDouble() * pi * 2;
        final dist = 2.5 + i * 0.9;
        if (dist > radius) continue;
        final g = l.group(Catalog.landmarkGroups[i % Catalog.landmarkGroups.length]);
        if (g.isEmpty) continue;
        final at = Offset((n + cos(ang) * dist) * tile + tile / 2,
            (n + sin(ang) * dist) * tile + tile);
        l.draw(canvas, g[r2.nextInt(g.length)], at, scale: 1.6);
      }
    }

    // The castle and the hero at the centre.
    final c = Offset(n * tile + tile / 2, n * tile + tile);
    final th = a['storages_townhall_builder'];
    final thFrame = th == null ? null : Catalog.townHall(th, townHallStage);
    if (th != null && thFrame != null) {
      th.draw(canvas, thFrame, c, scale: 2.0);
    } else {
      canvas.drawCircle(c - const Offset(0, 40), 40,
          Paint()..color = const Color(0xFFB8862B));
    }
    final k = a['knight'];
    final kf = k?.anim(Catalog.knightIdle);
    if (k != null && kf != null && kf.isNotEmpty) {
      k.draw(canvas, kf.first, c + const Offset(70, 40), scale: 1.5);
    }
  }

  @override
  bool shouldRepaint(WorldPainter old) =>
      old.radius != radius ||
      old.a.length != a.length ||
      old.townHallStage != townHallStage;
}
