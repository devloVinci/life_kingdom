import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/world_engine.dart';
import '../../../game/atlas/anim_overrides.dart';
import '../../../game/atlas/catalog.dart';
import '../../../game/atlas/character_anims.dart';
import '../../../game/atlas/sprite_atlas.dart';
import '../army/army_sheet.dart';
import '../kingdom/kingdom_screen.dart';
import '../ow_style.dart';

/// The open world: black beyond what your level has revealed. Landmarks
/// inside the light can be taken by marching the army (costs supplies).
class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  static const tile = 64.0;
  static int get side => WorldConfig.worldHalfSize * 2 + 1;
  static Size get sceneSize => Size(side * tile, side * tile);

  /// Scene position of a tile offset from the castle (feet of a sprite).
  static Offset at(double gx, double gy) {
    final n = WorldConfig.worldHalfSize;
    return Offset((n + gx) * tile + tile / 2, (n + gy) * tile + tile);
  }

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _March {
  _March(this.target, this.start);
  final Landmark target;
  final double start;
  static const seconds = 3.5;
}

class _WorldScreenState extends ConsumerState<WorldScreen>
    with SingleTickerProviderStateMixin {
  final _tc = TransformationController();
  bool _centered = false;
  Ticker? _ticker;
  double _t = 0;
  _March? _march;

  @override
  void initState() {
    super.initState();
    if (SceneClock.enabled) {
      _ticker = createTicker((d) {
        if (!mounted) return;
        final t = d.inMicroseconds / 1e6;
        if (_march != null && t - _march!.start > _March.seconds + 0.6) {
          setState(() {
            _t = t;
            _march = null;
          });
        } else {
          setState(() => _t = t);
        }
      })
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
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

  void _onTap(Offset p) {
    final s = ref.read(gameProvider);
    final level = GameEngine.level(s);
    Landmark? best;
    var bestD = 70.0;
    for (final l in ArmyEngine.landmarks) {
      if (!ArmyEngine.revealed(l, level)) continue;
      final d = (WorldScreen.at(l.gx, l.gy) - const Offset(0, 40) - p).distance;
      if (d < bestD) {
        bestD = d;
        best = l;
      }
    }
    if (best != null) _showLandmark(best);
  }

  void _showLandmark(Landmark l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Ow.panel,
      builder: (c) => Consumer(builder: (c, ref, _) {
        final s = ref.watch(gameProvider);
        final taken = s.world.captured.contains(l.id);
        final power = ArmyEngine.armyPower(s);
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_landmarkName(l), style: Ow.title(20, color: Ow.gold)),
              const SizedBox(height: 6),
              if (taken)
                Text('رايتك ترفرف هنا.', style: Ow.body(14, color: Ow.supply))
              else ...[
                Text(
                    'يحتاج قوة ${l.powerNeeded} (قوتك $power) '
                    'و${l.supplyCost} إمدادات (لديك ${s.world.supplies})',
                    style: Ow.body(14)),
                Text(
                    'الغنيمة: ${l.goldReward} ذهب'
                    '${l.gemReward > 0 ? ' و${l.gemReward} جواهر' : ''}',
                    style: Ow.body(13, color: Ow.muted)),
                const SizedBox(height: 12),
                Row(children: [
                  OwButton(
                    key: const Key('march'),
                    label: 'سيّر الجيش',
                    icon: Icons.flag,
                    onPressed: () {
                      final st = ref.read(gameProvider.notifier).capture(l.id);
                      Navigator.pop(c);
                      if (st == CaptureStatus.ok) {
                        setState(() => _march = _March(l, _t));
                        owToast(context,
                            'سار الجيش: +${l.goldReward} ذهب${l.gemReward > 0 ? ' +${l.gemReward} جواهر' : ''}');
                      } else {
                        owToast(
                            context,
                            switch (st) {
                              CaptureStatus.tooWeak =>
                                'الجيش أضعف من هذا المكان. درّب جنوداً في الثكنة.',
                              CaptureStatus.noSupplies =>
                                'لا تكفي الإمدادات. أنجز مهامك لتجمعها.',
                              _ => 'تعذّر المسير',
                            });
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  OwButton(
                    label: 'الثكنة',
                    color: Ow.panelHi,
                    onPressed: () {
                      Navigator.pop(c);
                      showArmySheet(context);
                    },
                  ),
                ]),
              ],
            ],
          ),
        );
      }),
    );
  }

  static const _groupNames = [
    'برج مراقبة',
    'أطلال قديمة',
    'معسكر استراحة',
    'موقع تعدين',
    'مقابر مهجورة',
    'محجر',
  ];
  String _landmarkName(Landmark l) => _groupNames[l.group % _groupNames.length];

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final level = GameEngine.level(s);
    final radius = WorldEngine.worldRadius(level);
    final anims = ref.watch(animOverridesProvider);
    final lib = ref.watch(characterLibraryProvider).valueOrNull;
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
    final march = _march;
    final marchT = march == null
        ? null
        : ((_t - march.start) / _March.seconds).clamp(0.0, 1.0);

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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d.localPosition),
            child: Stack(children: [
              RepaintBoundary(
                child: CustomPaint(
                  key: const Key('world_scene'),
                  size: WorldScreen.sceneSize,
                  painter: WorldPainter(atlases, radius,
                      WorldEngine.townHallStage(level), level,
                      s.world.captured),
                ),
              ),
              CustomPaint(
                size: WorldScreen.sceneSize,
                painter: _UnitsPainter(atlases, anims, lib, _t, s.world.army,
                    march?.target, marchT),
              ),
            ]),
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
                Row(children: [
                  Expanded(
                    child: Text('أنت في: ${WorldConfig.regions[region].name}',
                        style: Ow.title(17, color: Ow.gold)),
                  ),
                  Text('قوة ${ArmyEngine.armyPower(s)} · '
                      'إمدادات ${s.world.supplies}',
                      style: Ow.body(12, color: Ow.muted)),
                ]),
                const SizedBox(height: 4),
                Text(
                  nextRegion == null
                      ? 'انكشف لك العالم كله.'
                      : 'المس مَعلماً لتسيّر إليه الجيش. '
                          '${nextRegion.name} يظهر عند المستوى $nextLevel.',
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
  WorldPainter(
      this.a, this.radius, this.townHallStage, this.level, this.captured);

  final Map<String, SpriteAtlas> a;
  final double radius;
  final int townHallStage;
  final int level;
  final Set<String> captured;

  static const _groundAtlas = [
    'terrain_grass_dirt_mud',
    'terrain_snow_ice_shadow',
    'terrain_volcanic_lava',
    'terrain_snow_ice_shadow',
  ];
  static const _groundGroup = [
    'tileset0_variants',
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
    final props = <(Offset, int, double)>[];

    // Tiles near a landmark stay clear of trees.
    bool nearLandmark(int gx, int gy) => ArmyEngine.landmarks
        .any((l) => (l.gx - gx).abs() < 1.2 && (l.gy - gy).abs() < 1.2);

    for (var gy = -n; gy <= n; gy++) {
      for (var gx = -n; gx <= n; gx++) {
        final roll = rnd.nextDouble();
        final variant = rnd.nextInt(1 << 20);
        final d = sqrt((gx * gx + gy * gy).toDouble());
        if (d > radius + 1) continue;
        final fade = d <= radius ? 1.0 : (radius + 1 - d).clamp(0.0, 1.0) * 0.5;
        final region = WorldEngine.regionIndexAt(d);
        final center =
            Offset((gx + n) * tile + tile / 2, (gy + n) * tile + tile / 2);
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
        if (d <= radius && d > 1.5 && roll < 0.14 && !nearLandmark(gx, gy)) {
          props.add((center + const Offset(0, tile / 2), region, roll));
        }
      }
    }

    // Nature + landmarks, y-sorted together.
    final drawables = <(double, void Function())>[];
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
        drawables.add((
          p.$1.dy,
          () => f.draw(canvas, list[(p.$3 * 1000).floor() % list.length],
              p.$1, scale: 1.3)
        ));
      }
    }

    final l = a['world_landmarks'];
    final scars = a['battlefield_scars'];
    for (final lm in ArmyEngine.landmarks) {
      if (!ArmyEngine.revealed(lm, level)) continue;
      final at = WorldScreen.at(lm.gx, lm.gy);
      drawables.add((
        at.dy,
        () {
          final g = l?.group(Catalog.landmarkGroups[lm.group]) ??
              const <String>[];
          if (l == null || g.isEmpty) {
            canvas.drawCircle(at - const Offset(0, 30), 24,
                Paint()..color = const Color(0xFF8A7A5A));
          } else {
            l.draw(canvas, g[lm.variant % g.length], at, scale: 1.6);
          }
          if (captured.contains(lm.id)) {
            final b = scars?.group('conquest_banners') ?? const <String>[];
            if (scars != null && b.isNotEmpty) {
              scars.draw(canvas, b.first, at + const Offset(36, 6), scale: 1.2);
            } else {
              canvas.drawRect(Rect.fromLTWH(at.dx + 30, at.dy - 50, 18, 12),
                  Paint()..color = const Color(0xFFF5C542));
            }
          }
        }
      ));
    }

    // The castle at the centre.
    final c = WorldScreen.at(0, 0);
    drawables.add((
      c.dy,
      () {
        final th = a['town_hall_idle_upgrade'];
        final thFrame = th == null ? null : Catalog.townHall(th, townHallStage);
        if (th != null && thFrame != null) {
          th.draw(canvas, thFrame, c, scale: 2.0);
        } else {
          canvas.drawCircle(c - const Offset(0, 40), 40,
              Paint()..color = const Color(0xFFB8862B));
        }
      }
    ));

    drawables.sort((x, y) => x.$1.compareTo(y.$1));
    for (final d in drawables) {
      d.$2();
    }
  }

  @override
  bool shouldRepaint(WorldPainter old) =>
      old.radius != radius ||
      old.a.length != a.length ||
      old.townHallStage != townHallStage ||
      old.captured.length != captured.length;
}

/// Hero and army: idle beside the castle, or marching to a landmark.
class _UnitsPainter extends CustomPainter {
  _UnitsPainter(
      this.a, this.anims, this.lib, this.t, this.army, this.target, this.p);

  final Map<String, SpriteAtlas> a;
  final Map<String, String> anims;
  final CharacterLibrary? lib;
  final double t;
  final Map<String, int> army;
  final Landmark? target;
  final double? p;

  @override
  void paint(Canvas canvas, Size size) {
    final home = WorldScreen.at(0.9, 0.5);
    final marching = target != null && p != null;
    final dest = marching ? WorldScreen.at(target!.gx - 0.6, target!.gy + 0.3) : home;
    final pos = marching ? Offset.lerp(home, dest, p!)! : home;
    final moving = marching && p! < 1;
    final dir = moving ? facingOf(dest - home) : 'down';

    final party = <String>[
      'knight',
      for (var i = 0; i < (army['barbarian'] ?? 0) && i < 4; i++) 'barbarian',
      for (var i = 0; i < (army['archer'] ?? 0) && i < 3; i++) 'archer',
    ];
    final items = <(Offset, String)>[];
    for (var i = 0; i < party.length; i++) {
      final row = i ~/ 3, col = i % 3;
      items.add((pos + Offset(col * 26.0 - 26 + row * 8, row * 18.0), party[i]));
    }
    items.sort((x, y) => x.$1.dy.compareTo(y.$1.dy));
    for (final it in items) {
      final ok = drawSlot(canvas,
          lib: lib,
          atlases: a,
          overrides: anims,
          slot: '${it.$2}.${moving ? 'walk' : 'idle'}',
          direction: dir,
          at: it.$1,
          t: t,
          scale: it.$2 == 'knight' ? 1.5 : 1.25);
      if (!ok) {
        canvas.drawCircle(it.$1 - const Offset(0, 12), 9,
            Paint()..color = it.$2 == 'knight' ? Colors.white : Colors.orange);
      }
    }
  }

  @override
  bool shouldRepaint(_UnitsPainter old) => true;
}
