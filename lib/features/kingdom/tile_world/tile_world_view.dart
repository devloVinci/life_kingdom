import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/world_growth.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/character_rig.dart';
import '../../../core/world/tile_map.dart';
import 'land_journal.dart';
import 'world_painter.dart';
import 'world_props.dart';

/// Loaded once per app run.
class _WorldAssets {
  _WorldAssets(this.atlas, this.image);

  final TileAtlas atlas;
  final ui.Image image;

  static Future<_WorldAssets>? _cache;

  static Future<_WorldAssets> load() => _cache ??= () async {
        const dir = 'assets/world';
        final tmx = await rootBundle.loadString('$dir/grassland.tmx');
        final tsx = await rootBundle.loadString('$dir/grassland_tiles.tsx');
        final map = TileMapData.parse(tmx, tsx);
        final bytes = await rootBundle.load('$dir/${map.imageSource}');
        final codec =
            await ui.instantiateImageCodec(bytes.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return _WorldAssets(TileAtlas(map), frame.image);
      }();
}

/// The pixel-art home world. It starts as a tiny clearing around the old
/// well and opens up as the player completes habits and tasks, levels up and
/// holds streaks. Pan with a finger, pinch to zoom, tap the well for the
/// land journal.
class TileWorldView extends ConsumerStatefulWidget {
  const TileWorldView({super.key});

  @override
  ConsumerState<TileWorldView> createState() => _TileWorldViewState();
}

class _TileWorldViewState extends ConsumerState<TileWorldView>
    with TickerProviderStateMixin {
  _WorldAssets? _assets;
  Object? _error;

  final _camera = TransformationController();
  Size? _framedFor;
  bool _userMoved = false;

  /// Animates the open radius when new land is reached.
  late final AnimationController _reveal = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200));
  double _fromRadius = 0;
  double _toRadius = 0;
  bool _revealing = false;

  /// Camera glide that follows a reveal.
  late final AnimationController _glide = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  Matrix4Tween? _glideTween;

  Ticker? _ticker;

  /// Seconds since the view opened; repaints the world without rebuilding.
  final _clock = ValueNotifier<double>(0);

  String? _banner;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _reveal.addListener(() => setState(() {}));
    _glide.addListener(() {
      final t = _glideTween;
      if (t != null) {
        _camera.value = t.transform(Curves.easeInOutCubic.transform(_glide.value));
      }
    });
    _WorldAssets.load().then((a) {
      if (mounted) setState(() => _assets = a);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
    if (CharacterRig.enableAnimation) {
      _ticker = createTicker((d) => _clock.value = d.inMicroseconds / 1e6)
        ..start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    _reveal.dispose();
    _glide.dispose();
    _camera.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  double get _radius => _revealing
      ? ui.lerpDouble(_fromRadius, _toRadius,
          Curves.easeOutCubic.transform(_reveal.value))!
      : _toRadius;

  /// Starts the reveal when progress is ahead of the land already seen.
  void _sync(WorldProgress p, Set<String> seen) {
    final target = WorldGrowth.radiusFor(p.count);
    final seenRadius = WorldGrowth.radiusFor(seen.length);
    if (_revealing) return;
    if (_assets == null) {
      // Wait for the map so the player actually sees the land open.
      _toRadius = seenRadius;
      return;
    }
    if (p.count > seen.length) {
      final newLand = p.reached.difference(seen);
      final last = WorldGrowth.milestones
          .lastWhere((m) => newLand.contains(m.id), orElse: () => WorldGrowth.milestones.first);
      _revealing = true;
      _fromRadius = seenRadius;
      _toRadius = target;
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        _showBanner(newLand.length == 1
            ? 'New land: ${last.land}'
            : '${newLand.length} new lands discovered');
        _glideTo(target);
        if (CharacterRig.enableAnimation) {
          await _reveal.forward(from: 0);
        } else {
          _reveal.value = 1;
        }
        if (!mounted) return;
        ref.read(gameProvider.notifier).markLandSeen(newLand);
        setState(() => _revealing = false);
      });
    } else {
      _toRadius = target;
    }
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _banner = text);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Matrix4 _frame(Size view, TileMapData map, double radius) {
    final minScale = _minScale(view, map);
    final want = view.shortestSide * .8 / (radius * 2 * map.tileWidth);
    final s = want.clamp(minScale, math.max(3.0, minScale)).toDouble();
    const home = GrassLandLayout.home;
    var tx = view.width / 2 - home.dx * s;
    var ty = view.height * .52 - home.dy * s;
    // Keep the map covering the screen.
    tx = tx.clamp(math.min(view.width - map.pixelWidth * s, 0.0), 0.0).toDouble();
    ty = ty.clamp(math.min(view.height - map.pixelHeight * s, 0.0), 0.0).toDouble();
    return Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, tx)
      ..setEntry(1, 3, ty);
  }

  double _minScale(Size view, TileMapData map) =>
      math.max(view.width / map.pixelWidth, view.height / map.pixelHeight);

  void _glideTo(double radius) {
    final a = _assets;
    final view = _framedFor;
    if (a == null || view == null || _userMoved) return;
    _glideTween =
        Matrix4Tween(begin: _camera.value.clone(), end: _frame(view, a.atlas.map, radius));
    if (CharacterRig.enableAnimation) {
      _glide.forward(from: 0);
    } else {
      _camera.value = _glideTween!.end!;
    }
  }

  void _onTap(TapUpDetails d) {
    final p = d.localPosition;
    final well = GrassLandLayout.props.firstWhere((x) => x.id == 'well');
    if (well.bounds.inflate(10).contains(p)) showLandJournal(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final progress = WorldGrowth.progress(s, now);
    final seen = WorldGrowth.seen(s);
    if (!_revealing && _toRadius == 0) {
      // First build: start from the land already seen.
      _toRadius = WorldGrowth.radiusFor(seen.length);
    }
    _sync(progress, seen);

    final a = _assets;
    return ColoredBox(
      color: worldFogColor,
      child: LayoutBuilder(builder: (context, box) {
        if (a == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                  _error == null
                      ? ''
                      : 'World map not imported yet.\nRun tools/tiles/import_pack.ps1',
                  textAlign: TextAlign.center,
                  style: AppText.body(14, color: const Color(0xFFB9A57A))),
            ),
          );
        }
        final view = box.biggest;
        final map = a.atlas.map;
        if (_framedFor != view) {
          _framedFor = view;
          _camera.value = _frame(view, map, _radius);
        }
        return Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              key: const Key('tile_world'),
              transformationController: _camera,
              constrained: false,
              minScale: _minScale(view, map),
              maxScale: math.max(4.0, _minScale(view, map) * 2),
              boundaryMargin: EdgeInsets.zero,
              onInteractionStart: (_) {
                _userMoved = true;
                _glide.stop();
              },
              child: GestureDetector(
                onTapUp: _onTap,
                child: SizedBox(
                  width: map.pixelWidth,
                  height: map.pixelHeight,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: WorldPainter(
                        atlas: a.atlas,
                        image: a.image,
                        radius: _radius,
                        clock: _clock,
                        home: GrassLandLayout.home,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_banner != null)
            Positioned(
              left: 24,
              right: 24,
              top: view.height * .3,
              child: IgnorePointer(child: _LandBanner(text: _banner!)),
            ),
        ]);
      }),
    );
  }
}

class _LandBanner extends StatelessWidget {
  const _LandBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: .8 + .2 * t, child: child),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xEE1B1406),
              border: Border.all(color: const Color(0xFFE8C46A), width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(text,
                key: const Key('land_banner'),
                textAlign: TextAlign.center,
                style: AppText.heading(18, color: const Color(0xFFFFE7A3))),
          ),
        ),
      );
}
