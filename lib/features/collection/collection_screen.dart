import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';

/// Every hero in the game: owned ones in colour, locked ones dimmed.
class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key, this.showBack = true});

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final heroes =
        Catalog.items.where((i) => i.type == ItemType.character).toList();
    final ownedCount = heroes.where((h) => s.owned.contains(h.id)).length;
    final equipped = s.equipped['character'];

    return Scaffold(
      body: GameBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(children: [
              if (showBack)
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
                  onPressed: () => context.pop(),
                )
              else
                const SizedBox(width: 8),
              Expanded(child: Text('Heroes', style: AppText.heading(26))),
              Text('$ownedCount / ${heroes.length}',
                  style: AppText.heading(20, color: AppColors.gold)),
            ]),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: heroes.length,
              itemBuilder: (_, i) => _HeroTile(
                item: heroes[i],
                owned: s.owned.contains(heroes[i].id),
                equipped: equipped == heroes[i].id,
                companion: s.companions.contains(heroes[i].id),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _HeroTile extends StatelessWidget {
  const _HeroTile({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.companion,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool companion;

  @override
  Widget build(BuildContext context) {
    final color = rarityOf(item.rarity).color;
    return Semantics(
      button: true,
      label: '${item.name}, ${owned ? 'owned' : 'locked'}',
      child: GestureDetector(
        onTap: () => context.push('/character/${item.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: equipped ? AppColors.gold : AppColors.outline,
                width: equipped ? 4 : 3),
            boxShadow: [
              BoxShadow(color: AppColors.panelDark, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Expanded(
              child: Stack(alignment: Alignment.center, children: [
                Opacity(
                  opacity: owned ? 1 : 0.35,
                  child: LayoutBuilder(
                    builder: (_, c) => CharacterAvatar(
                        item: item, size: c.biggest.shortestSide),
                  ),
                ),
                if (!owned)
                  Icon(Icons.lock, color: AppColors.outline, size: 28),
                if (companion)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(Icons.pets, color: AppColors.panelPrimary, size: 18),
                  ),
              ]),
            ),
            const SizedBox(height: 6),
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(12, weight: FontWeight.w900)),
            Container(
              margin: const EdgeInsets.only(top: 2),
              height: 5,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(3)),
            ),
          ]),
        ),
      ),
    );
  }
}
