import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'skinned_pose.dart';
import 'skinned_rig.dart';

/// Drives which clip a [SkinnedCharacter] plays.
///
/// The character always returns to [loopClip] (idle by default) after a
/// one-shot clip such as `victory`, `levelUp`, `hit` or `skill` finishes.
class CharacterAnimController extends ChangeNotifier {
  CharacterAnimController({String loopClip = 'idle'}) : _loopClip = loopClip;

  String _loopClip;
  String? _request;
  int _serial = 0;

  String get loopClip => _loopClip;

  /// Plays [clip] once, then returns to the loop clip.
  void play(String clip) {
    _request = clip;
    _serial++;
    notifyListeners();
  }

  /// Changes the looping clip (e.g. `walk` while travelling, `idle` at rest).
  void setLoop(String clip) {
    _loopClip = clip;
    _request = clip;
    _serial++;
    notifyListeners();
  }
}

/// Renders an animated, mesh-skinned painted character from a rig folder
/// produced by the character pipeline. Independent of the rest of the UI:
/// drop it anywhere and give it a size.
class SkinnedCharacter extends StatefulWidget {
  const SkinnedCharacter({
    super.key,
    this.folder = 'assets/heroes/hero_knight',
    this.controller,
    this.clip,
    this.animate = true,
    this.showShadow = true,
    this.fallback,
  });

  /// Asset folder containing rig.json and the layer textures.
  final String folder;

  /// Optional controller for triggering one-shot clips.
  final CharacterAnimController? controller;

  /// Clip to loop when there is no controller (default `idle`).
  final String? clip;

  /// When false (or when the platform asks to reduce motion) a still frame
  /// is drawn: cheap enough for long lists.
  final bool animate;
  final bool showShadow;
  final Widget? fallback;

  @override
  State<SkinnedCharacter> createState() => _SkinnedCharacterState();
}

class _SkinnedCharacterState extends State<SkinnedCharacter>
    with SingleTickerProviderStateMixin {
  late Future<LoadedRig> _future;
  late final Ticker _ticker;
  final _clock = CharacterClock();
  int _seenSerial = -1;

  @override
  void initState() {
    super.initState();
    _future = SkinnedRigLoader.load(widget.folder);
    _ticker = createTicker((elapsed) {
      _clock.now = elapsed.inMicroseconds / 1e6;
      _clock.tick();
    });
    widget.controller?.addListener(_onController);
    _clock.loopClip = widget.controller?.loopClip ?? widget.clip ?? 'idle';
    _clock.clip = _clock.loopClip;
  }

  void _onController() {
    final c = widget.controller!;
    if (c._serial == _seenSerial) return;
    _seenSerial = c._serial;
    _clock.loopClip = c.loopClip;
    _clock.clip = c._request ?? c.loopClip;
    _clock.start = _clock.now;
    _clock.tick();
  }

  void _syncTicker(BuildContext context) {
    final still = !widget.animate ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (still && _ticker.isActive) _ticker.stop();
    if (!still && !_ticker.isActive) _ticker.start();
  }

  @override
  void didUpdateWidget(SkinnedCharacter old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onController);
      widget.controller?.addListener(_onController);
    }
    if (old.folder != widget.folder) {
      _future = SkinnedRigLoader.load(widget.folder);
    }
    if (widget.controller == null && widget.clip != old.clip) {
      _clock.loopClip = widget.clip ?? 'idle';
      _clock.clip = _clock.loopClip;
      _clock.start = _clock.now;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncTicker(context);
    return FutureBuilder<LoadedRig>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) return widget.fallback ?? const SizedBox.shrink();
        final loaded = snap.data;
        if (loaded == null) return widget.fallback ?? const SizedBox.shrink();
        return AspectRatio(
          aspectRatio: CharacterPainter.boundsFor(loaded.rig).width /
              CharacterPainter.boundsFor(loaded.rig).height,
          child: CustomPaint(
            painter: CharacterPainter(
              loaded,
              _clock,
              showShadow: widget.showShadow,
            ),
          ),
        );
      },
    );
  }
}

/// Time source shared with the painter; ticks repaint without rebuilds.
class CharacterClock extends ChangeNotifier {
  double now = 0;
  double start = 0;
  String clip = 'idle';
  String loopClip = 'idle';

  void tick() => notifyListeners();
}

/// Paints one frame. Public so tests and tools can render poses directly.
class CharacterPainter extends CustomPainter {
  CharacterPainter(this.loaded, this._clock, {this.showShadow = true})
      : super(repaint: _clock);

  final LoadedRig loaded;
  final CharacterClock _clock;
  final bool showShadow;

  static const padX = 70.0, padTop = 90.0, padBottom = 30.0;

  static Rect boundsFor(SkinnedRig rig) =>
      Rect.fromLTRB(-padX, -padTop, rig.width + padX, rig.height + padBottom);

  static final Map<ui.Image, ui.Shader> _shaders = {};
  static final _identity =
      Float64List.fromList([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);

  ui.Shader _shader(ui.Image img) => _shaders.putIfAbsent(
      img,
      () => ui.ImageShader(img, ui.TileMode.clamp, ui.TileMode.clamp, _identity,
          filterQuality: FilterQuality.medium));

  @override
  void paint(Canvas canvas, Size size) {
    final rig = loaded.rig;
    var clip = rig.clips[_clock.clip] ?? rig.clips.values.first;
    var elapsed = _clock.now - _clock.start;
    if (clip.isFinished(elapsed) && clip.name != _clock.loopClip) {
      // One-shot done: fall back to the loop clip (painter-side, no rebuild).
      _clock.clip = _clock.loopClip;
      _clock.start = _clock.now;
      clip = rig.clips[_clock.loopClip] ?? clip;
      elapsed = 0;
    }
    final pose = RigPose.sample(rig, clip, elapsed, totalTime: _clock.now);
    paintPose(canvas, size, pose, _clock.now);
  }

  void paintPose(Canvas canvas, Size size, RigPose pose, double time) {
    final rig = loaded.rig;
    final b = boundsFor(rig);
    final scale = math.min(size.width / b.width, size.height / b.height);
    canvas.save();
    canvas.translate((size.width - b.width * scale) / 2,
        (size.height - b.height * scale) / 2);
    canvas.scale(scale);
    canvas.translate(-b.left, -b.top);

    final shake = pose.effect('shake') * 7 * math.sin(time * 95);
    canvas.translate(shake, 0);

    // ground shadow (shrinks while airborne)
    final root = pose.bones.first;
    final lift = root.mapY(rig.ground.dx, rig.ground.dy) - rig.ground.dy;
    if (showShadow) {
      final s = math.max(0.45, 1 + lift / 160);
      canvas.drawOval(
        Rect.fromCenter(
            center: rig.ground, width: 340 * s, height: 52 * s),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    final meshes = [
      for (var i = 0; i < rig.layers.length; i++) _skinnedVertices(i, pose)
    ];

    // glows behind the character
    const glowColors = {
      'aura': Color(0xFFFFC83C),
      'glow': Color(0xFFFFD75A),
      'charge': Color(0xFF5AB4FF),
    };
    for (final e in glowColors.entries) {
      final v = pose.effect(e.key);
      if (v <= 0.01) continue;
      canvas.saveLayer(
        b.inflate(60),
        Paint()
          ..imageFilter = ui.ImageFilter.compose(
            outer: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            inner: ColorFilter.mode(
                e.value.withValues(alpha: math.min(1.0, v)), BlendMode.srcIn),
          ),
      );
      _drawLayers(canvas, meshes, null);
      canvas.restore();
    }

    final aura = pose.effect('aura');
    if (aura > 0.01) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = const Color(0xFFFFD250).withValues(alpha: math.min(1.0, aura));
      for (var k = 0; k < 3; k++) {
        final r = (90 + 70 * k) * aura;
        canvas.drawOval(
            Rect.fromCenter(center: rig.ground, width: r * 3.2, height: r * 0.7),
            ring);
      }
    }

    // the character itself (+ hurt / flash tint)
    final hurt = pose.effect('hurt');
    final flash = pose.effect('flash');
    ColorFilter? tint;
    if (hurt > 0.01) {
      tint = ColorFilter.mode(
          const Color(0xFFFF2828).withValues(alpha: 0.45 * hurt),
          BlendMode.srcATop);
    } else if (flash > 0.01) {
      tint = ColorFilter.mode(
          const Color(0xFFFFFFFF).withValues(alpha: flash), BlendMode.srcATop);
    }
    _drawLayers(canvas, meshes, tint);

    // blinking eyelids follow the head bone
    if (pose.blink > 0.02) {
      final lid = Paint()..color = rig.lidColor;
      final lash = Paint()
        ..color = const Color(0xFF3C1E14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final eye in rig.eyes) {
        canvas.save();
        canvas.transform(pose.bones[eye.bone].toMatrix4());
        final r = Rect.fromLTRB(eye.cx - eye.rx, eye.cy - eye.ry,
            eye.cx + eye.rx, eye.cy - eye.ry + 2 * eye.ry * pose.blink);
        canvas.drawOval(r, lid);
        canvas.drawArc(r, 0.35, 2.44, false, lash);
        canvas.restore();
      }
    }

    _drawParticles(canvas, pose, time);
    canvas.restore();
  }

  ui.Vertices _skinnedVertices(int i, RigPose pose) {
    final layer = loaded.rig.layers[i];
    final out = Float32List(layer.positions.length);
    pose.skin(layer, out);
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      out,
      textureCoordinates: layer.uvs,
      indices: layer.triangles,
    );
  }

  void _drawLayers(Canvas canvas, List<ui.Vertices> meshes, ColorFilter? tint) {
    for (var i = 0; i < meshes.length; i++) {
      final paint = Paint()
        ..shader = _shader(loaded.textures[i])
        ..filterQuality = FilterQuality.medium;
      if (tint != null) paint.colorFilter = tint;
      canvas.drawVertices(meshes[i], BlendMode.srcOver, paint);
    }
  }

  void _drawParticles(Canvas canvas, RigPose pose, double time) {
    final rig = loaded.rig;
    final particles = pose.effect('particles');
    final sparkle = pose.effect('sparkle');
    if (particles <= 0.01 && sparkle <= 0.01) return;
    final rnd = math.Random(7);
    final dot = Paint()
      ..color = const Color(0xFFFFE178).withValues(alpha: math.min(1.0, particles));
    final star = Paint()
      ..color = const Color(0xFFFFF5BE)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 26; i++) {
      final x = -10 + rnd.nextDouble() * (rig.width + 20);
      final phase = rnd.nextDouble();
      final r = 3 + 4 * rnd.nextDouble();
      final sy = rnd.nextDouble() * rig.height;
      if (particles > 0.01) {
        final y = rig.ground.dy - ((time * 220 + phase * 900) % 900);
        canvas.drawCircle(Offset(x, y), r, dot);
      }
      if (sparkle > 0.01) {
        final tw =
            (math.sin(time * 9 + phase * 6.28) + 1) / 2 * math.min(1.0, sparkle);
        final len = 4 + 12 * tw;
        final y = sy - 60;
        canvas.drawLine(Offset(x - len, y), Offset(x + len, y), star);
        canvas.drawLine(Offset(x, y - len), Offset(x, y + len), star);
      }
    }
  }

  @override
  bool shouldRepaint(CharacterPainter old) =>
      old.loaded != loaded || old.showShadow != showShadow;
}
