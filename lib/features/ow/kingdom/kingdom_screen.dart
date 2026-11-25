import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/world_engine.dart';
import '../../../game/atlas/anim_overrides.dart';
import '../../../game/atlas/catalog.dart';
import '../../../game/atlas/character_anims.dart';
import '../../../game/atlas/sprite_atlas.dart';
import '../army/army_sheet.dart';
import '../ow_style.dart';

/// Tests turn the animation clock off so pumpAndSettle can finish.
class SceneClock {
  static bool enabled = true;
}

/// Everything the kingdom painter needs, derived from the game state.
class KingdomView {
  KingdomView(GameState s, DateTime now)
      : townHallStage = WorldEngine.townHallStage(GameEngine.level(s)),
        mineStage = WorldEngine.mineStage(s),
        harvest = s.world.pendingHarvest,
        towerLevel = WorldEngine.towerLevel(s.world.bestWeek),
        chestFrame = WorldEngine.chestFrame(s, now),
        chestReady = WorldEngine.pendingChest(s, now) != null,
        goblin = s.world.goblinLoot > 0,
        fortifications = s.streak.freezesHeld,
        restDay = WorldEngine.isRestDay(s, now),
        workedToday = WorldEngine.workedOn(s, dateKeyOf(now)),
        level = GameEngine.level(s),
        barbarians = s.world.army['barbarian'] ?? 0,
        archers = s.world.army['archer'] ?? 0;

  final int townHallStage;
  final int mineStage;
  final int harvest;
  final int towerLevel;
  final int chestFrame;
  final bool chestReady;
  final bool goblin;
  final int fortifications;
  final bool restDay;
  final bool workedToday;
  final int level;
  final int barbarians;
  final int archers;
}

class KingdomScreen extends ConsumerStatefulWidget {
  const KingdomScreen({super.key});

  static const sceneSize = Size(1400, 1000);

  @override
  ConsumerState<KingdomScreen> createState() => _KingdomScreenState();
}

class _KingdomScreenState extends ConsumerState<KingdomScreen>
    with SingleTickerProviderStateMixin {
  Ticker? _ticker;
  double _t = 0;
  final _hits = <String, Rect>{};
  final _tc = TransformationController();
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    if (SceneClock.enabled) {
      _ticker = createTicker((d) {
        if (!mounted) return;
        setState(() => _t = d.inMicroseconds / 1e6);
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

  void _center(Size view) {
    if (_centered) return;
    _centered = true;
    const scene = KingdomScreen.sceneSize;
    final scale = max(view.width / scene.width, view.height / scene.height) * 1.25;
    final dx = (view.width - scene.width * scale) / 2;
    final dy = (view.height - scene.height * scale) / 2 + 40;
    _tc.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale);
  }

  void _onTap(Offset p) {
    String? hit;
    for (final e in _hits.entries) {
      if (e.value.contains(p)) hit = e.key; // last drawn wins (front-most)
    }
    if (hit == null) return;
    final game = ref.read(gameProvider.notifier);
    switch (hit) {
      case 'mine':
        final g = game.collectHarvest();
        owToast(context, g > 0 ? 'جمعت $g ذهباً من المنجم' : 'المنجم يملأ بما تنجزه');
      case 'chest':
        final c = game.claimChest();
        owToast(
            context,
            c != null
                ? 'صندوق الأمس: +${c.gold} ذهب، +${c.supplies} إمدادات${c.gems > 0 ? '، +${c.gems} جوهرة' : ''}'
                : 'الصندوق يمتلئ بإنجاز اليوم، ويُفتح غداً');
      case 'goblin':
        final g = game.chaseGoblin();
        owToast(
            context,
            g < 0
                ? 'أنجز شيئاً اليوم لتطارد الغول وتسترد ذهبك'
                : 'طاردت الغول واستعدت $g ذهباً');
      case 'tower':
        final s = ref.read(gameProvider);
        final next = WorldEngine.nextTowerThreshold(s.world.bestWeek);
        owToast(
            context,
            next == null
                ? 'برج الأرقام مكتمل. أفضل أسبوع: ${s.world.bestWeek}'
                : 'أفضل أسبوع: ${s.world.bestWeek} نقطة. الطابق التالي عند $next');
      case 'townhall':
        final s = ref.read(gameProvider);
        owToast(context,
            'قاعة المملكة تكبر مع مستواك (${GameEngine.level(s)})');
      case 'barracks':
      case 'camp':
        showArmySheet(context);
      case 'builder':
        owToast(context, 'البنّاء يعمل في الأيام التي تنجز فيها');
      case 'knight':
        owToast(context, 'فارسك ينتظر أوامرك في العالم');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(nowProvider)();
    final atlases =
        ref.watch(atlasSetProvider(Atlases.kingdom.join(','))).valueOrNull ??
            const <String, SpriteAtlas>{};
    final view = KingdomView(s, now);
    final anims = ref.watch(animOverridesProvider);
    final lib = ref.watch(characterLibraryProvider).valueOrNull;
    return LayoutBuilder(builder: (context, c) {
      _center(c.biggest);
      return Stack(children: [
        Positioned.fill(
          child: Container(color: const Color(0xFF2D4A22)),
        ),
        InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          minScale: 0.3,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(200),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTap(d.localPosition),
            child: CustomPaint(
              key: const Key('kingdom_scene'),
              size: KingdomScreen.sceneSize,
              painter: KingdomPainter(atlases, view, _t, _hits, anims, lib),
            ),
          ),
        ),
        if (atlases.isEmpty)
          const Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _MissingAssets(),
          ),
        if (view.restDay)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: OwPanel(
                accent: Ow.xp,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text('يوم راحة: البوابات مغلقة والحرس على الأسوار',
                    style: Ow.body(13)),
              ),
            ),
          ),
      ]);
    });
  }
}

class _MissingAssets extends StatelessWidget {
  const _MissingAssets();

  @override
  Widget build(BuildContext context) => OwPanel(
        accent: Ow.danger,
        child: Text(
          'لم تُستورد صور الحزمة بعد. شغّل tools/openworld/import_pack.ps1 '
          'ثم أعد تشغيل التطبيق.',
          style: Ow.body(13),
        ),
      );
}

class KingdomPainter extends CustomPainter {
  KingdomPainter(this.a, this.v, this.t, this.hits, this.anims, this.lib);

  final CharacterLibrary? lib;

  final Map<String, SpriteAtlas> a;
  final KingdomView v;
  final double t;
  final Map<String, Rect> hits;
  final Map<String, String> anims;

  static const _barracks = Offset(1070, 700);
  static const _camp = Offset(880, 760);

  static const _th = Offset(700, 470);
  static const _mine = Offset(470, 560);
  static const _tower = Offset(960, 500);
  static const _builder = Offset(830, 575);
  static const _knight = Offset(620, 660);
  static const _chest = Offset(700, 830);
  static const _goblin = Offset(360, 650);

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    _ground(canvas, size);
    _nature(canvas, size);

    // Y-sorted drawables (pivot y = depth).
    final items = <(double, void Function())>[
      (_th.dy, () => _townHall(canvas)),
      (_mine.dy, () => _goldMine(canvas)),
      (_tower.dy, () => _recordTower(canvas)),
      (_builder.dy, () => _unit(canvas,
          v.workedToday ? 'builder.work' : 'builder.idle', 'left',
          _builder, 1.7, 'builder')),
      (_knight.dy, () =>
          _unit(canvas, 'knight.idle', 'down', _knight, 1.9, 'knight')),
      (_barracks.dy, () => _building(canvas, 'army_barracks_spells_lab',
          'barracks_wood', (v.level ~/ 6).clamp(0, 15), _barracks, 2.0,
          'barracks', 'الثكنة')),
      (_camp.dy - 30, () => _building(canvas, 'army_barracks_spells_lab',
          'army_camp_tents',
          ((v.barbarians + v.archers) ~/ 3).clamp(0, 15), _camp, 1.6,
          'camp', 'المعسكر')),
      for (final u in _soldiers()) (u.$2.dy, () => _soldier(canvas, u)),
      (_chest.dy, () => _dailyChest(canvas)),
      if (v.goblin)
        (_goblin.dy, () => _unit(canvas, 'goblin.idle', 'right',
            _goblin + Offset(sin(t * 2) * 12, 0), 1.6, 'goblin')),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    for (final i in items) {
      i.$2();
    }
    _walls(canvas);
    _harvestBubble(canvas);
    if (v.restDay) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = const Color(0xFF0A1030).withValues(alpha: 0.35));
    }
  }

  void _ground(Canvas canvas, Size size) {
    final g = a['grass_dirt_mud'];
    if (g == null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF4E8B3A));
      return;
    }
    final plain = g.group(Catalog.grassGroups[0]);
    final lush = g.group(Catalog.grassGroups[1]);
    final rnd = Random(7);
    const tile = 64.0;
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        final pick = rnd.nextInt(10);
        final list = (pick < 2 && lush.isNotEmpty) ? lush : plain;
        if (list.isEmpty) continue;
        g.draw(canvas, list[rnd.nextInt(list.length)],
            Offset(x + tile / 2, y + tile / 2));
      }
    }
  }

  void _nature(Canvas canvas, Size size) {
    final f = a['flora_rocks_resources'];
    if (f == null) return;
    final trees = [
      ...f.group(Catalog.treeGroups[0]),
      ...f.group(Catalog.treeGroups[1]),
    ];
    final bushes = f.group(Catalog.bushGroup);
    if (trees.isEmpty) return;
    final rnd = Random(11);
    // A forest ring around the village clearing.
    for (var i = 0; i < 70; i++) {
      final ang = rnd.nextDouble() * pi * 2;
      final r = 470 + rnd.nextDouble() * 220;
      final p = Offset(700 + cos(ang) * r * 1.15, 500 + sin(ang) * r * 0.8);
      if (p.dx < -40 || p.dy < 0 || p.dx > size.width + 40 || p.dy > size.height + 60) {
        continue;
      }
      f.draw(canvas, trees[rnd.nextInt(trees.length)], p, scale: 1.7);
    }
    for (var i = 0; i < 14 && bushes.isNotEmpty; i++) {
      final p = Offset(380 + rnd.nextDouble() * 640, 330 + rnd.nextDouble() * 560);
      if ((p - _th).distance < 150 || (p - _chest).distance < 90) continue;
      f.draw(canvas, bushes[rnd.nextInt(bushes.length)], p, scale: 1.1);
    }
  }

  void _townHall(Canvas canvas) {
    final b = a['storages_townhall_builder'];
    final f = b == null ? null : Catalog.townHall(b, v.townHallStage);
    if (b == null || f == null) {
      _placeholder(canvas, _th, const Size(150, 150), 'القاعة', 'townhall');
      return;
    }
    final r = b.draw(canvas, f, _th, scale: 2.6);
    if (r != null) hits['townhall'] = r;
  }

  void _goldMine(Canvas canvas) {
    final b = a['resource_extractors'];
    final f = b == null ? null : Catalog.goldMine(b, v.mineStage);
    if (b == null || f == null) {
      _placeholder(canvas, _mine, const Size(110, 110), 'المنجم', 'mine');
      return;
    }
    final r = b.draw(canvas, f, _mine, scale: 2.1);
    if (r != null) hits['mine'] = r;
  }

  void _recordTower(Canvas canvas) {
    final b = a['record_tower'];
    final f = b == null ? null : Catalog.recordTower(b, max(1, v.towerLevel));
    if (b == null || f == null) {
      _placeholder(canvas, _tower, const Size(60, 160), 'البرج', 'tower');
      return;
    }
    final r = b.draw(canvas, f, _tower,
        scale: 0.26, opacity: v.towerLevel == 0 ? 0.35 : 1);
    if (r != null) hits['tower'] = r;
  }

  void _dailyChest(Canvas canvas) {
    final b = a['daily_chest'];
    final f = b == null ? null : Catalog.dailyChest(b, v.chestFrame);
    if (b == null || f == null) {
      _placeholder(canvas, _chest, const Size(90, 70), 'الصندوق', 'chest');
      return;
    }
    final bob = v.chestReady ? sin(t * 4).abs() * -6 : 0.0;
    final r = b.draw(canvas, f, _chest + Offset(0, bob), scale: 0.34);
    if (r != null) hits['chest'] = r;
  }

  void _unit(Canvas canvas, String slot, String dir, Offset at, double scale,
      String hit) {
    final ok = drawSlot(canvas,
        lib: lib,
        atlases: a,
        overrides: anims,
        slot: slot,
        direction: dir,
        at: at,
        t: t,
        scale: scale);
    if (!ok) {
      _placeholder(canvas, at, const Size(40, 60), '', hit);
      return;
    }
    hits[hit] = Rect.fromLTWH(
        at.dx - 32 * scale, at.dy - 66 * scale, 64 * scale, 66 * scale);
  }

  void _building(Canvas canvas, String atlas, String group, int frame,
      Offset at, double scale, String hit, String label) {
    final b = a[atlas];
    final g = b?.group(group) ?? const <String>[];
    if (b == null || g.isEmpty) {
      _placeholder(canvas, at, const Size(90, 90), label, hit);
      return;
    }
    final r = b.draw(canvas, g[frame.clamp(0, g.length - 1)], at, scale: scale);
    if (r != null) hits[hit] = r;
  }

  /// Up to 12 soldiers strolling around the camp: (kind, position, facing).
  List<(String, Offset, String)> _soldiers() {
    final out = <(String, Offset, String)>[];
    final kinds = [
      for (var i = 0; i < v.barbarians && i < 8; i++) 'barbarian',
      for (var i = 0; i < v.archers && i < 6; i++) 'archer',
    ].take(12).toList();
    for (var i = 0; i < kinds.length; i++) {
      final phase = i * 1.7;
      final x = sin(t * 0.35 + phase) * 110;
      final y = cos(t * 0.23 + phase * 1.3) * 45;
      final vel = Offset(cos(t * 0.35 + phase) * 110 * 0.35,
          -sin(t * 0.23 + phase * 1.3) * 45 * 0.23);
      out.add((kinds[i], _camp + Offset(x - 40, y + 70), facingOf(vel)));
    }
    return out;
  }

  void _soldier(Canvas canvas, (String, Offset, String) u) {
    final ok = drawSlot(canvas,
        lib: lib,
        atlases: a,
        overrides: anims,
        slot: '${u.$1}.walk',
        direction: u.$3,
        at: u.$2,
        t: t,
        scale: 1.4);
    if (!ok) {
      canvas.drawCircle(u.$2 - const Offset(0, 14), 10,
          Paint()..color = u.$1 == 'barbarian' ? Colors.orange : Colors.teal);
    }
  }

  void _walls(Canvas canvas) {
    if (v.fortifications <= 0) return;
    final w = a['walls_corners'];
    if (w == null) return;
    final g = w.group(Catalog.wallGroups[(v.fortifications - 1).clamp(0, 2)]);
    if (g.isEmpty) return;
    final seg = g.first;
    for (var x = 330.0; x <= 1070; x += 74) {
      w.draw(canvas, seg, Offset(x, 900), scale: 1.4);
    }
  }

  void _harvestBubble(Canvas canvas) {
    if (v.harvest <= 0) return;
    final ui = a['ui_elements_a'];
    final at = _mine + Offset(0, -170 + sin(t * 3) * 6);
    canvas.drawCircle(at, 30, Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawCircle(
        at,
        30,
        Paint()
          ..color = const Color(0xFFB8862B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    final coin = ui == null ? null : Catalog.coinIcon(ui);
    if (ui != null && coin != null) {
      ui.draw(canvas, coin, at, scale: 0.7);
    } else {
      canvas.drawCircle(at, 14, Paint()..color = const Color(0xFFF5C542));
    }
    final tp = TextPainter(
      text: TextSpan(
          text: '+${v.harvest}',
          style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 3)])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + Offset(-tp.width / 2, 30));
    final bubble = Rect.fromCircle(center: at, radius: 34);
    hits.remove('mine');
    hits['mine'] = bubble; // the bubble is the easiest thing to tap
  }

  void _placeholder(
      Canvas canvas, Offset pivot, Size sz, String label, String hit) {
    final r = Rect.fromLTWH(
        pivot.dx - sz.width / 2, pivot.dy - sz.height, sz.width, sz.height);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xFF8A6A3A));
    if (label.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(
            text: label,
            style: const TextStyle(color: Colors.white, fontSize: 18)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    }
    hits[hit] = r;
  }

  @override
  bool shouldRepaint(KingdomPainter old) => true;
}
