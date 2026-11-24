import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Painted frame-based heroes (kingdom revamp).
///
/// Every hero folder holds `portrait.png` plus one or more frame sets made by
/// `tools/character_pipeline/slice_sheet.py`: a folder with `<frame>.png`
/// files on one shared canvas and `frames.json` giving the canvas size and
/// the anchor point (feet for ground poses, body centre for flying poses).
class SpriteHeroDef {
  const SpriteHeroDef({
    required this.itemId,
    required this.folder,
    required this.combat,
    required this.idle,
    required this.attack,
    this.flight,
  });

  final String itemId;
  final String folder;

  /// Sub-folder with the ground/combat frames.
  final String combat;

  /// Frame used while resting (gets a breathing motion).
  final String idle;

  /// Tap / auto attack combo: frame name + how long it is held.
  final List<SpriteStep> attack;

  /// Optional flight frames (wings up / down) for heroes that roam the sky.
  final String? flight;

  String get portrait => '$folder/portrait.png';
}

class SpriteStep {
  const SpriteStep(this.frame, this.ms, {this.punch = 0, this.lunge = 0});

  final String frame;
  final int ms;

  /// Extra scale at the start of the step (impact feel), e.g. 0.08.
  final double punch;

  /// Horizontal hop in fractions of the hero height (facing direction).
  final double lunge;
}

const spriteHeroes = <String, SpriteHeroDef>{
  'char_juggernaut': SpriteHeroDef(
    itemId: 'char_juggernaut',
    folder: 'assets/heroes/juggernaut',
    combat: 'combat',
    idle: 'idle',
    attack: [
      SpriteStep('windup', 520),
      SpriteStep('attack', 700, punch: 0.10),
      SpriteStep('victory', 900, punch: 0.04),
    ],
  ),
  'char_dragon_hayyab': SpriteHeroDef(
    itemId: 'char_dragon_hayyab',
    folder: 'assets/heroes/dragon_hayyab',
    combat: 'combat',
    idle: 'walk',
    attack: [
      SpriteStep('windup', 600),
      SpriteStep('breath', 1100, punch: 0.06, lunge: 0.03),
      SpriteStep('victory', 900, punch: 0.04),
    ],
    flight: 'flight',
  ),
};

SpriteHeroDef? spriteHeroFor(String itemId) => spriteHeroes[itemId];

/// Canvas size + anchor of one frame set, read from `frames.json`.
class SpriteFrames {
  SpriteFrames(this.folder, this.names, this.size, this.anchor);

  final String folder;
  final List<String> names;
  final Size size;

  /// Anchor as a fraction of [size] (0..1).
  final Offset anchor;

  double get aspect => size.width / size.height;
  String path(String frame) => '$folder/$frame.png';

  static final _cache = <String, Future<SpriteFrames>>{};

  static Future<SpriteFrames> load(String folder) =>
      _cache.putIfAbsent(folder, () async {
        final j = jsonDecode(await rootBundle.loadString('$folder/frames.json'))
            as Map<String, dynamic>;
        final size = (j['size'] as List).cast<num>();
        final anchor = (j['anchor'] as List).cast<num>();
        return SpriteFrames(
          folder,
          (j['frames'] as List).cast<String>(),
          Size(size[0].toDouble(), size[1].toDouble()),
          Offset(anchor[0].toDouble(), anchor[1].toDouble()),
        );
      });

  /// Decode every frame up front so switching frames never flickers.
  Future<void> precache(BuildContext context) => Future.wait([
        for (final n in names) precacheImage(AssetImage(path(n)), context),
      ]);
}

/// Lets the village (or a button) trigger the attack combo.
class SpriteHeroController extends ChangeNotifier {
  int _requests = 0;
  int get requests => _requests;
  void attack() {
    _requests++;
    notifyListeners();
  }
}

/// A painted hero standing on the ground: breathes on its idle frame,
/// plays its attack combo on tap / controller / every [autoEvery].
///
/// The widget is [height] tall; its feet (anchor) are at the bottom-centre
/// anchor fraction, so use [SpriteHero.anchorOf] to place it in a scene.
class SpriteHero extends StatefulWidget {
  const SpriteHero({
    super.key,
    required this.def,
    required this.height,
    this.controller,
    this.autoEvery,
    this.flip = false,
    this.tapToAttack = true,
    this.onFrames,
  });

  final SpriteHeroDef def;
  final double height;
  final SpriteHeroController? controller;
  final Duration? autoEvery;
  final bool flip;
  final bool tapToAttack;

  /// Called once the frame metadata is known (for scene placement).
  final ValueChanged<SpriteFrames>? onFrames;

  @override
  State<SpriteHero> createState() => _SpriteHeroState();
}

class _SpriteHeroState extends State<SpriteHero>
    with SingleTickerProviderStateMixin {
  SpriteFrames? _frames;
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();
  String? _frame;
  SpriteStep? _step;
  DateTime _stepStart = DateTime.now();
  bool _busy = false;
  Timer? _auto;
  int _seenRequests = 0;
  final _rand = math.Random();

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onRequest);
    _seenRequests = widget.controller?.requests ?? 0;
    _load();
    _scheduleAuto();
  }

  Future<void> _load() async {
    final f = await SpriteFrames.load('${widget.def.folder}/${widget.def.combat}');
    if (!mounted) return;
    await f.precache(context);
    if (!mounted) return;
    setState(() => _frames = f);
    widget.onFrames?.call(f);
  }

  void _scheduleAuto() {
    _auto?.cancel();
    final every = widget.autoEvery;
    if (every == null) return;
    final jitter = Duration(milliseconds: _rand.nextInt(every.inMilliseconds ~/ 2 + 1));
    _auto = Timer(every + jitter, () {
      attack();
      _scheduleAuto();
    });
  }

  void _onRequest() {
    final r = widget.controller!.requests;
    if (r != _seenRequests) {
      _seenRequests = r;
      attack();
    }
  }

  Future<void> attack() async {
    if (_busy || _frames == null) return;
    _busy = true;
    for (final s in widget.def.attack) {
      if (!mounted) return;
      setState(() {
        _step = s;
        _frame = s.frame;
        _stepStart = DateTime.now();
      });
      await Future<void>.delayed(Duration(milliseconds: s.ms));
    }
    if (!mounted) return;
    setState(() {
      _step = null;
      _frame = null;
    });
    _busy = false;
  }

  @override
  void didUpdateWidget(covariant SpriteHero old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onRequest);
      widget.controller?.addListener(_onRequest);
    }
    if (old.autoEvery != widget.autoEvery) _scheduleAuto();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onRequest);
    _auto?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frames;
    if (f == null) return SizedBox(height: widget.height, width: widget.height * 0.8);
    final w = widget.height * f.aspect;
    final anchor = Alignment(f.anchor.dx * 2 - 1, f.anchor.dy * 2 - 1);
    final frame = _frame ?? widget.def.idle;
    final child = AnimatedBuilder(
      animation: _breath,
      builder: (context, img) {
        var sx = 1.0, sy = 1.0, dx = 0.0;
        if (_step == null) {
          // idle: slow breathing, slight squash at the feet
          final t = math.sin(_breath.value * 2 * math.pi);
          sy = 1 + 0.018 * t;
          sx = 1 - 0.008 * t;
        } else {
          // impact: punch scale that settles over ~250 ms
          final ms = DateTime.now().difference(_stepStart).inMilliseconds;
          final k = math.exp(-ms / 120.0);
          sx = sy = 1 + _step!.punch * k;
          dx = _step!.lunge * widget.height * (1 - k);
        }
        return Transform.translate(
          offset: Offset(widget.flip ? -dx : dx, 0),
          child: Transform(
            alignment: anchor,
            transform: Matrix4.diagonal3Values(widget.flip ? -sx : sx, sy, 1),
            child: img,
          ),
        );
      },
      child: Image.asset(f.path(frame),
          width: w,
          height: widget.height,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium),
    );
    return SizedBox(
      width: w,
      height: widget.height,
      child: widget.tapToAttack
          ? GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: attack,
              child: child)
          : child,
    );
  }
}

/// Portrait tile image for shop lists, profile and chest reveals.
class SpriteHeroPortrait extends StatelessWidget {
  const SpriteHeroPortrait({super.key, required this.def, required this.size});

  final SpriteHeroDef def;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(def.portrait,
      width: size, height: size, fit: BoxFit.contain, filterQuality: FilterQuality.medium);
}
