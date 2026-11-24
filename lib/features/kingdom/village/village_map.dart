import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/characters/rig_data.dart';
import '../../../core/characters/rig_poses.dart';
import '../../../core/game/catalog.dart';
import '../../../core/game/economy_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/quest_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/character_rig.dart';
import 'village_painters.dart';

const double stageW = 390;
const double stageH = 844;

/// What the village needs to know about the game, derived once per build.
class _Facts {
  _Facts(GameState s, DateTime now) {
    equipped = Catalog.byId[s.equipped['character']] ?? Catalog.byId['char_raider']!;
    heroes = Catalog.items.where((i) => i.type == ItemType.character).toList();
    busy = EconomyEngine.busyBuilders(s);
    claimable = QuestEngine.all(s, now).any((q) => q.claimable);
    final unowned = heroes.where((h) => !s.owned.contains(h.id)).toList()
      ..sort((a, b) => _cost(a).compareTo(_cost(b)));
    affordable = unowned.where((h) => canAfford(s, h)).toList();
    teaser = affordable.isNotEmpty
        ? affordable.first
        : (unowned.isEmpty ? null : unowned.first);
    treasuryReady = s.gold >=
        EconomyEngine.upgradeCost(s.buildingLevel('treasury') + 1) &&
        busy < EconomyEngine.builderSlots(s);
  }

  late final ShopItem equipped;
  late final List<ShopItem> heroes;
  late final int busy;
  late final bool claimable;
  late final List<ShopItem> affordable;
  late final ShopItem? teaser;
  late final bool treasuryReady;

  static int _cost(ShopItem i) => i.goldPrice ?? ((i.gemPrice ?? 0) * 10);

  static bool canAfford(GameState s, ShopItem i) =>
      (i.goldPrice != null && s.gold >= i.goldPrice!) ||
      (i.gemPrice != null && s.gems >= i.gemPrice!);
}

/// The animated village (Figma "Kingdom Home"): a 390x844 stage that is
/// scaled to fit the screen.
class VillageMap extends ConsumerStatefulWidget {
  const VillageMap({super.key});

  @override
  ConsumerState<VillageMap> createState() => _VillageMapState();
}

class _VillageMapState extends ConsumerState<VillageMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (CharacterRig.enableAnimation) {
      _t.repeat();
    } else {
      _t.value = 0.1;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  static const _trees = <(double, double, double, double)>[
    (8, 120, 44, 56), (52.2, 106, 39.6, 50.4), (318, 110, 44, 56),
    (347.3, 158, 37.4, 47.6), (132.4, 118, 35.2, 44.8), (232.2, 124, 39.6, 50.4),
    (2.9, 293, 46.2, 58.8), (12, 480, 44, 56), (340, 485, 44, 56),
    (1.8, 656, 48.4, 61.6), (339.8, 658, 48.4, 61.6), (131.3, 688, 37.4, 47.6),
    (228.2, 688, 39.6, 50.4), (336.6, 310, 30.8, 39.2), (26.4, 406, 35.2, 44.8),
  ];

  // Building origins (top-left) from the Figma frame.
  static const _origins = <String, Offset>{
    'keep': Offset(120, 232),
    'builders_hut': Offset(45, 416),
    'army_camp': Offset(245, 400),
    'laboratory': Offset(37, 164),
    'treasury': Offset(260, 206),
    'clan_castle': Offset(240, 524),
    'shop': Offset(36, 552),
    'magic_items': Offset(150, 582),
  };

  static const _names = <String, String>{
    'keep': 'Keep',
    'builders_hut': "Builder's Hut",
    'army_camp': 'Army Camp',
    'laboratory': 'Laboratory',
    'treasury': 'Treasury',
    'clan_castle': 'Clan Castle',
    'shop': 'Shop',
    'magic_items': 'Magic Items',
  };

  // Where resident heroes stand (top-left of a ~51x59 box).
  static const _heroSpots = <Offset>[
    Offset(56, 318), Offset(248, 346), Offset(292, 664), Offset(90, 366),
    Offset(158, 526), Offset(96, 650), Offset(190, 706), Offset(300, 590),
    Offset(196, 530), Offset(24, 600), Offset(185, 330), Offset(20, 230),
  ];

  void _openBuilding(String id) {
    switch (id) {
      case 'shop':
        context.go('/shop');
      case 'magic_items':
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
              content: Text('Magic Items are coming soon!'),
              duration: Duration(seconds: 2)));
      default:
        context.push('/building/$id');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final f = _Facts(s, now);
    final sprites = <(double, Widget)>[];

    for (final (i, t) in _trees.indexed) {
      sprites.add((
        t.$2 + t.$4,
        Positioned(
          left: t.$1,
          top: t.$2,
          child: _Sway(
              t: _t,
              phase: i * 0.7,
              child: VillageTree(size: Size(t.$3, t.$4))),
        ),
      ));
    }

    for (final e in _origins.entries) {
      final art = buildingArt[e.key]!;
      final upgrading = s.building(e.key).upgrading;
      String? badge;
      Color badgeColor = AppColors.danger;
      switch (e.key) {
        case 'builders_hut':
          if (f.busy > 0) badge = '${f.busy}';
        case 'army_camp':
          if (f.claimable) badge = '!';
        case 'treasury':
          if (f.treasuryReady) {
            badge = r'$';
            badgeColor = AppColors.success;
          }
        case 'shop':
          if (f.affordable.isNotEmpty) {
            badge = 'NEW';
            badgeColor = AppColors.gem;
          }
      }
      if (upgrading) {
        badge = '${EconomyEngine.daysLeft(s, e.key)}d';
        badgeColor = AppColors.panelLight;
      }
      final isBld = s.building(e.key).level > 0 && Catalog.buildingById.containsKey(e.key);
      final label = isBld
          ? '${_names[e.key]} ${s.buildingLevel(e.key)}'
          : _names[e.key]!;
      sprites.add((
        e.value.dy + art.size.height,
        Positioned(
          left: e.value.dx,
          top: e.value.dy,
          child: _BuildingSprite(
            key: Key('bld_${e.key}'),
            art: art,
            label: label,
            badge: badge,
            badgeColor: badgeColor,
            t: _t,
            upgrading: upgrading,
            smoke: e.key == 'builders_hut',
            flag: e.key == 'keep',
            onTap: () => _openBuilding(e.key),
          ),
        ),
      ));
    }

    // Builder at the hut.
    sprites.add((
      443.2 + 58.8,
      Positioned(
        left: 146,
        top: 443.2,
        child: _Actor(
          key: const Key('actor_builder'),
          slug: 'builder',
          anim: f.busy > 0 ? RigAnim.work : RigAnim.idle,
          onTap: () => _openBuilding('builders_hut'),
        ),
      ),
    ));

    // The equipped hero stands on the plaza and always shows a glow.
    final eqSlug = rigSlugForItemId(f.equipped.id);
    if (eqSlug != null) {
      sprites.add((
        446 + 58.8,
        Positioned(
          left: 206,
          top: 446,
          child: _Actor(
            key: const Key('actor_equipped'),
            slug: eqSlug,
            anim: RigAnim.idle,
            glow: AppColors.gold,
            t: _t,
            onTap: () => context.push('/character/${f.equipped.id}'),
          ),
        ),
      ));
    }

    // Every other owned hero lives in the village and wanders a little.
    var spot = 0;
    for (final h in f.heroes) {
      if (!s.owned.contains(h.id) ||
          h.id == f.equipped.id ||
          h.id == 'char_builder') {
        continue;
      }
      final slug = rigSlugForItemId(h.id);
      if (slug == null || spot >= _heroSpots.length) continue;
      final p = _heroSpots[spot];
      sprites.add((
        p.dy + 58.8,
        Positioned(
          left: p.dx,
          top: p.dy,
          child: _Wanderer(
            key: Key('hero_${h.id}'),
            slug: slug,
            t: _t,
            phase: spot * 0.37,
            amp: 8 + (spot % 3) * 4,
            walks: spot.isEven,
            onTap: () => context.push('/character/${h.id}'),
          ),
        ),
      ));
      spot++;
    }

    // Teaser: the next hero to buy, as a silhouette on a pedestal.
    if (f.teaser != null) {
      sprites.add((
        404,
        Positioned(
          left: 292,
          top: 308,
          child: _Teaser(
            key: const Key('teaser'),
            item: f.teaser!,
            state: s,
            t: _t,
            onTap: () => context.push('/character/${f.teaser!.id}'),
          ),
        ),
      ));
    }

    // Chests waiting to be opened.
    const chestSpots = [Offset(168, 496), Offset(212, 500), Offset(124, 522)];
    final types = s.chests.toSet().take(3).toList();
    for (final (i, type) in types.indexed) {
      final p = chestSpots[i];
      sprites.add((
        p.dy + 44,
        Positioned(
          left: p.dx,
          top: p.dy,
          child: _Chest(
            key: Key('chest_$type'),
            type: type,
            count: s.chests.where((c) => c == type).length,
            t: _t,
            phase: i * 0.3,
            onTap: () => openChestDialog(context, ref, type),
          ),
        ),
      ));
    }

    sprites.sort((a, b) => a.$1.compareTo(b.$1));

    return Container(
      color: const Color(0xFF6DBB3A),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: stageW,
            height: stageH,
            child: ClipRect(
              child: Stack(clipBehavior: Clip.none, children: [
                const Positioned.fill(child: _Ground()),
                Positioned.fill(
                    child: _Ambient(t: _t, treasury: s.buildingLevel('treasury'))),
                for (final sp in sprites) sp.$2,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens a chest and shows the reward (shared with the old home screen).
Future<void> openChestDialog(
    BuildContext context, WidgetRef ref, String type) async {
  final r = ref.read(gameProvider.notifier).openChest(type);
  if (r == null || !context.mounted) return;
  final item = r.itemId == null ? null : Catalog.byId[r.itemId!];
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.outline, width: 4),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Chest opened!',
              style: AppText.headingPlain(26, color: AppColors.panelPrimary)),
          const SizedBox(height: 12),
          Text('+${r.gold} gold', style: AppText.body(18)),
          if (r.gems > 0) Text('+${r.gems} gems', style: AppText.body(18)),
          if (item != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: rigSlugForItemId(item.id) == null
                  ? const SizedBox()
                  : CharacterRig(
                      slug: rigSlugForItemId(item.id)!,
                      height: 96,
                      anim: RigAnim.celebrate),
            ),
            Text('New hero: ${item.name}!', style: AppText.body(16)),
          ],
          const SizedBox(height: 14),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Great!')),
        ]),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Ground
// ---------------------------------------------------------------------------

class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) => const CustomPaint(painter: _GroundPainter());
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF8CCC4D), Color(0xFF70BF3B), Color(0xFF549E2E)],
          ).createShader(rect));

    // Grass tufts.
    final rnd = math.Random(7);
    final tuft = Paint()..color = const Color(0x2233691F);
    for (var i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 16, height: 6), tuft);
    }
    final flower = [Colors.white, const Color(0xFFFFE27A), const Color(0xFFFF9EC4)];
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
          Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
          2.2,
          Paint()..color = flower[i % 3]);
    }

    // Paths from the plaza to every building.
    const plaza = Offset(197, 478);
    const targets = [
      Offset(195, 410), // keep gate
      Offset(98, 460), // hut
      Offset(300, 450), // camp
      Offset(83, 312), // lab
      Offset(314, 312), // treasury
      Offset(300, 640), // castle
      Offset(92, 646), // shop
      Offset(195, 700), // magic items
    ];
    final edge = Paint()
      ..color = const Color(0xFFA9763F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = AppColors.path
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    for (final t in targets) {
      final p = Path()
        ..moveTo(plaza.dx, plaza.dy)
        ..quadraticBezierTo((plaza.dx + t.dx) / 2 + (t.dy - plaza.dy) * 0.08,
            (plaza.dy + t.dy) / 2, t.dx, t.dy);
      canvas.drawPath(p, edge);
    }
    for (final t in targets) {
      final p = Path()
        ..moveTo(plaza.dx, plaza.dy)
        ..quadraticBezierTo((plaza.dx + t.dx) / 2 + (t.dy - plaza.dy) * 0.08,
            (plaza.dy + t.dy) / 2, t.dx, t.dy);
      canvas.drawPath(p, fill);
    }

    // Plaza (stone ring with a path-coloured centre).
    final pr = Rect.fromCenter(center: plaza, width: 132, height: 84);
    canvas.drawOval(pr.inflate(5), Paint()..color = AppColors.outline);
    canvas.drawOval(pr, Paint()..color = AppColors.stone);
    canvas.drawOval(pr.deflate(10), Paint()..color = const Color(0xFFE2D9C2));

    // Pond.
    final pond = Rect.fromLTWH(30, 690, 100, 56);
    canvas.drawOval(pond.inflate(4), Paint()..color = AppColors.outline);
    canvas.drawOval(pond, Paint()..color = const Color(0xFF4FB6F0));
    canvas.drawOval(pond.deflate(8), Paint()..color = const Color(0xFF79CFFA));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ---------------------------------------------------------------------------
// Ambient life: clouds, ripples, fireflies, sparkles
// ---------------------------------------------------------------------------

class _Ambient extends StatelessWidget {
  const _Ambient({required this.t, required this.treasury});
  final Animation<double> t;
  final int treasury;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: t,
          builder: (_, __) => CustomPaint(painter: _AmbientPainter(t.value)),
        ),
      );
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter(this.v);
  final double v;

  @override
  void paint(Canvas canvas, Size size) {
    final a = v * 2 * math.pi;

    // Pond ripples.
    for (var i = 0; i < 2; i++) {
      final k = ((v * 4 + i * .5) % 1);
      canvas.drawOval(
          Rect.fromCenter(
              center: const Offset(80, 718), width: 20 + 50 * k, height: 8 + 20 * k),
          Paint()
            ..color = Colors.white.withOpacity(.6 * (1 - k))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // Fireflies / sparkles drifting around the village.
    for (var i = 0; i < 14; i++) {
      final bx = (i * 97 + 31) % 370 + 10.0;
      final by = (i * 151 + 120) % 640 + 100.0;
      final ph = a * (1 + i % 3) + i;
      final x = bx + 10 * math.sin(ph);
      final y = by + 8 * math.cos(ph * .8);
      final tw = (math.sin(a * 6 + i * 1.3) + 1) / 2;
      canvas.drawCircle(Offset(x, y), 3.2 * tw + 1,
          Paint()..color = const Color(0xFFFFF3A8).withOpacity(.25 + .6 * tw));
    }

    // Clouds drifting across (soft shadows on the grass).
    for (var i = 0; i < 3; i++) {
      final k = (v * (1 + i) + i * .33) % 1;
      final x = -120 + k * 640;
      final y = 220 + i * 200.0;
      final p = Paint()..color = const Color(0x1A000000);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 110, height: 34), p);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x + 30, y - 8), width: 70, height: 30), p);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter old) => old.v != v;
}

// ---------------------------------------------------------------------------
// Sprites
// ---------------------------------------------------------------------------

class _Sway extends StatelessWidget {
  const _Sway({required this.t, required this.phase, required this.child});
  final Animation<double> t;
  final double phase;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: t,
        child: child,
        builder: (_, c) => Transform.rotate(
          angle: 0.045 * math.sin(t.value * 2 * math.pi * 12 + phase),
          alignment: Alignment.bottomCenter,
          child: c,
        ),
      );
}

class _BuildingSprite extends StatefulWidget {
  const _BuildingSprite({
    super.key,
    required this.art,
    required this.label,
    required this.t,
    required this.onTap,
    this.badge,
    this.badgeColor = AppColors.danger,
    this.upgrading = false,
    this.smoke = false,
    this.flag = false,
  });

  final BuildingArt art;
  final String label;
  final String? badge;
  final Color badgeColor;
  final Animation<double> t;
  final bool upgrading;
  final bool smoke;
  final bool flag;
  final VoidCallback onTap;

  @override
  State<_BuildingSprite> createState() => _BuildingSpriteState();
}

class _BuildingSpriteState extends State<_BuildingSprite> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.art;
    const plateH = 22.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 90),
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: a.size.width,
          height: a.size.height + plateH,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(
              left: 0,
              top: 0,
              width: a.size.width,
              height: a.size.height,
              child: Stack(clipBehavior: Clip.none, children: [
                ...a.build(),
                if (widget.flag)
                  Positioned(
                    left: 75,
                    top: -22,
                    child: AnimatedBuilder(
                      animation: widget.t,
                      builder: (_, __) => Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.diagonal3Values(1 + 0.18 * math.sin(widget.t.value * 2 * math.pi * 40), 1, 1),
                        child: const CustomPaint(
                            size: Size(22, 12), painter: _FlagPainter()),
                      ),
                    ),
                  ),
                if (widget.smoke) _Smoke(t: widget.t),
                if (widget.upgrading) _Hammer(t: widget.t, w: a.size.width),
              ]),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: a.size.height - 2,
              child: Center(child: NamePlate(widget.label)),
            ),
            if (widget.badge != null)
              Positioned(
                right: -4,
                top: -8,
                child: _Pulse(
                    t: widget.t,
                    child: VillageBadge(widget.badge!, widget.badgeColor)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter();
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.danger);
    canvas.drawPath(
        p,
        Paint()
          ..color = AppColors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _Smoke extends StatelessWidget {
  const _Smoke({required this.t});
  final Animation<double> t;

  @override
  Widget build(BuildContext context) => Positioned(
        left: 70,
        top: -44,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: t,
            builder: (_, __) => SizedBox(
              width: 40,
              height: 50,
              child: CustomPaint(painter: _SmokePainter(t.value)),
            ),
          ),
        ),
      );
}

class _SmokePainter extends CustomPainter {
  _SmokePainter(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < 3; i++) {
      final k = (v * 24 / 3 * 1 + i / 3) % 1; // ~8 puffs per loop
      final y = s.height * (1 - k);
      final x = 14 + 8 * math.sin(k * 5 + i);
      canvas.drawCircle(
          Offset(x, y),
          4 + 7 * k,
          Paint()..color = Colors.white.withOpacity(.75 * (1 - k)));
    }
  }

  @override
  bool shouldRepaint(_SmokePainter old) => old.v != v;
}

class _Hammer extends StatelessWidget {
  const _Hammer({required this.t, required this.w});
  final Animation<double> t;
  final double w;

  @override
  Widget build(BuildContext context) => Positioned(
        left: w / 2 - 14,
        top: 6,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: t,
            builder: (_, __) => Transform.rotate(
              angle: -0.5 + 0.7 * math.sin(t.value * 2 * math.pi * 60).abs(),
              alignment: Alignment.bottomRight,
              child: const Icon(Icons.hardware,
                  size: 28,
                  color: Colors.white,
                  shadows: [Shadow(color: AppColors.outline, blurRadius: 3)]),
            ),
          ),
        ),
      );
}

class _Pulse extends StatelessWidget {
  const _Pulse({required this.t, required this.child});
  final Animation<double> t;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: t,
        child: child,
        builder: (_, c) => Transform.scale(
            scale: 1 + 0.1 * math.sin(t.value * 2 * math.pi * 48), child: c),
      );
}

const _actorW = 51.0;
const _actorH = 58.8;

class _Actor extends StatelessWidget {
  const _Actor({
    super.key,
    required this.slug,
    required this.anim,
    required this.onTap,
    this.glow,
    this.t,
  });

  final String slug;
  final RigAnim anim;
  final VoidCallback onTap;
  final Color? glow;
  final Animation<double>? t;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: _actorW,
        height: _actorH,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          if (glow != null && t != null)
            Positioned(
              bottom: -2,
              child: AnimatedBuilder(
                animation: t!,
                builder: (_, __) {
                  final k = (math.sin(t!.value * 2 * math.pi * 36) + 1) / 2;
                  return Container(
                    width: 58 + 6 * k,
                    height: 16 + 2 * k,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: glow!.withOpacity(.35 + .3 * k),
                            blurRadius: 14,
                            spreadRadius: 3)
                      ],
                    ),
                  );
                },
              ),
            ),
          CharacterRig(slug: slug, height: _actorH, anim: anim),
        ]),
      ),
    );
  }
}

/// A hero that strolls back and forth around its spot.
class _Wanderer extends StatelessWidget {
  const _Wanderer({
    super.key,
    required this.slug,
    required this.t,
    required this.phase,
    required this.amp,
    required this.walks,
    required this.onTap,
  });

  final String slug;
  final Animation<double> t;
  final double phase;
  final double amp;
  final bool walks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) {
        final p = (t.value * 12 + phase) * 2 * math.pi;
        final dx = walks ? amp * math.sin(p) : 0.0;
        final facingLeft = walks && math.cos(p) < 0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scaleX: facingLeft ? -1 : 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: SizedBox(
                width: _actorW,
                height: _actorH,
                child: CharacterRig(
                  slug: slug,
                  height: _actorH,
                  anim: walks ? RigAnim.walk : RigAnim.idle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The next hero to buy: a dark silhouette on a glowing pedestal with a
/// price tag that says how far away the goal is.
class _Teaser extends StatelessWidget {
  const _Teaser({
    super.key,
    required this.item,
    required this.state,
    required this.t,
    required this.onTap,
  });

  final ShopItem item;
  final GameState state;
  final Animation<double> t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final slug = rigSlugForItemId(item.id);
    final affordable = _Facts.canAfford(state, item);
    final useGold = item.goldPrice != null;
    final price = useGold ? item.goldPrice! : item.gemPrice!;
    final have = useGold ? state.gold : state.gems;
    final unit = useGold ? 'gold' : 'gems';
    final color = rarityOf(item.rarity).color;
    final text = affordable ? 'Tap to unlock!' : '${price - have} $unit to go';

    return Transform.scale(
      scale: 0.85,
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 74,
        height: 96,
        child: AnimatedBuilder(
          animation: t,
          builder: (_, __) {
            final k = (math.sin(t.value * 2 * math.pi * 30) + 1) / 2;
            return Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
              // pedestal glow
              Positioned(
                bottom: 6,
                child: Container(
                  width: 62,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.stone,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.outline, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(affordable ? .5 + .4 * k : .25),
                          blurRadius: 14 + 6 * k,
                          spreadRadius: 2)
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 14 + (affordable ? 3 * k : 0),
                child: slug == null
                    ? const SizedBox()
                    : ColorFiltered(
                        colorFilter: ColorFilter.mode(
                            affordable
                                ? Colors.transparent
                                : const Color(0xFF1A1030).withOpacity(.86),
                            affordable ? BlendMode.dst : BlendMode.srcATop),
                        child: CharacterRig(
                            slug: slug,
                            height: 58,
                            anim: affordable ? RigAnim.jump : RigAnim.idle),
                      ),
              ),
              if (!affordable)
                Positioned(
                  top: 6 - 3 * k,
                  child: Text('?',
                      style: AppText.heading(24, color: AppColors.gold)),
                ),
              Positioned(
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: affordable ? AppColors.success : AppColors.panelDeep,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                  child: Text(text,
                      style: AppText.body(10,
                          color: Colors.white, weight: FontWeight.w800)),
                ),
              ),
            ]);
          },
        ),
      ),
      ),
    );
  }
}

class _Chest extends StatelessWidget {
  const _Chest({
    super.key,
    required this.type,
    required this.count,
    required this.t,
    required this.phase,
    required this.onTap,
  });

  final String type;
  final int count;
  final Animation<double> t;
  final double phase;
  final VoidCallback onTap;

  Color get _color => switch (type) {
        'silver' => const Color(0xFFC9D2DC),
        'golden' => AppColors.gold,
        'legendary' => AppColors.gem,
        _ => AppColors.wood,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedBuilder(
        animation: t,
        builder: (_, __) {
          final b = math.sin((t.value * 30 + phase) * 2 * math.pi);
          return Transform.translate(
            offset: Offset(0, -4 * (b + 1) / 2),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 2,
                  top: 14,
                  width: 40,
                  height: 28,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.woodDark,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.outline, width: 2.5),
                    ),
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 6,
                  width: 40,
                  height: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      border: Border.all(color: AppColors.outline, width: 2.5),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 18,
                  width: 8,
                  height: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      border: Border.all(color: AppColors.outline, width: 1.5),
                    ),
                  ),
                ),
                if (count > 1)
                  Positioned(
                      right: -6,
                      top: -4,
                      child: VillageBadge('x$count', AppColors.danger)),
              ]),
            ),
          );
        },
      ),
    );
  }
}
