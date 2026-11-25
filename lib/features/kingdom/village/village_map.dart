import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/characters/rig_data.dart';
import '../../../core/characters/rig_poses.dart';
import '../../../core/game/catalog.dart';
import '../../../core/game/economy_engine.dart';
import '../../../core/game/game_engine.dart';
import '../../../core/game/models.dart';
import '../../../core/game/quest_engine.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/character_rig.dart';
import '../../../core/world/season.dart';
import '../../../core/world/world_layout.dart';
import 'world_actors.dart';
import 'world_painters.dart';

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
    teaser = affordable.isNotEmpty ? affordable.first : (unowned.isEmpty ? null : unowned.first);
    treasuryReady = s.gold >= EconomyEngine.upgradeCost(s.buildingLevel('treasury') + 1) &&
        busy < EconomyEngine.builderSlots(s);
    level = GameEngine.level(s);
    streak = GameEngine.currentStreak(s, now);
    due = s.habits.where((h) => !h.archived && h.isDueOn(now)).length;
    done = GameEngine.completedToday(s, now);
  }

  late final ShopItem equipped;
  late final List<ShopItem> heroes;
  late final int busy;
  late final bool claimable;
  late final List<ShopItem> affordable;
  late final ShopItem? teaser;
  late final bool treasuryReady;
  late final int level, streak, due, done;

  static int _cost(ShopItem i) => i.goldPrice ?? ((i.gemPrice ?? 0) * 10);

  static bool canAfford(GameState s, ShopItem i) =>
      (i.goldPrice != null && s.gold >= i.goldPrice!) ||
      (i.gemPrice != null && s.gems >= i.gemPrice!);
}

/// The living kingdom: a pannable, zoomable world with seasons, buildings,
/// the player's Warden and a wandering dragon.
class VillageMap extends ConsumerStatefulWidget {
  const VillageMap({super.key});

  @override
  ConsumerState<VillageMap> createState() => _VillageMapState();
}

class _VillageMapState extends ConsumerState<VillageMap> with TickerProviderStateMixin {
  final _time = ValueNotifier<double>(0);
  late final WorldSim _sim;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  final _camera = TransformationController();
  AnimationController? _fly;
  Size? _viewport;
  final _rnd = math.Random();

  bool get _animated => CharacterRig.enableAnimation;

  static const _home = Offset(550, 790);

  static Set<String> _unlockedFor(int level) => {
        for (final r in WorldLayout.regions)
          if (level >= r.unlockLevel) r.id,
      };

  @override
  void initState() {
    super.initState();
    _sim = WorldSim(unlockedRegions: _unlockedFor(GameEngine.level(ref.read(gameProvider))));
    if (_animated) {
      _ticker = createTicker(_onTick)..start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time.value = elapsed.inMicroseconds / 1e6;
    _sim.tick(dt);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _fly?.dispose();
    _camera.dispose();
    _time.dispose();
    _sim.dispose();
    super.dispose();
  }

  // ---- Camera ----

  double _minScale(Size vp) =>
      math.max(vp.width / WorldLayout.size.width, vp.height / WorldLayout.size.height);

  Matrix4 _view(Size vp, Offset focus, double scale) {
    final s = scale.clamp(_minScale(vp), 2.2);
    final w = WorldLayout.size.width * s, h = WorldLayout.size.height * s;
    final tx = (vp.width / 2 - focus.dx * s).clamp(vp.width - w, 0.0);
    final ty = (vp.height / 2 - focus.dy * s).clamp(vp.height - h, 0.0);
    // Column-major: scale on the diagonal, translation in the last column.
    return Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  double _homeScale(Size vp) => (vp.width / 470).clamp(_minScale(vp), 1.8);

  void _flyTo(Offset focus, {double? scale}) {
    final vp = _viewport;
    if (vp == null) return;
    final target = _view(vp, focus, scale ?? _camera.value.getMaxScaleOnAxis());
    if (!_animated) {
      _camera.value = target;
      return;
    }
    _fly?.dispose();
    final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _fly = c;
    final anim = Matrix4Tween(begin: _camera.value.clone(), end: target)
        .animate(CurvedAnimation(parent: c, curve: Curves.easeInOutCubic));
    anim.addListener(() => _camera.value = anim.value);
    c.forward();
  }

  // ---- Interactions ----

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  void _openBuilding(String id) {
    switch (id) {
      case 'shop':
        context.go('/shop');
      case 'magic_items':
        _toast('Magic Items are coming soon!');
      default:
        context.push('/building/$id');
    }
  }

  void _tapHero(_Facts f) {
    HapticFeedback.lightImpact();
    _sim.hero.react(heroLine(_rnd, due: f.due, done: f.done, streak: f.streak));
  }

  void _tapDragon() {
    HapticFeedback.mediumImpact();
    _sim.dragon.react();
  }

  void _tapRegion(WorldRegion r, bool locked) {
    _flyTo(r.label);
    _toast(locked ? 'Reach level ${r.unlockLevel} to explore ${r.name}.' : r.name);
  }

  // ---- Build ----

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final season = ref.watch(seasonProvider);
    final skin = ref.watch(dragonSkinProvider);
    final now = ref.watch(clockProvider)();
    final f = _Facts(s, now);
    _sim.unlocked = _unlockedFor(f.level);
    final locked = [
      for (final r in WorldLayout.regions)
        if (f.level < r.unlockLevel) r,
    ];

    // Static sprites (rebuilt when the game state changes).
    final statics = <_Sprite>[
      for (final spot in WorldLayout.buildings.values) _buildingSprite(s, f, spot, season),
    ];
    statics.add(_heroSprite(
      key: 'actor_builder',
      slug: 'builder',
      ground: WorldLayout.door('builders_hut') + const Offset(44, 2),
      anim: f.busy > 0 ? RigAnim.work : RigAnim.idle,
      onTap: () => _openBuilding('builders_hut'),
    ));
    final eqSlug = rigSlugForItemId(f.equipped.id);
    if (eqSlug != null) {
      statics.add(_heroSprite(
        key: 'actor_equipped',
        slug: eqSlug,
        ground: WorldLayout.plaza + const Offset(58, 12),
        anim: RigAnim.idle,
        glow: AppColors.gold,
        onTap: () => context.push('/character/${f.equipped.id}'),
      ));
    }
    var spot = 0;
    for (final h in f.heroes) {
      if (!s.owned.contains(h.id) || h.id == f.equipped.id || h.id == 'char_builder') continue;
      final slug = rigSlugForItemId(h.id);
      if (slug == null || spot >= _residentSpots.length) continue;
      final p = _residentSpots[spot];
      statics.add(_Sprite(
        p.dy,
        Positioned(
          key: ValueKey('hero_${h.id}'),
          left: p.dx - _actorW / 2,
          top: p.dy - _actorH,
          child: _Wanderer(
            slug: slug,
            time: _time,
            phase: spot * 0.9,
            amp: 8 + (spot % 3) * 4.0,
            walks: spot.isEven,
            onTap: () => context.push('/character/${h.id}'),
          ),
        ),
      ));
      spot++;
    }
    if (f.teaser != null) {
      final p = WorldLayout.plaza + const Offset(-118, 4);
      statics.add(_Sprite(
        p.dy,
        Positioned(
          key: const ValueKey('teaser'),
          left: p.dx - 37,
          top: p.dy - 92,
          child: _Teaser(
            item: f.teaser!,
            state: s,
            time: _time,
            onTap: () => context.push('/character/${f.teaser!.id}'),
          ),
        ),
      ));
    }
    const chestSpots = [Offset(-22, 74), Offset(16, 80), Offset(-58, 64)];
    for (final (i, type) in s.chests.toSet().take(3).indexed) {
      final p = WorldLayout.plaza + chestSpots[i];
      statics.add(_Sprite(
        p.dy,
        Positioned(
          key: ValueKey('chest_$type'),
          left: p.dx - 22,
          top: p.dy - 40,
          child: _Chest(
            type: type,
            count: s.chests.where((c) => c == type).length,
            time: _time,
            phase: i * 0.3,
            onTap: () => openChestDialog(context, ref, type),
          ),
        ),
      ));
    }

    final world = SizedBox(
      width: WorldLayout.size.width,
      height: WorldLayout.size.height,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: GroundPainter(season))),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
                child: CustomPaint(painter: LivingPainter(time: _time, season: season))),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _sim,
            builder: (context, _) {
              final all = [...statics, ..._actors(f, skin)]
                ..sort((a, b) => a.baseline.compareTo(b.baseline));
              return Stack(clipBehavior: Clip.none, children: [for (final a in all) a.widget]);
            },
          ),
        ),
        if (locked.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                    painter: FogPainter(time: _time, locked: locked, tint: season.skyBottom)),
              ),
            ),
          ),
        for (final r in WorldLayout.regions)
          Positioned(
            key: ValueKey('region_${r.id}'),
            left: r.label.dx - 90,
            top: r.label.dy - 24,
            width: 180,
            child: Center(
              child: _RegionSign(
                region: r,
                locked: locked.contains(r),
                onTap: () => _tapRegion(r, locked.contains(r)),
              ),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: season.light.withValues(alpha: season.lightStrength)),
          ),
        ),
      ]),
    );

    return LayoutBuilder(builder: (context, box) {
      final vp = box.biggest;
      if (_viewport == null) {
        _camera.value = _view(vp, _home, _homeScale(vp));
      } else if ((_viewport!.width - vp.width).abs() > 1 ||
          (_viewport!.height - vp.height).abs() > 1) {
        SchedulerBinding.instance
            .addPostFrameCallback((_) => _camera.value = _view(vp, _home, _homeScale(vp)));
      }
      _viewport = vp;
      final bottomInset = MediaQuery.of(context).padding.bottom;
      return Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [season.skyTop, season.skyBottom],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: InteractiveViewer(
            transformationController: _camera,
            constrained: false,
            minScale: _minScale(vp),
            maxScale: 2.2,
            boundaryMargin: EdgeInsets.zero,
            child: world,
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: WeatherPainter(time: _time, season: season)),
            ),
          ),
        ),
        // Soft vignette keeps the eye in the middle and the HUD readable.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.05,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                  stops: const [0.62, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 104 + bottomInset,
          child: Column(children: [
            _MapButton(
              key: const Key('map_recenter'),
              icon: Icons.my_location_rounded,
              tooltip: 'Find my hero',
              onTap: () => _flyTo(_sim.hero.pos, scale: math.max(_homeScale(vp), 1.15)),
            ),
            const SizedBox(height: 10),
            _MapButton(
              key: const Key('map_overview'),
              icon: Icons.zoom_out_map_rounded,
              tooltip: 'Whole kingdom',
              onTap: () => _flyTo(WorldLayout.size.center(Offset.zero), scale: _minScale(vp)),
            ),
          ]),
        ),
      ]);
    });
  }

  /// Hero and dragon sprites for the current frame.
  List<_Sprite> _actors(_Facts f, String skin) {
    final out = <_Sprite>[];
    final h = _sim.hero;
    const hh = 74.0;
    const hw = hh * 120 / 160;
    out.add(_Sprite(
      h.pos.dy,
      Positioned(
        key: const ValueKey('actor_hero'),
        left: h.pos.dx - hw / 2,
        top: h.pos.dy - hh * 150 / 160,
        width: hw,
        height: hh,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapHero(f),
          child: Stack(clipBehavior: Clip.none, children: [
            Transform.flip(
              flipX: h.facingLeft,
              child: CharacterRig(slug: 'warden', height: hh, anim: h.anim),
            ),
            if (h.bubble != null)
              Positioned(
                left: -80,
                right: -80,
                bottom: hh + 2,
                child: Center(
                  child: Opacity(opacity: h.bubbleOpacity, child: _Bubble(h.bubble!)),
                ),
              ),
          ]),
        ),
      ),
    ));

    final d = _sim.dragon;
    const dh = 104.0;
    const dw = dh * 180 / 160;
    final lift = d.alt * DragonSim.cruise;
    // The ground shadow stays on the ground and shrinks as the dragon climbs.
    final sw = 70 * (1 - 0.45 * d.alt);
    out.add(_Sprite(
      d.pos.dy - 0.5,
      Positioned(
        key: const ValueKey('dragon_shadow'),
        left: d.pos.dx - sw / 2,
        top: d.pos.dy - 6,
        width: sw,
        height: 12,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.26 - 0.12 * d.alt),
              borderRadius: const BorderRadius.all(Radius.elliptical(40, 8)),
            ),
          ),
        ),
      ),
    ));
    out.add(_Sprite(
      // A flying dragon draws above everything on the ground.
      d.pos.dy + (d.alt > 0.2 ? 2000 : 0),
      Positioned(
        key: const ValueKey('actor_dragon'),
        left: d.pos.dx - dw * 92 / 180,
        top: d.pos.dy - dh * 142 / 160 - lift,
        width: dw,
        height: dh,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _tapDragon,
          child: Transform.flip(
            flipX: d.facingLeft,
            child: Stack(clipBehavior: Clip.none, children: [
              CharacterRig(slug: skin, height: dh, anim: d.anim, hiddenRoles: const {'shadow'}),
              if (d.fire > 0)
                Positioned(
                  left: dw * 166 / 180,
                  top: dh * 60 / 160 - 6 * d.fire,
                  child: IgnorePointer(child: _FirePuff(progress: d.fire, skin: skin)),
                ),
            ]),
          ),
        ),
      ),
    ));
    return out;
  }

  static final List<Offset> _residentSpots = [
    WorldLayout.door('laboratory') + const Offset(-50, 20),
    WorldLayout.door('treasury') + const Offset(54, 16),
    WorldLayout.door('army_camp') + const Offset(-60, 28),
    WorldLayout.door('shop') + const Offset(56, 18),
    WorldLayout.door('magic_items') + const Offset(-54, 22),
    WorldLayout.door('clan_castle') + const Offset(-80, 6),
    WorldLayout.door('keep') + const Offset(-96, 40),
    WorldLayout.door('keep') + const Offset(96, 40),
    WorldLayout.door('army_camp') + const Offset(60, 30),
    WorldLayout.door('clan_castle') + const Offset(84, 8),
    WorldLayout.door('builders_hut') + const Offset(-56, 26),
    WorldLayout.door('laboratory') + const Offset(52, 26),
  ];

  _Sprite _buildingSprite(GameState s, _Facts f, BuildingSpot spot, SeasonPack season) {
    final id = spot.id;
    final st = s.building(id);
    String? badge;
    var badgeColor = AppColors.danger;
    switch (id) {
      case 'builders_hut':
        if (f.busy > 0) badge = '${f.busy}';
      case 'army_camp':
        if (f.claimable) badge = '!';
      case 'treasury':
        if (f.treasuryReady) {
          badge = r'$';
          badgeColor = const Color(0xFF3FAE73);
        }
      case 'shop':
        if (f.affordable.isNotEmpty) {
          badge = 'NEW';
          badgeColor = AppColors.gem;
        }
    }
    if (st.upgrading) {
      badge = '${EconomyEngine.daysLeft(s, id)}d';
      badgeColor = const Color(0xFF4C7BE0);
    }
    final hasLevel = Catalog.buildingById.containsKey(id);
    // Buildings grow a little with every level.
    final sc = spot.scale * (1 + 0.025 * (st.level - 1)).clamp(1.0, 1.3);
    final w = spot.size.width * sc, h = spot.size.height * sc;
    return _Sprite(
      spot.anchor.dy,
      Positioned(
        key: ValueKey('bld_$id'),
        left: spot.anchor.dx - spot.pivot.dx * sc,
        top: spot.anchor.dy - spot.pivot.dy * sc,
        width: w,
        height: h,
        child: _BuildingSprite(
          id: id,
          label: hasLevel ? '${spot.name}  ${st.level}' : spot.name,
          badge: badge,
          badgeColor: badgeColor,
          snow: season.snowOnRoofs,
          upgrading: st.upgrading,
          time: _time,
          labelTop: spot.pivot.dy * sc + 4,
          onTap: () => _openBuilding(id),
        ),
      ),
    );
  }

  _Sprite _heroSprite({
    required String key,
    required String slug,
    required Offset ground,
    required RigAnim anim,
    required VoidCallback onTap,
    Color? glow,
  }) =>
      _Sprite(
        ground.dy,
        Positioned(
          key: ValueKey(key),
          left: ground.dx - _actorW / 2,
          top: ground.dy - _actorH,
          child: _Actor(key: Key(key), slug: slug, anim: anim, glow: glow, time: _time, onTap: onTap),
        ),
      );
}

class _Sprite {
  const _Sprite(this.baseline, this.widget);
  final double baseline;
  final Widget widget;
}

const _actorW = 51.0;
const _actorH = 58.8;

// ---------------------------------------------------------------------------
// Sprites
// ---------------------------------------------------------------------------

class _BuildingSprite extends StatefulWidget {
  const _BuildingSprite({
    required this.id,
    required this.label,
    required this.badge,
    required this.badgeColor,
    required this.snow,
    required this.upgrading,
    required this.time,
    required this.labelTop,
    required this.onTap,
  });

  final String id;
  final String label;
  final String? badge;
  final Color badgeColor;
  final bool snow;
  final bool upgrading;
  final ValueNotifier<double> time;
  final double labelTop;
  final VoidCallback onTap;

  @override
  State<_BuildingSprite> createState() => _BuildingSpriteState();
}

class _BuildingSpriteState extends State<_BuildingSprite> with SingleTickerProviderStateMixin {
  late final AnimationController _press =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    if (CharacterRig.enableAnimation) await _press.forward(from: 0);
    if (mounted) widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final art = Stack(fit: StackFit.expand, children: [
      SvgPicture.asset('assets/buildings/${widget.id}.svg', fit: BoxFit.fill),
      if (widget.snow)
        SvgPicture.asset('assets/buildings/${widget.id}_snow.svg', fit: BoxFit.fill),
    ]);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _tap,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _press,
            child: art,
            builder: (_, child) {
              // Squash on press, spring back up.
              final t = _press.value;
              final k = t < 0.4
                  ? -0.07 * (t / 0.4)
                  : -0.07 + 0.11 * math.sin((t - 0.4) / 0.6 * math.pi);
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(1 - k * 0.5, 1 + k, 1),
                child: child,
              );
            },
          ),
        ),
        Positioned(
          left: -40,
          right: -40,
          top: widget.labelTop,
          child: Center(child: _Plate(widget.label)),
        ),
        if (widget.badge != null)
          Positioned(
            right: 6,
            top: 4,
            child: ValueListenableBuilder<double>(
              valueListenable: widget.time,
              builder: (_, t, child) => Transform.translate(
                offset: Offset(0, -3 * (math.sin(t * 3) + 1) / 2),
                child: child,
              ),
              child: _Badge(widget.badge!, widget.badgeColor),
            ),
          ),
        if (widget.upgrading)
          Positioned(
            left: 4,
            top: 6,
            child: ValueListenableBuilder<double>(
              valueListenable: widget.time,
              builder: (_, t, child) => Transform.rotate(
                angle: -0.5 + 0.6 * math.max(0, math.sin(t * 6)),
                alignment: Alignment.bottomRight,
                child: child,
              ),
              child: const _RoundIcon(Icons.hardware_rounded, Color(0xFF4C7BE0)),
            ),
          ),
      ]),
    );
  }
}

/// Name plate under a building.
class _Plate extends StatelessWidget {
  const _Plate(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xCC12151E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(text,
            maxLines: 1,
            style: AppText.body(10.5, color: Colors.white, weight: FontWeight.w800)
                .copyWith(letterSpacing: 0.2)),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8)],
        ),
        child: Text(label,
            style: AppText.body(11.5, color: Colors.white, weight: FontWeight.w900)),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon(this.icon, this.color);
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(icon, size: 15, color: Colors.white),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFDF7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xB31A1622), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3))
          ],
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: AppText.body(11, color: const Color(0xFF1C2233), weight: FontWeight.w800)),
      );
}

class _FirePuff extends StatelessWidget {
  const _FirePuff({required this.progress, required this.skin});
  final double progress;
  final String skin;

  @override
  Widget build(BuildContext context) {
    final cols = switch (skin) {
      'dragon_frost' => const [Color(0xFFFFFFFF), Color(0xFF9DE6FF), Color(0xFF3F88B8)],
      'dragon_shadow' => const [Color(0xFFF2D6FF), Color(0xFFB26BFF), Color(0xFF4A1F8A)],
      'dragon_verdant' => const [Color(0xFFF4FFC4), Color(0xFF9BE05E), Color(0xFF3F8A33)],
      _ => const [Color(0xFFFFF6C2), Color(0xFFFFB43A), Color(0xFFE5482A)],
    };
    final p = progress;
    final fade = p < 0.2 ? p / 0.2 : (1 - (p - 0.2) / 0.8);
    return SizedBox(
      width: 70,
      height: 40,
      child: Stack(clipBehavior: Clip.none, children: [
        for (var i = 0; i < 6; i++)
          Positioned(
            left: p * 50 * (0.4 + i * 0.13),
            top: 14 - 6 * math.sin(i * 1.7) * p,
            child: Opacity(
              opacity: (fade * (1 - i * 0.1)).clamp(0.0, 1.0),
              child: Container(
                width: 10 + 14 * p * (1 - i * 0.08),
                height: 10 + 14 * p * (1 - i * 0.08),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                      colors: [cols[0], cols[1], cols[2].withValues(alpha: 0)]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton(
      {super.key, required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: const Color(0xCC12151E),
          shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.16))),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: SizedBox(
                width: 44, height: 44, child: Icon(icon, color: Colors.white, size: 21)),
          ),
        ),
      );
}

class _RegionSign extends StatelessWidget {
  const _RegionSign({required this.region, required this.locked, required this.onTap});
  final WorldRegion region;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
          decoration: BoxDecoration(
            color: locked ? const Color(0xE612151E) : const Color(0x9912151E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: locked ? const Color(0x99E8B84A) : Colors.white.withValues(alpha: 0.2)),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(locked ? Icons.lock_rounded : Icons.explore_rounded,
                size: 16, color: locked ? const Color(0xFFE8B84A) : Colors.white),
            const SizedBox(width: 6),
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(region.name,
                      style: AppText.body(12, color: Colors.white, weight: FontWeight.w900)),
                  if (locked)
                    Text('Level ${region.unlockLevel}',
                        style: AppText.body(10,
                            color: const Color(0xFFE8B84A), weight: FontWeight.w800)),
                ]),
          ]),
        ),
      );
}

/// Opens a chest and shows the reward.
Future<void> openChestDialog(BuildContext context, WidgetRef ref, String type) async {
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
          border: Border.all(color: AppColors.outline, width: AppColors.palette.stroke + 1),
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
                      slug: rigSlugForItemId(item.id)!, height: 96, anim: RigAnim.celebrate),
            ),
            Text('New hero: ${item.name}!', style: AppText.body(16)),
          ],
          const SizedBox(height: 14),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Great!')),
        ]),
      ),
    ),
  );
}

class _Actor extends StatelessWidget {
  const _Actor({
    super.key,
    required this.slug,
    required this.anim,
    required this.onTap,
    required this.time,
    this.glow,
  });

  final String slug;
  final RigAnim anim;
  final VoidCallback onTap;
  final Color? glow;
  final ValueNotifier<double> time;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: _actorW,
        height: _actorH,
        child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
          if (glow != null)
            Positioned(
              bottom: -2,
              child: ValueListenableBuilder<double>(
                valueListenable: time,
                builder: (_, t, __) {
                  final k = (math.sin(t * 2.4) + 1) / 2;
                  return Container(
                    width: 58 + 6 * k,
                    height: 16 + 2 * k,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: glow!.withValues(alpha: .35 + .3 * k),
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

/// A resident hero that strolls back and forth around its spot.
class _Wanderer extends StatelessWidget {
  const _Wanderer({
    required this.slug,
    required this.time,
    required this.phase,
    required this.amp,
    required this.walks,
    required this.onTap,
  });

  final String slug;
  final ValueNotifier<double> time;
  final double phase;
  final double amp;
  final bool walks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rig = SizedBox(
      width: _actorW,
      height: _actorH,
      child: CharacterRig(
          slug: slug, height: _actorH, anim: walks ? RigAnim.walk : RigAnim.idle),
    );
    return ValueListenableBuilder<double>(
      valueListenable: time,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: rig),
      builder: (_, t, child) {
        final p = t * 0.5 + phase;
        final dx = walks ? amp * math.sin(p) : 0.0;
        final left = walks && math.cos(p) < 0;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.flip(flipX: left, child: child),
        );
      },
    );
  }
}

/// The next hero to buy: a dark silhouette on a glowing pedestal with a
/// price tag that says how far away the goal is.
class _Teaser extends StatelessWidget {
  const _Teaser(
      {required this.item, required this.state, required this.time, required this.onTap});

  final ShopItem item;
  final GameState state;
  final ValueNotifier<double> time;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 74,
        height: 96,
        child: ValueListenableBuilder<double>(
          valueListenable: time,
          builder: (_, t, __) {
            final k = (math.sin(t * 2.6) + 1) / 2;
            return Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
              Positioned(
                bottom: 6,
                child: Container(
                  width: 58,
                  height: 18,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [Color(0xFFE9E1D0), Color(0xFF8E826C)]),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1A1622), width: 1.6),
                    boxShadow: [
                      BoxShadow(
                          color: color.withValues(alpha: affordable ? .5 + .4 * k : .3),
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
                                : const Color(0xFF1A1030).withValues(alpha: .86),
                            affordable ? BlendMode.dst : BlendMode.srcATop),
                        child: CharacterRig(
                            slug: slug,
                            height: 56,
                            anim: affordable ? RigAnim.jump : RigAnim.idle),
                      ),
              ),
              if (!affordable)
                Positioned(
                  top: 4 - 3 * k,
                  child: Text('?', style: AppText.heading(22, color: AppColors.gold)),
                ),
              Positioned(
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: affordable ? const Color(0xFF3FAE73) : const Color(0xE612151E),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(text,
                      style: AppText.body(9.5, color: Colors.white, weight: FontWeight.w800)),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Chest extends StatelessWidget {
  const _Chest({
    required this.type,
    required this.count,
    required this.time,
    required this.phase,
    required this.onTap,
  });

  final String type;
  final int count;
  final ValueNotifier<double> time;
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
    const ink = Color(0xFF1A1622);
    final chest = SizedBox(
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
              gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8A5A2E), Color(0xFF4F3118)]),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: ink, width: 2),
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
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(_color, Colors.white, 0.35)!, _color]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border.all(color: ink, width: 2),
            ),
          ),
        ),
        Positioned(
          left: 18,
          top: 17,
          width: 8,
          height: 10,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: ink, width: 1.4),
            ),
          ),
        ),
        if (count > 1)
          Positioned(right: -6, top: -4, child: _Badge('x$count', AppColors.danger)),
      ]),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ValueListenableBuilder<double>(
        valueListenable: time,
        child: chest,
        builder: (_, t, child) {
          final b = math.sin(t * 7.8 + phase * 6);
          return Transform.translate(offset: Offset(0, -4 * (b + 1) / 2), child: child);
        },
      ),
    );
  }
}
