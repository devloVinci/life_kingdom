import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/characters/rig_poses.dart';
import '../../core/game/catalog.dart';
import '../../core/game/companion_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';

/// Choose which owned heroes accompany you (slots come from the Army Camp).
class CompanionsScreen extends ConsumerWidget {
  const CompanionsScreen({super.key});

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final s = ref.read(gameProvider);
    final options = Catalog.items
        .where((i) =>
            i.type == ItemType.character &&
            s.owned.contains(i.id) &&
            !s.companions.contains(i.id))
        .toList();
    final id = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.panel,
      builder: (ctx) => SafeArea(
        child: options.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text('All your heroes are already companions.',
                    style: AppText.body(15)),
              )
            : ListView(shrinkWrap: true, children: [
                for (final o in options)
                  ListTile(
                    key: Key('pick_${o.id}'),
                    leading: CharacterAvatar(item: o, size: 44),
                    title: Text(o.name, style: AppText.body(16, weight: FontWeight.w900)),
                    onTap: () => Navigator.pop(ctx, o.id),
                  ),
              ]),
      ),
    );
    if (id == null || !context.mounted) return;
    final st = ref.read(gameProvider.notifier).addCompanion(id);
    if (st == CompanionStatus.full) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No free slot')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final slots = CompanionEngine.slots(s);
    final next = CompanionEngine.nextSlotLevel(s);

    return Scaffold(
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              Expanded(child: Text('Companions', style: AppText.heading(26))),
              Text('${s.companions.length} / $slots',
                  style: AppText.heading(20, color: AppColors.gold)),
            ]),
            const SizedBox(height: 8),
            for (var i = 0; i < slots; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: i < s.companions.length
                    ? _FilledSlot(id: s.companions[i])
                    : _EmptySlot(onTap: () => _pick(context, ref)),
              ),
            if (next != null)
              GamePanel(
                child: Row(children: [
                  const Icon(Icons.lock, color: AppColors.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Next slot opens at Army Camp level $next.',
                        style: AppText.body(13)),
                  ),
                  GameButton(
                    label: 'Army Camp',
                    compact: true,
                    style: GameButtonStyle.blue,
                    onPressed: () => context.push('/building/army_camp'),
                  ),
                ]),
              ),
            const SizedBox(height: 12),
            GamePanel(
              child: Text(
                  'Companions walk with you around your kingdom. A desktop version that lets them roam your computer screen is planned for the desktop app.',
                  style: AppText.body(12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilledSlot extends ConsumerWidget {
  const _FilledSlot({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = Catalog.byId[id];
    if (item == null) return const SizedBox.shrink();
    return GamePanel(
      child: Row(children: [
        CharacterAvatar(item: item, size: 72, anim: RigAnim.walk, animate: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name, style: AppText.headingPlain(20)),
            Text(item.rarity.name, style: AppText.body(12)),
          ]),
        ),
        GameButton(
          key: Key('remove_$id'),
          label: 'Remove',
          compact: true,
          style: GameButtonStyle.danger,
          onPressed: () =>
              ref.read(gameProvider.notifier).removeCompanion(id),
        ),
      ]),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('empty_slot'),
      onTap: onTap,
      child: GamePanel(
        child: SizedBox(
          height: 72,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_circle_outline, color: AppColors.panelPrimary),
            const SizedBox(width: 8),
            Text('Add a companion', style: AppText.headingPlain(16)),
          ]),
        ),
      ),
    );
  }
}
