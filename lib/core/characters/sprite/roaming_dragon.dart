import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'sprite_hero.dart';

enum _Phase { flying, landing, grounded, takingOff }

/// A flying hero that wanders over the village: flaps its wings, casts a
/// moving shadow on the ground, and now and then (or when tapped) lands,
/// breathes fire and takes off again.
///
/// Put it in a Stack with `Positioned.fill`; it uses the whole area.
class RoamingDragon extends StatefulWidget {
  const RoamingDragon({
    super.key,
    required this.def,
    this.flightHeight = 110,
    this.groundHeight = 120,
    this.landEvery = const Duration(seconds: 20),
  });

  final SpriteHeroDef def;

  /// Height of the flying sprite (wingspan included) in logical px.
  final double flightHeight;

  /// Height of the landed / fire-breathing sprite.
  final double groundHeight;

  /// Average time between automatic landings.
  final Duration landEvery;

  @override
  State<RoamingDragon> createState() => _RoamingDragonState();
}

class _RoamingDragonState extends State<RoamingDragon>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _rand = math.Random();
  SpriteFrames? _flight, _ground;

  Size _area = Size.zero;
  Offset _pos = Offset.zero; // ground point under the dragon
  Offset _vel = Offset.zero;
  Offset _target = Offset.zero;
  double _alt = 0; // current altitude in px
  double _t = 0; // seconds since start
  double _phaseT = 0; // seconds in current phase
  double _nextLand = 0;
  bool _faceLeft = false;
  _Phase _phase = _Phase.flying;
  String _groundFrame = 'walk';
  double _punch = 0;
  Duration _last = Duration.zero;

  double get _cruiseAlt => _area.height * 0.34;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await SpriteFrames.load('${widget.def.folder}/${widget.def.flight}');
    final g = await SpriteFrames.load('${widget.def.folder}/${widget.def.combat}');
    if (!mounted) return;
    await Future.wait([f.precache(context), g.precache(context)]);
    if (!mounted) return;
    setState(() {
      _flight = f;
      _ground = g;
    });
    _ticker.start();
  }

  void _pickTarget() {
    final w = _area.width, h = _area.height;
    _target = Offset(w * (0.12 + 0.76 * _rand.nextDouble()),
        h * (0.55 + 0.37 * _rand.nextDouble()));
  }

  void _scheduleLanding() {
    final s = widget.landEvery.inMilliseconds / 1000;
    _nextLand = _t + s * (0.7 + 0.6 * _rand.nextDouble());
  }

  void _setPhase(_Phase p) {
    _phase = p;
    _phaseT = 0;
  }

  void _tick(Duration elapsed) {
    if (_area == Size.zero) return;
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _t += dt;
    _phaseT += dt;

    switch (_phase) {
      case _Phase.flying:
        _steer(dt, 58);
        _alt += (_cruiseAlt + math.sin(_t * math.pi * 4) * 5 - _alt) * math.min(1.0, dt * 3);
        if (_t >= _nextLand) _setPhase(_Phase.landing);
      case _Phase.landing:
        _steer(dt, 30);
        _alt = math.max(0.0, _alt - dt * _cruiseAlt / 0.8);
        if (_alt <= 0) {
          _vel = Offset.zero;
          _setPhase(_Phase.grounded);
          _groundFrame = 'walk';
        }
      case _Phase.grounded:
        _runGroundCombo();
      case _Phase.takingOff:
        _steer(dt, 40);
        _alt = math.min(_cruiseAlt, _alt + dt * _cruiseAlt / 0.9);
        if (_alt >= _cruiseAlt - 1) {
          _setPhase(_Phase.flying);
          _scheduleLanding();
        }
    }
    _punch = math.max(0.0, _punch - dt * 0.4);
    setState(() {});
  }

  void _runGroundCombo() {
    // walk-in, then the attack steps, then take off
    var start = 0.45;
    if (_phaseT < start) {
      _groundFrame = 'walk';
      return;
    }
    for (final s in widget.def.attack) {
      final end = start + s.ms / 1000;
      if (_phaseT < end) {
        if (_groundFrame != s.frame) _punch = s.punch;
        _groundFrame = s.frame;
        return;
      }
      start = end;
    }
    _pickTarget();
    _setPhase(_Phase.takingOff);
  }

  void _steer(double dt, double speed) {
    final d = _target - _pos;
    if (d.distance < 24) {
      _pickTarget();
      return;
    }
    final desired = d / d.distance * speed;
    _vel = Offset.lerp(_vel, desired, math.min(1.0, dt * 1.4))!;
    _pos += _vel * dt;
    if (_vel.dx.abs() > 8) _faceLeft = _vel.dx < 0;
  }

  void _onTap() {
    if (_phase == _Phase.flying) _setPhase(_Phase.landing);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      if (_area == Size.zero && size.width > 0) {
        _area = size;
        _pos = Offset(size.width * 0.3, size.height * 0.75);
        _alt = _cruiseAlt;
        _pickTarget();
        _scheduleLanding();
      }
      _area = size;
      final flight = _flight, ground = _ground;
      if (flight == null || ground == null) return const SizedBox.shrink();

      final inAir = _phase != _Phase.grounded;
      // shadow shrinks and fades with altitude; landed frames have their own
      final h01 = (_alt / math.max(1.0, _cruiseAlt)).clamp(0.0, 1.0);
      final shadowW = widget.flightHeight * (1.1 - 0.45 * h01);
      final shadowOpacity = inAir ? 0.32 - 0.12 * h01 : 0.0;

      late final Widget sprite;
      late final double left, top;
      if (inAir) {
        final fh = widget.flightHeight, fw = fh * flight.aspect;
        final frame = ((_t * 4).floor() % 2 == 0) ? 'up' : 'down';
        left = _pos.dx - fw * flight.anchor.dx;
        top = _pos.dy - _alt - fh * flight.anchor.dy;
        sprite = _img(flight.path(frame), fw, fh, flight.anchor, 1);
      } else {
        final gh = widget.groundHeight, gw = gh * ground.aspect;
        left = _pos.dx - gw * ground.anchor.dx;
        top = _pos.dy - gh * ground.anchor.dy;
        sprite = _img(ground.path(_groundFrame), gw, gh, ground.anchor, 1 + _punch);
      }

      return Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: _pos.dx - shadowW / 2,
          top: _pos.dy - shadowW * 0.14,
          child: Container(
            width: shadowW,
            height: shadowW * 0.28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.elliptical(shadowW / 2, shadowW * 0.14)),
              color: Colors.black.withValues(alpha: shadowOpacity),
            ),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: GestureDetector(onTap: _onTap, child: sprite),
        ),
      ]);
    });
  }

  Widget _img(String path, double w, double h, Offset anchor, double scale) {
    return Transform(
      alignment: Alignment(anchor.dx * 2 - 1, anchor.dy * 2 - 1),
      transform: Matrix4.diagonal3Values(_faceLeft ? -scale : scale, scale, 1),
      child: Image.asset(path,
          width: w,
          height: h,
          fit: BoxFit.fill,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium),
    );
  }
}
