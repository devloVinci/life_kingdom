import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/characters/rig_poses.dart';
import '../../../core/world/world_layout.dart';

/// What an actor is doing right now.
enum ActorMode { idle, look, walk, act, react, fly }

/// Moves the hero and the dragon around the world. No pathfinding: the hero
/// follows the roads, the dragon walks or flies straight to favourite spots.
class WorldSim extends ChangeNotifier {
  WorldSim({required Set<String> unlockedRegions, int seed = 1})
      : _unlocked = unlockedRegions,
        _rnd = math.Random(seed) {
    hero = HeroSim(this);
    dragon = DragonSim(this);
  }

  final math.Random _rnd;
  Set<String> _unlocked;
  late final HeroSim hero;
  late final DragonSim dragon;

  /// Seconds since the world started.
  double time = 0;

  Set<String> get unlocked => _unlocked;
  set unlocked(Set<String> v) => _unlocked = v;

  void tick(double dt) {
    time += dt;
    hero.update(dt);
    dragon.update(dt);
    notifyListeners();
  }
}

class HeroSim {
  HeroSim(this.sim);

  final WorldSim sim;
  Offset pos = WorldLayout.plaza + const Offset(-34, 46);
  ActorMode mode = ActorMode.idle;
  bool facingLeft = false;
  double _timer = 1.5;
  List<Offset> _path = const [];
  int _i = 0;

  /// Building the hero is standing at (null = plaza).
  String? at;
  String? _target;

  String? bubble;
  double _bubbleT = 0;

  static const speed = 46.0;

  RigAnim get anim => switch (mode) {
        ActorMode.walk => RigAnim.walk,
        ActorMode.act => RigAnim.work,
        ActorMode.react => RigAnim.roar,
        ActorMode.look => RigAnim.look,
        _ => RigAnim.idle,
      };

  double get bubbleOpacity => bubble == null ? 0 : _bubbleT.clamp(0.0, 0.3) / 0.3;

  void say(String text, {double seconds = 2.8}) {
    bubble = text;
    _bubbleT = seconds;
  }

  /// Tap reaction: brace, raise the sword, say something.
  void react(String line) {
    mode = ActorMode.react;
    _timer = loopDuration(RigAnim.roar).inMilliseconds / 1000;
    say(line);
  }

  void update(double dt) {
    if (_bubbleT > 0) {
      _bubbleT -= dt;
      if (_bubbleT <= 0) bubble = null;
    }
    switch (mode) {
      case ActorMode.walk:
        _walk(dt);
      default:
        _timer -= dt;
        if (_timer <= 0) _next();
    }
  }

  void _walk(double dt) {
    var step = speed * dt;
    while (step > 0 && _i < _path.length) {
      final to = _path[_i];
      final d = to - pos;
      if (d.distance <= step) {
        pos = to;
        step -= d.distance;
        _i++;
      } else {
        final dir = d / d.distance;
        pos += dir * step;
        if (dir.dx.abs() > 0.15) facingLeft = dir.dx < 0;
        step = 0;
      }
    }
    if (_i >= _path.length) {
      at = _target;
      if (at != null) {
        // Busy at the building for a moment.
        mode = ActorMode.act;
        _timer = 2.6;
      } else {
        mode = ActorMode.look;
        _timer = 3.2;
      }
    }
  }

  void _next() {
    final r = sim._rnd.nextDouble();
    if (mode != ActorMode.idle && mode != ActorMode.look) {
      mode = ActorMode.idle;
      _timer = 1.2 + sim._rnd.nextDouble() * 1.6;
      return;
    }
    if (r < 0.25 && mode == ActorMode.idle) {
      mode = ActorMode.look;
      _timer = 3.2;
      return;
    }
    final ids = WorldLayout.buildings.keys.toList();
    String? target;
    if (at == null || sim._rnd.nextDouble() < 0.7) {
      do {
        target = ids[sim._rnd.nextInt(ids.length)];
      } while (target == at);
    }
    _goTo(target);
  }

  void _goTo(String? target) {
    final pts = <Offset>[];
    if (at != null) pts.addAll(WorldLayout.roadTo(at!).reversed);
    // Cross the plaza around the fountain.
    final side = sim._rnd.nextBool() ? 1.0 : -1.0;
    pts.add(WorldLayout.plaza + Offset(48 * side, 34));
    if (target != null) {
      pts.addAll(WorldLayout.roadTo(target));
    } else {
      pts.add(WorldLayout.plaza + Offset(-34 * side, 46));
    }
    _path = pts;
    _i = 0;
    _target = target;
    mode = ActorMode.walk;
  }
}

class DragonSim {
  DragonSim(this.sim);

  final WorldSim sim;
  Offset pos = const Offset(640, 940);

  /// 0 on the ground, 1 at cruising height.
  double alt = 0;
  ActorMode mode = ActorMode.idle;
  bool facingLeft = true;
  double _timer = 2;
  Offset _target = Offset.zero;
  double _reactT = 0;

  static const walkSpeed = 30.0;
  static const flySpeed = 120.0;
  static const cruise = 70.0;

  RigAnim get anim => switch (mode) {
        ActorMode.fly => RigAnim.fly,
        ActorMode.walk => RigAnim.walk,
        ActorMode.react => RigAnim.roar,
        ActorMode.look => RigAnim.look,
        _ => alt > 0.05 ? RigAnim.fly : RigAnim.idle,
      };

  /// 0..1 while the fire puff plays.
  double get fire => mode == ActorMode.react ? (1 - _reactT / 1.1).clamp(0.0, 1.0) : 0;

  void react() {
    if (mode == ActorMode.fly) return; // can't roar mid-flight
    mode = ActorMode.react;
    _reactT = 1.1;
  }

  void update(double dt) {
    switch (mode) {
      case ActorMode.react:
        _reactT -= dt;
        if (_reactT <= 0) {
          mode = ActorMode.idle;
          _timer = 1.5;
        }
      case ActorMode.walk:
        _move(dt, walkSpeed);
      case ActorMode.fly:
        final d = (_target - pos).distance;
        // Climb at the start, glide down near the end.
        final want = d > 90 ? 1.0 : (d / 90);
        alt += ((want - alt).clamp(-dt * 1.4, dt * 1.2));
        _move(dt, flySpeed * (0.35 + 0.65 * alt));
      default:
        if (alt > 0) alt = math.max(0, alt - dt * 1.5);
        _timer -= dt;
        if (_timer <= 0) _next();
    }
  }

  void _move(double dt, double speed) {
    final d = _target - pos;
    final step = speed * dt;
    if (d.distance <= step) {
      pos = _target;
      mode = sim._rnd.nextDouble() < 0.5 ? ActorMode.look : ActorMode.idle;
      _timer = 2.5 + sim._rnd.nextDouble() * 3;
      return;
    }
    final dir = d / d.distance;
    pos += dir * step;
    if (dir.dx.abs() > 0.1) facingLeft = dir.dx < 0;
  }

  void _next() {
    if (mode == ActorMode.idle && sim._rnd.nextDouble() < 0.3) {
      mode = ActorMode.look;
      _timer = 3.2;
      return;
    }
    final spots = WorldLayout.dragonSpots
        .where((s) => s.$1.isEmpty || sim.unlocked.contains(s.$1))
        .map((s) => s.$2)
        .where((p) => (p - pos).distance > 40)
        .toList();
    if (spots.isEmpty) return;
    _target = spots[sim._rnd.nextInt(spots.length)];
    mode = (_target - pos).distance > 200 ? ActorMode.fly : ActorMode.walk;
  }
}

/// Short lines the hero says when tapped, based on today's progress.
String heroLine(math.Random rnd, {required int due, required int done, required int streak}) {
  if (due == 0) return 'Give me a quest! Add a habit.';
  if (done >= due) {
    return const [
      'All done today. The realm is proud!',
      'Victory! Rest well tonight.',
      'Not a single quest left. Legendary.',
    ][rnd.nextInt(3)];
  }
  final left = due - done;
  final lines = [
    '$left ${left == 1 ? 'quest' : 'quests'} left today. Onward!',
    if (streak > 1) '$streak days strong. Keep the fire burning!',
    if (done > 0) 'Good start. $left to go!',
    'For the kingdom!',
  ];
  return lines[rnd.nextInt(lines.length)];
}
