import 'package:flutter/material.dart';

import '../game/catalog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

Rarity rarityOf(ItemRarity r) => Rarity.values.byName(r.name);

/// Placeholder avatar (rarity-colored tile with the initial). It will be
/// replaced by the exported SVG character art / animated rig.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({super.key, required this.item, this.size = 64});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = rarityOf(item.rarity).color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.outline, width: 3),
      ),
      child: Text(item.name.substring(0, 1), style: AppText.heading(size * 0.5)),
    );
  }
}
