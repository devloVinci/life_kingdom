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
import '../../core/widgets/rarity_frame.dart';
import '../shop/shop_screen.dart' show showPurchaseDialog;

/// Hero detail: owned (equip, companion, animation preview) or locked (buy).
class CharacterDetailScreen extends ConsumerStatefulWidget {
  const CharacterDetailScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<CharacterDetailScreen> createState() =>
      _CharacterDetailScreenState();
}

class _CharacterDetailScreenState extends ConsumerState<CharacterDetailScreen> {
  RigAnim _anim = RigAnim.idle;

  static const _labels = {
    RigAnim.idle: 'Idle',
    RigAnim.walk: 'Walk',
    RigAnim.work: 'Work',
    RigAnim.celebrate: 'Cheer',
    RigAnim.jump: 'Jump',
    RigAnim.sleep: 'Sleep',
  };

  void _toast(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final item = Catalog.byId[widget.characterId];
    final s = ref.watch(gameProvider);
    final controller = ref.read(gameProvider.notifier);
    if (item == null || item.type != ItemType.character) {
      return Scaffold(
        body: GameBackground(
          child: Center(child: Text('Hero not found', style: AppText.heading(22))),
        ),
      );
    }
    final owned = s.owned.contains(item.id);
    final equipped = s.equipped['character'] == item.id;
    final companion = s.companions.contains(item.id);
    final rarity = rarityOf(item.rarity);

    return Scaffold(
      body: GameBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(children: [
              IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back, color: AppColors.onBackground),
                onPressed: () => context.pop(),
              ),
              Expanded(child: Text(item.name, style: AppText.heading(26))),
            ]),
            const SizedBox(height: 8),
            RarityFrame(
              rarity: rarity,
              child: Padding(
                padding: const EdgeInsets.only(top: 22, bottom: 8),
                child: Column(children: [
                  Opacity(
                    opacity: owned ? 1 : 0.4,
                    child: CharacterAvatar(
                        item: item, size: 180, anim: _anim, animate: owned),
                  ),
                  if (!owned)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.lock, size: 18, color: AppColors.outline),
                        const SizedBox(width: 6),
                        Text('Locked', style: AppText.headingPlain(16)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description, style: AppText.body(14)),
                    const SizedBox(height: 8),
                    Text(
                        rarity.name[0].toUpperCase() + rarity.name.substring(1),
                        style: AppText.body(13, color: rarity.color, weight: FontWeight.w900)),
                  ]),
            ),
            if (owned) ...[
              const SizedBox(height: 12),
              GamePanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Animations', style: AppText.headingPlain(18)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final a in _labels.keys)
                          ChoiceChip(
                            key: Key('anim_${a.name}'),
                            label: Text(_labels[a]!),
                            selected: _anim == a,
                            onSelected: (_) => setState(() => _anim = a),
                          ),
                      ]),
                    ]),
              ),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    GameButton(
                      key: const Key('equip_button'),
                      label: equipped ? 'Equipped' : 'Equip',
                      style: GameButtonStyle.blue,
                      onPressed: equipped ? null : () => controller.equip(item.id),
                    ),
                    GameButton(
                      key: const Key('companion_button'),
                      label: companion ? 'Remove companion' : 'Make companion',
                      icon: Icons.pets,
                      style: GameButtonStyle.gold,
                      onPressed: () {
                        if (companion) {
                          controller.removeCompanion(item.id);
                          _toast('${item.name} left your companions');
                        } else {
                          final st = controller.addCompanion(item.id);
                          _toast(switch (st) {
                            CompanionStatus.ok => '${item.name} is now a companion',
                            CompanionStatus.full =>
                              'No free slot. Upgrade the Army Camp for more.',
                            CompanionStatus.already => 'Already a companion',
                            _ => 'You do not own this hero',
                          });
                        }
                      },
                    ),
                  ]),
            ] else ...[
              const SizedBox(height: 12),
              GamePanel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.forSale ? 'Unlock this hero' : 'How to get',
                          style: AppText.headingPlain(18)),
                      const SizedBox(height: 4),
                      Text(
                          item.forSale
                              ? [
                                  if (item.goldPrice != null) '${item.goldPrice} gold',
                                  if (item.gemPrice != null) '${item.gemPrice} gems',
                                ].join('  or  ')
                              : 'Found in chests from quests and streaks.',
                          style: AppText.body(14, color: AppColors.panelPrimary)),
                    ]),
              ),
              if (item.forSale) ...[
                const SizedBox(height: 16),
                Center(
                  child: GameButton(
                    key: const Key('buy_button'),
                    label: 'Buy',
                    style: GameButtonStyle.gold,
                    onPressed: () => showPurchaseDialog(context, ref, item),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
