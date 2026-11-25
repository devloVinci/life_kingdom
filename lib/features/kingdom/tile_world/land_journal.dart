import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/game/world_growth.dart';
import '../../../core/theme/app_text.dart';

const _panel = Color(0xF01B1406);
const _gold = Color(0xFFE8C46A);
const _cream = Color(0xFFFFE7A3);
const _muted = Color(0xFFB9A57A);

BoxDecoration _frame() => BoxDecoration(
      color: _panel,
      border: Border.all(color: _gold, width: 2),
      borderRadius: BorderRadius.circular(4),
      boxShadow: const [
        BoxShadow(color: Color(0x88000000), offset: Offset(0, 3)),
      ],
    );

/// Small card above the bottom bar: what to do in real life to open the
/// next piece of land. Tap it for the full land journal.
class NextLandCard extends ConsumerWidget {
  const NextLandCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final p = WorldGrowth.progress(s, now);
    final next = p.next;
    final total = WorldGrowth.milestones.length;

    return GestureDetector(
      key: const Key('next_land_card'),
      onTap: () => showLandJournal(context),
      child: Semantics(
        button: true,
        label: 'Open land journal',
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: _frame(),
          child: Row(children: [
            const Icon(Icons.explore, color: _gold, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    next == null
                        ? 'The whole valley is yours'
                        : 'Next land: ${next.land}',
                    style: AppText.heading(15, color: _cream),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    next == null
                        ? 'More lands arrive with new map packs'
                        : '${next.goal}  (${_clamp(p.nextValue, next.target)}/${next.target})',
                    style: AppText.body(12, color: _muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  _PixelBar(
                    value: next == null
                        ? 1
                        : _clamp(p.nextValue, next.target) / next.target,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${p.count}/$total',
                style: AppText.heading(14, color: _gold)),
          ]),
        ),
      ),
    );
  }

  static int _clamp(int v, int target) => v > target ? target : v;
}

/// Chunky segmented bar (pixel-art style).
class _PixelBar extends StatelessWidget {
  const _PixelBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    const segments = 12;
    final filled = (value * segments).floor();
    return Row(children: [
      for (var i = 0; i < segments; i++)
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.only(right: 2),
            color: i < filled ? const Color(0xFF7BD34F) : const Color(0xFF3A2E17),
          ),
        ),
    ]);
  }
}

/// Every land in order: which are open and what the rest need.
Future<void> showLandJournal(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _LandJournal(),
    );

class _LandJournal extends ConsumerWidget {
  const _LandJournal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final now = ref.watch(clockProvider)();
    final p = WorldGrowth.progress(s, now);

    return SafeArea(
      child: Container(
        key: const Key('land_journal'),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .75),
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: _frame(),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Land Journal', style: AppText.heading(22, color: _cream)),
          const SizedBox(height: 4),
          Text('Your world grows with your real progress.',
              style: AppText.body(12, color: _muted)),
          const SizedBox(height: 10),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              _row('The Clearing', 'Where every journey starts', true, null),
              for (final m in WorldGrowth.milestones)
                _row(
                  m.land,
                  m.goal,
                  p.reached.contains(m.id),
                  p.reached.contains(m.id)
                      ? null
                      : '${NextLandCard._clamp(WorldGrowth.value(s, now, m.metric), m.target)}/${m.target}',
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String land, String goal, bool open, String? count) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(open ? Icons.check_box : Icons.lock_outline,
              color: open ? const Color(0xFF7BD34F) : _muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(land,
                  style: AppText.heading(15, color: open ? _cream : _muted)),
              Text(goal, style: AppText.body(12, color: _muted)),
            ]),
          ),
          if (count != null) Text(count, style: AppText.body(13, color: _gold)),
        ]),
      );
}
