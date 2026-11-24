import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../characters/rig_data.dart';
import '../characters/rig_poses.dart';

/// Animated character built from stacked SVG parts (see tools/split_character.py).
///
/// All parts share one canvas, so they are simply stacked; each role is
/// rotated/translated about its pivot according to [anim].
class CharacterRig extends StatefulWidget {
  const CharacterRig({
    super.key,
    required this.slug,
    this.height = 120,
    this.anim = RigAnim.idle,
    this.animate = true,
    this.fallback,
  });

  final String slug;
  final double height;
  final RigAnim anim;

  /// When false (or [enableAnimation] is off) the character stands still.
  final bool animate;

  /// Shown while loading or if the art is missing.
  final Widget? fallback;

  /// Global switch; tests turn it off so pumpAndSettle can finish.
  static bool enableAnimation = true;

  @override
  State<CharacterRig> createState() => _CharacterRigState();
}

class _CharacterRigState extends State<CharacterRig>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late Future<RigData?> _rig = RigData.load(widget.slug);

  bool get _running => widget.animate && CharacterRig.enableAnimation;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    _c.duration = loopDuration(widget.anim);
    if (_running) {
      _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didUpdateWidget(CharacterRig old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) _rig = RigData.load(widget.slug);
    if (old.anim != widget.anim || old.animate != widget.animate) _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RigData?>(
      future: _rig,
      builder: (context, snap) {
        final rig = snap.data;
        if (rig == null) {
          return widget.fallback ?? SizedBox(height: widget.height);
        }
        final k = widget.height / rig.height;
        final w = rig.width * k;
        return RepaintBoundary(
          child: SizedBox(
            width: w,
            height: widget.height,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Stack(children: [
                for (final p in rig.parts) _part(rig, p, k, w),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _part(RigData rig, RigPart p, double k, double w) {
    final pose = resolvePose(widget.anim, _c.value, p.role);
    final pivot = rig.pivots[p.role] ?? Offset(rig.width / 2, rig.height / 2);
    final svg = SvgPicture.asset(
      rig.assetPath(p),
      width: w,
      height: widget.height,
    );
    final m = Matrix4.identity()
      ..translate(pose.dx * k, pose.dy * k)
      ..rotateZ(pose.rot)
      ..scale(pose.sx, pose.sy);
    return Positioned.fill(
      child: Transform(
        origin: Offset(pivot.dx * k, pivot.dy * k),
        transform: m,
        child: svg,
      ),
    );
  }
}
