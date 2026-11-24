import 'package:flutter/material.dart';

import '../characters/rig_data.dart';
import '../characters/rig_poses.dart';
import '../characters/sprite/sprite_hero.dart';
import '../game/catalog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'character_rig.dart';

Rarity rarityOf(ItemRarity r) => Rarity.values.byName(r.name);

/// Rarity-colored tile showing the character's SVG art (animated when
/// [animate]); characters without art yet show their initial.
class CharacterAvatar extends StatelessWidget {
  const CharacterAvatar({
    super.key,
    required this.item,
    this.size = 64,
    this.anim = RigAnim.idle,
    this.animate = false,
  });

  final ShopItem item;
  final double size;
  final RigAnim anim;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final color = rarityOf(item.rarity).color;
    final slug = rigSlugForItemId(item.id);
    final initial = Text(item.name.substring(0, 1),
        style: AppText.heading(size * 0.5));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: AppColors.outline, width: 3),
      ),
      child: spriteHeroFor(item.id) != null
          ? SpriteHeroPortrait(def: spriteHeroFor(item.id)!, size: size)
          : slug == null
              ? initial
              : Padding(
              padding: EdgeInsets.all(size * 0.06),
              child: CharacterRig(
                slug: slug,
                height: size * 0.88,
                anim: anim,
                animate: animate,
                fallback: initial,
              ),
            ),
    );
  }
}
