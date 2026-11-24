import 'dart:math' as math;

/// Animations a rigged character can play.
enum RigAnim { idle, walk, work, celebrate, jump, sleep }

/// A transform applied to one body role. Angles in radians (positive =
/// clockwise on screen). Pivot comes from the rig's `pivots` map.
class PartPose {
  const PartPose({this.dx = 0, this.dy = 0, this.rot = 0, this.sx = 1, this.sy = 1});

  final double dx, dy, rot, sx, sy;

  static const zero = PartPose();

  PartPose operator +(PartPose o) => PartPose(
        dx: dx + o.dx,
        dy: dy + o.dy,
        rot: rot + o.rot,
        sx: sx * o.sx,
        sy: sy * o.sy,
      );
}

const rigRoles = ['body', 'head', 'armL', 'armR', 'legL', 'legR'];

/// Duration of one loop of [a].
Duration loopDuration(RigAnim a) => switch (a) {
      RigAnim.idle => const Duration(milliseconds: 2400),
      RigAnim.walk => const Duration(milliseconds: 700),
      RigAnim.work => const Duration(milliseconds: 900),
      RigAnim.celebrate => const Duration(milliseconds: 800),
      RigAnim.jump => const Duration(milliseconds: 900),
      RigAnim.sleep => const Duration(milliseconds: 3600),
    };

/// Raw pose per role for loop position [t] in [0, 1). Includes the key
/// `root` (whole body, shadow excluded) and `shadow`.
Map<String, PartPose> rawPose(RigAnim a, double t) {
  final s = math.sin(2 * math.pi * t);
  final c = math.cos(2 * math.pi * t);
  switch (a) {
    case RigAnim.idle:
      return {
        'body': PartPose(sy: 1 + 0.02 * s),
        'head': PartPose(dy: -1.2 * s),
        'armL': PartPose(rot: 0.05 + 0.05 * s),
        'armR': PartPose(rot: -0.05 - 0.05 * s),
      };
    case RigAnim.walk:
      return {
        'root': PartPose(dy: -2.5 * s.abs()),
        'head': PartPose(rot: 0.03 * s),
        'legL': PartPose(rot: 0.5 * s),
        'legR': PartPose(rot: -0.5 * s),
        'armL': PartPose(rot: 0.6 * s),
        'armR': PartPose(rot: 0.6 * s - 0.1),
      };
    case RigAnim.work:
      // Mallet rests up/back, then sweeps over and down in a quick strike.
      final hit = math.pow((1 - c) / 2, 3).toDouble(); // 0 -> 1 at t = .5
      return {
        'armR': PartPose(rot: -0.6 + 2.8 * hit),
        'armL': PartPose(rot: 0.1 - 0.1 * hit),
        'head': PartPose(dy: 2 * hit, rot: 0.05 * hit),
        'body': PartPose(sy: 1 - 0.03 * hit),
      };
    case RigAnim.celebrate:
      return {
        'root': PartPose(dy: -6 * s.abs()),
        'armL': PartPose(rot: 2.6 + 0.2 * s),
        'armR': PartPose(rot: -0.3 + 0.35 * s), // waves the mallet
        'head': PartPose(rot: 0.05 * s),
        'legL': PartPose(rot: 0.12 * s),
        'legR': PartPose(rot: -0.12 * s),
      };
    case RigAnim.jump:
      final h = math.sin(math.pi * t); // 0 -> 1 -> 0
      return {
        'root': PartPose(dy: -16 * h),
        'armL': PartPose(rot: 1.2 * h),
        'armR': PartPose(rot: -0.5 * h),
        'legL': PartPose(rot: 0.4 * h),
        'legR': PartPose(rot: -0.4 * h),
        'shadow': PartPose(sx: 1 - 0.25 * h, sy: 1 - 0.25 * h),
      };
    case RigAnim.sleep:
      return {
        'body': PartPose(sy: 1 + 0.03 * s),
        'head': PartPose(rot: 0.22 + 0.02 * s, dy: 2),
        'armL': PartPose(rot: 0.04),
        'armR': PartPose(rot: -0.04),
      };
  }
}

/// Final pose of [role] at [t]: the role's own pose plus the whole-body
/// `root` motion.
PartPose resolvePose(RigAnim a, double t, String role) {
  final raw = rawPose(a, t);
  if (role == 'shadow') return raw['shadow'] ?? PartPose.zero;
  if (role == 'whole') return wholePose(a, t);
  return (raw[role] ?? PartPose.zero) + (raw['root'] ?? PartPose.zero);
}

/// Motion for characters exported as one flat layer (no separate limbs):
/// squash & stretch, bobbing and tilting the entire body.
PartPose wholePose(RigAnim a, double t) {
  final s = math.sin(2 * math.pi * t);
  final c = math.cos(2 * math.pi * t);
  switch (a) {
    case RigAnim.idle:
      return PartPose(sy: 1 + 0.025 * s, sx: 1 - 0.012 * s);
    case RigAnim.walk:
      return PartPose(dy: -3 * s.abs(), rot: 0.06 * s);
    case RigAnim.work:
      final hit = math.pow((1 - c) / 2, 3).toDouble();
      return PartPose(dy: 2 * hit, rot: -0.05 + 0.15 * hit, sy: 1 - 0.05 * hit);
    case RigAnim.celebrate:
      return PartPose(dy: -8 * s.abs(), rot: 0.1 * s, sy: 1 + 0.04 * c.abs());
    case RigAnim.jump:
      final h = math.sin(math.pi * t);
      return PartPose(dy: -16 * h, sy: 1 + 0.08 * h, sx: 1 - 0.04 * h);
    case RigAnim.sleep:
      return PartPose(rot: 0.1, sy: 1 + 0.03 * s);
  }
}
