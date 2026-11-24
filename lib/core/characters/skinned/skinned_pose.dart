import 'dart:math' as math;
import 'dart:typed_data';

import 'skinned_rig.dart';

/// 2D affine transform: x' = a*x + b*y + e,  y' = c*x + d*y + f.
class Affine {
  const Affine(this.a, this.b, this.c, this.d, this.e, this.f);

  static const identity = Affine(1, 0, 0, 1, 0, 0);

  final double a, b, c, d, e, f;

  Affine operator *(Affine l) => Affine(
        a * l.a + b * l.c,
        a * l.b + b * l.d,
        c * l.a + d * l.c,
        c * l.b + d * l.d,
        a * l.e + b * l.f + e,
        c * l.e + d * l.f + f,
      );

  double mapX(double x, double y) => a * x + b * y + e;
  double mapY(double x, double y) => c * x + d * y + f;

  /// Column-major 4x4 for Canvas.transform.
  Float64List toMatrix4() => Float64List.fromList(
      [a, c, 0, 0, b, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1]);
}

/// The sampled state of a rig at one moment.
class RigPose {
  RigPose(this.bones, this.fx, this.blink);

  /// Skin matrix per bone (rest pose -> animated pose).
  final List<Affine> bones;

  /// Effect intensities (0..1) for this moment.
  final Map<String, double> fx;

  /// Eyelid closure 0 (open) .. 1 (closed).
  final double blink;

  double effect(String name) => fx[name] ?? 0;

  /// Same math as rigkit.py:
  /// M_bone = M_parent * T(head + t) * R(rot) * S(sx, sy) * T(-head)
  static RigPose sample(SkinnedRig rig, RigClip clip, double elapsed,
      {double totalTime = 0}) {
    final t = clip.localTime(elapsed);
    final mats = <Affine>[];
    for (final bone in rig.bones) {
      final tr = clip.tracks[bone.name];
      final rot = (tr?['rot']?.sample(t) ?? 0) * math.pi / 180;
      final tx = tr?['tx']?.sample(t) ?? 0;
      final ty = tr?['ty']?.sample(t) ?? 0;
      final sx = tr?['sx']?.sample(t) ?? 1;
      final sy = tr?['sy']?.sample(t) ?? 1;
      final cs = math.cos(rot), sn = math.sin(rot);
      final a = cs * sx, b = -sn * sy, c = sn * sx, d = cs * sy;
      final local = Affine(
        a,
        b,
        c,
        d,
        bone.hx + tx - (a * bone.hx + b * bone.hy),
        bone.hy + ty - (c * bone.hx + d * bone.hy),
      );
      mats.add(bone.parent < 0 ? local : mats[bone.parent] * local);
    }
    return RigPose(
      mats,
      {for (final e in clip.fx.entries) e.key: e.value.sample(t)},
      clip.blink ? blinkAmount(totalTime) : 0,
    );
  }

  /// A quick blink every [period] seconds.
  static double blinkAmount(double t,
      {double period = 3.4, double duration = 0.16}) {
    final p = (t % period) / duration;
    if (p >= 1) return 0;
    return math.max(0.0, 1 - (p * 2 - 1).abs());
  }

  /// Linear-blend skinning of one layer into [out] (length = positions).
  void skin(RigLayer layer, Float32List out) {
    final n = layer.vertexCount;
    final k = layer.influences;
    final p = layer.positions;
    for (var v = 0; v < n; v++) {
      final x = p[2 * v], y = p[2 * v + 1];
      var ox = 0.0, oy = 0.0;
      for (var i = 0; i < k; i++) {
        final w = layer.boneWeights[v * k + i];
        if (w == 0) continue;
        final m = bones[layer.boneIds[v * k + i]];
        ox += w * m.mapX(x, y);
        oy += w * m.mapY(x, y);
      }
      out[2 * v] = ox;
      out[2 * v + 1] = oy;
    }
  }
}
