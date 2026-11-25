import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'game_button.dart';

/// Shows the result of completing/undoing a habit: a reward burst for
/// rewards, and a celebration card for level-ups, rank-ups and streak
/// milestones.
Future<void> showOutcomeFeedback(BuildContext context, CompletionOutcome o) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (o.status) {
    case CompletionStatus.done:
      if (o.xpGained > 0) {
        HapticFeedback.mediumImpact();
        showRewardPop(context, xp: o.xpGained, gold: o.goldGained);
      }
    case CompletionStatus.alreadyCompleted:
      messenger.showSnackBar(const SnackBar(content: Text('Already completed today')));
    case CompletionStatus.notDue:
      messenger.showSnackBar(const SnackBar(content: Text('This habit is not scheduled today')));
    case CompletionStatus.archived:
    case CompletionStatus.notFound:
    case CompletionStatus.notCompleted:
      break;
  }
  if (!context.mounted) return;
  await showEvents(context, o.events);
}

/// Floating "+XP / +gold" chips with a burst of sparks.
void showRewardPop(BuildContext context, {required int xp, required int gold}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _RewardPop(xp: xp, gold: gold, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _RewardPop extends StatefulWidget {
  const _RewardPop({required this.xp, required this.gold, required this.onDone});
  final int xp;
  final int gold;
  final VoidCallback onDone;

  @override
  State<_RewardPop> createState() => _RewardPopState();
}

class _RewardPopState extends State<_RewardPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final pop = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
          final fade = t < 0.75 ? 1.0 : 1 - (t - 0.75) / 0.25;
          return Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _SparkPainter(t))),
            Align(
              alignment: const Alignment(0, -0.2),
              child: Transform.translate(
                offset: Offset(0, -70 * Curves.easeOut.transform(t)),
                child: Opacity(
                  opacity: fade.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * pop,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _Chip(icon: Icons.star_rounded, color: const Color(0xFF5AA9F0), text: '+${widget.xp} XP'),
                      if (widget.gold > 0) ...[
                        const SizedBox(width: 10),
                        _Chip(icon: Icons.circle, color: AppColors.gold, text: '+${widget.gold}'),
                      ],
                    ]),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
        decoration: BoxDecoration(
          color: const Color(0xEE12151E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 18)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 6),
          Text(text,
              style: AppText.body(17, color: Colors.white, weight: FontWeight.w900)
                  .copyWith(decoration: TextDecoration.none)),
        ]),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.4);
    final k = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    const colors = [Color(0xFFFFD34D), Color(0xFF6FD3FF), Color(0xFFFFFFFF), Color(0xFFFFA94D)];
    for (var i = 0; i < 18; i++) {
      final a = i / 18 * math.pi * 2 + (i.isEven ? 0.1 : -0.1);
      final dist = (70 + (i % 4) * 26) * k;
      final p = c + Offset(math.cos(a) * dist, math.sin(a) * dist * 0.85 + 40 * t * t);
      final paint = Paint()..color = colors[i % 4].withValues(alpha: fade);
      if (i % 3 == 0) {
        // Little four-point star.
        final r = 5.0 * (1 - t * 0.5);
        final star = Path()
          ..moveTo(p.dx, p.dy - r)
          ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
          ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
          ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
        canvas.drawPath(star, paint);
      } else {
        canvas.drawCircle(p, 2.6 * (1 - t * 0.6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.t != t;
}

/// Celebration card for level-ups, rank-ups and streak milestones.
Future<void> showEvents(BuildContext context, List<GameEvent> events) async {
  if (events.isEmpty) return;
  final lines = <String>[];
  var title = 'Well done!';
  int? level;
  String? rank;
  for (final e in events) {
    switch (e) {
      case LevelUp(level: final l):
        title = 'LEVEL UP!';
        level = l;
        lines.add('You reached level $l');
      case RankUp(rank: final r):
        title = 'NEW RANK!';
        rank = r;
        lines.add('Rank $r unlocked');
      case StreakMilestone(:final days):
        lines.add('$days-day streak reward');
    }
  }
  HapticFeedback.heavyImpact();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Celebration',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 420),
    transitionBuilder: (_, a, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (ctx, _, __) => Center(
      child: Material(
        type: MaterialType.transparency,
        child: _CelebrationCard(
          title: title,
          big: rank ?? (level != null ? '$level' : null),
          lines: lines,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    ),
  );
}

class _CelebrationCard extends StatelessWidget {
  const _CelebrationCard({required this.title, required this.big, required this.lines, required this.onClose});
  final String title;
  final String? big;
  final List<String> lines;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    const gold = Color(0xFFE8B84A);
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: p.chunky ? [p.surface, p.surface] : [p.surfaceRaised, p.surface],
        ),
        borderRadius: BorderRadius.circular(p.radius + 8),
        border: Border.all(color: p.chunky ? p.border : gold.withValues(alpha: 0.6), width: p.chunky ? 3 : 1.4),
        boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: 2)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (big != null)
          Container(
            width: 92,
            height: 92,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.4),
                colors: [Color(0xFFFFF0B0), Color(0xFFE8B84A), Color(0xFF9A6A1C)],
                stops: [0, 0.55, 1],
              ),
              boxShadow: [BoxShadow(color: Color(0x99E8B84A), blurRadius: 28, spreadRadius: 4)],
            ),
            padding: const EdgeInsets.all(14),
            child: FittedBox(
              child: Text(big!,
                  style: AppText.body(40, color: const Color(0xFF2A1C04), weight: FontWeight.w900)),
            ),
          ),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: AppText.headingPlain(28, color: p.chunky ? AppColors.panelPrimary : gold)
                .copyWith(letterSpacing: 1.5)),
        const SizedBox(height: 8),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l, textAlign: TextAlign.center, style: AppText.body(15)),
          ),
        const SizedBox(height: 16),
        GameButton(label: 'Continue', onPressed: onClose),
      ]),
    );
  }
}
