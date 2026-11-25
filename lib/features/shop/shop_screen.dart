import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/game/catalog.dart';
import '../../core/characters/rig_poses.dart';
import '../../core/widgets/character_rig.dart';
import '../../core/widgets/cosmetic_swatches.dart';
import '../../core/game/economy_engine.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/game_background.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../../core/widgets/rarity_frame.dart';
import '../../core/widgets/resource_counter.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    return DefaultTabController(
      length: 4,
      child: GameBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              Text('Shop', style: AppText.heading(28)),
              const Spacer(),
              ResourceCounter(type: ResourceType.gold, amount: s.gold),
              const SizedBox(width: 8),
              ResourceCounter(type: ResourceType.gem, amount: s.gems),
            ]),
          ),
          TabBar(
            labelColor: AppColors.onBackground,
            unselectedLabelColor: AppColors.onBackground.withValues(alpha: 0.6),
            indicatorColor: AppColors.accent,
            dividerColor: Colors.transparent,
            labelStyle: AppText.body(14, color: AppColors.onBackground),
            tabs: const [
              Tab(text: 'Heroes'),
              Tab(text: 'World'),
              Tab(text: 'Style'),
              Tab(text: 'Rewards'),
            ],
          ),
          const Expanded(
            child: TabBarView(children: [
              _ItemList(types: [ItemType.character]),
              _ItemList(types: [ItemType.season, ItemType.dragonSkin, ItemType.uiTheme]),
              _ItemList(types: [ItemType.title, ItemType.background]),
              _RewardsTab(),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.types});

  final List<ItemType> types;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final items = Catalog.items
        .where((i) => types.contains(i.type))
        // Hide unowned items that are not for sale (earned titles).
        .where((i) => i.forSale || s.owned.contains(i.id))
        .toList();
    final children = <Widget>[];
    for (final t in types) {
      final group = items.where((i) => i.type == t).toList();
      if (group.isEmpty) continue;
      if (types.length > 1) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
          child: Text(_sectionTitle(t).toUpperCase(),
              style: AppText.label(12, color: AppColors.onBackground.withValues(alpha: 0.7))),
        ));
      }
      for (final item in group) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _ItemCard(item: item),
        ));
      }
    }
    return ListView(padding: const EdgeInsets.all(16), children: children);
  }

  static String _sectionTitle(ItemType t) => switch (t) {
        ItemType.character => 'Heroes',
        ItemType.title => 'Titles',
        ItemType.background => 'Backgrounds',
        ItemType.uiTheme => 'Interface themes',
        ItemType.season => 'World seasons',
        ItemType.dragonSkin => 'Dragon skins',
      };
}

class _ItemCard extends ConsumerWidget {
  const _ItemCard({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final owned = s.owned.contains(item.id);
    final equipped = s.equipped[item.slot] == item.id;

    Widget action;
    if (equipped) {
      action = const GameButton(label: 'Equipped', compact: true, onPressed: null);
    } else if (owned) {
      action = GameButton(
        label: 'Equip',
        compact: true,
        style: GameButtonStyle.blue,
        onPressed: () => ref.read(gameProvider.notifier).equip(item.id),
      );
    } else {
      action = GameButton(
        label: 'Buy',
        compact: true,
        style: GameButtonStyle.gold,
        onPressed: () => showPurchaseDialog(context, ref, item),
      );
    }

    return GestureDetector(
      key: Key('item_${item.id}'),
      onTap: () => item.type == ItemType.character
          ? context.push('/character/${item.id}')
          : showItemPreview(context, ref, item),
      child: RarityFrame(
      rarity: rarityOf(item.rarity),
      selected: equipped,
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Row(children: [
          _Preview(item: item),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: AppText.headingPlain(18)),
                  Text(item.description, style: AppText.body(12)),
                  if (!owned) _PriceLine(item: item),
                ]),
          ),
          const SizedBox(width: 8),
          action,
        ]),
      ),
    ));
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case ItemType.character:
        return CharacterAvatar(item: item);
      case ItemType.title:
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: rarityOf(item.rarity).color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline, width: 3),
          ),
          child: const Icon(Icons.military_tech, color: Colors.white),
        );
      case ItemType.season:
        return SizedBox(width: 64, height: 64, child: SeasonSwatch(id: item.id));
      case ItemType.uiTheme:
        return SizedBox(width: 64, height: 64, child: ThemeSwatch(id: item.id));
      case ItemType.dragonSkin:
        return SizedBox(
          width: 64,
          height: 64,
          child: FittedBox(
            child: CharacterRig(
                slug: item.id, height: 64, anim: RigAnim.idle, hiddenRoles: const {'shadow'}),
          ),
        );
      case ItemType.background:
        final g = item.gradient!;
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(g[0]), Color(g[1])],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.outline, width: 3),
          ),
        );
    }
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.goldPrice != null) '${item.goldPrice} gold',
      if (item.gemPrice != null) '${item.gemPrice} gems',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(parts.join('  or  '),
          style: AppText.body(13, color: AppColors.panelPrimary)),
    );
  }
}

/// Bottom sheet preview for titles and backgrounds (heroes have their own
/// detail screen).
Future<void> showItemPreview(
    BuildContext context, WidgetRef ref, ShopItem item) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.panel,
    isScrollControlled: true,
    builder: (ctx) => Consumer(builder: (ctx, ref, _) {
      final s = ref.watch(gameProvider);
      final owned = s.owned.contains(item.id);
      final equipped = s.equipped[item.slot] == item.id;
      final big = switch (item.type) {
        ItemType.season => SizedBox(height: 150, child: SeasonSwatch(id: item.id, large: true)),
        ItemType.uiTheme => SizedBox(height: 150, child: ThemeSwatch(id: item.id, large: true)),
        ItemType.dragonSkin => SizedBox(
            height: 150,
            child: Center(
              child: CharacterRig(slug: item.id, height: 140, anim: RigAnim.look),
            ),
          ),
        _ => _bigPreview(item),
      };
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            big,
            const SizedBox(height: 12),
            Text(item.name, style: AppText.headingPlain(22)),
            Text(item.description,
                textAlign: TextAlign.center, style: AppText.body(14)),
            if (!owned) _PriceLine(item: item),
            const SizedBox(height: 12),
            if (equipped)
              const GameButton(label: 'Equipped', onPressed: null)
            else if (owned)
              GameButton(
                label: 'Equip',
                style: GameButtonStyle.blue,
                onPressed: () {
                  ref.read(gameProvider.notifier).equip(item.id);
                  Navigator.pop(ctx);
                },
              )
            else if (item.forSale)
              GameButton(
                key: const Key('preview_buy'),
                label: 'Buy',
                style: GameButtonStyle.gold,
                onPressed: () {
                  Navigator.pop(ctx);
                  showPurchaseDialog(context, ref, item);
                },
              )
            else
              Text('Earn this by playing.', style: AppText.body(13)),
          ]),
        ),
      );
    }),
  );
}

Widget _bigPreview(ShopItem item) => item.type == ItemType.background
          ? Container(
              height: 140,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(item.gradient![0]), Color(item.gradient![1])],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline, width: 3),
              ),
            )
          : Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rarityOf(item.rarity).color,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline, width: 3),
              ),
              child: Text(item.name, style: AppText.heading(26)),
            );

Future<void> showPurchaseDialog(
    BuildContext context, WidgetRef ref, ShopItem item) async {
  final useGems = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: GamePanel(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Buy ${item.name}?', style: AppText.headingPlain(22)),
          const SizedBox(height: 8),
          Text(item.description,
              textAlign: TextAlign.center, style: AppText.body(14)),
          const SizedBox(height: 16),
          if (item.goldPrice != null)
            GameButton(
              label: '${item.goldPrice} gold',
              style: GameButtonStyle.gold,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          if (item.goldPrice != null && item.gemPrice != null)
            const SizedBox(height: 10),
          if (item.gemPrice != null)
            GameButton(
              label: '${item.gemPrice} gems',
              style: GameButtonStyle.blue,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
        ]),
      ),
    ),
  );
  if (useGems == null || !context.mounted) return;
  final o =
      ref.read(gameProvider.notifier).buy(item.id, useGems: useGems);
  final msg = switch (o.status) {
    PurchaseStatus.ok => '${item.name} is yours!',
    PurchaseStatus.insufficientGold => 'You need ${o.missing} more gold',
    PurchaseStatus.insufficientGems => 'You need ${o.missing} more gems',
    PurchaseStatus.alreadyOwned => 'You already own this',
    PurchaseStatus.notForSale => 'Not available with this currency',
    PurchaseStatus.notFound => 'Item not found',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

class _RewardsTab extends ConsumerWidget {
  const _RewardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Your own rewards', style: AppText.heading(20)),
        const SizedBox(height: 4),
        Text('Create real-life treats and pay for them with gold.',
            style: AppText.body(13, color: AppColors.onBackground)),
        const SizedBox(height: 12),
        if (s.customRewards.isEmpty)
          GamePanel(
            child: Text('No rewards yet. Add your first one!',
                style: AppText.body(14)),
          ),
        for (final r in s.customRewards)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GamePanel(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.title, style: AppText.headingPlain(18)),
                        Text('${r.priceGold} gold  -  redeemed ${r.timesRedeemed}x',
                            style: AppText.body(12)),
                      ]),
                ),
                GameButton(
                  label: 'Redeem',
                  compact: true,
                  style: GameButtonStyle.gold,
                  onPressed: () {
                    final st = ref
                        .read(gameProvider.notifier)
                        .redeemCustomReward(r.id);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                          content: Text(st == RewardStatus.ok
                              ? 'Enjoy: ${r.title}!'
                              : 'Not enough gold yet')));
                  },
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete, color: AppColors.danger),
                  onPressed: () => ref
                      .read(gameProvider.notifier)
                      .deleteCustomReward(r.id),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 8),
        Center(
          child: GameButton(
            label: 'Add reward',
            icon: Icons.add,
            onPressed: () => _showAddDialog(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) {
    final title = TextEditingController();
    final price = TextEditingController();
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New reward'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('reward_title'),
            controller: title,
            decoration: const InputDecoration(labelText: 'Reward'),
          ),
          TextField(
            key: const Key('reward_price'),
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Price in gold'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final p = int.tryParse(price.text.trim());
              if (title.text.trim().isEmpty || p == null || p <= 0) return;
              ref
                  .read(gameProvider.notifier)
                  .addCustomReward(title.text.trim(), p);
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
