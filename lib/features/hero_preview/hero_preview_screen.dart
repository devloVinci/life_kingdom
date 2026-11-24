import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/characters/rig_data.dart';
import '../../core/characters/rig_poses.dart';
import '../../core/characters/sprite/sprite_hero.dart';
import '../../core/game/catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/character_avatar.dart';
import '../../core/widgets/character_rig.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../kingdom/living_village.dart';
import '../shop/shop_screen.dart' show showPurchaseDialog;

/// Full-screen previewer for one hero: big stage, every animation / frame,
/// how it looks in the village and at small sizes, and buy / equip.
class HeroPreviewScreen extends ConsumerStatefulWidget {
  const HeroPreviewScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<HeroPreviewScreen> createState() => _HeroPreviewScreenState();
}

enum _Stage { arena, village }

class _HeroPreviewScreenState extends ConsumerState<HeroPreviewScreen> {
  final _ctrl = SpriteHeroController();
  _Stage _stage = _Stage.arena;
  List<String> _frames = const [];
  String? _hold;
  bool _auto = false;
  bool _flip = false;
  double _zoom = 1.0;
  RigAnim _rigAnim = RigAnim.idle;

  SpriteHeroDef? get _sprite => spriteHeroFor(widget.itemId);

  @override
  void initState() {
    super.initState();
    final def = _sprite;
    if (def != null) {
      SpriteFrames.load('${def.folder}/${def.combat}').then((f) {
        if (mounted) setState(() => _frames = f.names);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = Catalog.byId[widget.itemId];
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Unknown hero', style: AppText.heading(18))),
      );
    }
    final rarity = rarityOf(item.rarity);
    return Scaffold(
      backgroundColor: const Color(0xFF0E1228),
      appBar: AppBar(
        title: Text(item.name),
        backgroundColor: AppColors.panelDeep,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_sprite != null) ...[
            Center(
              child: SegmentedButton<_Stage>(
                segments: const [
                  ButtonSegment(value: _Stage.arena, label: Text('Arena'), icon: Icon(Icons.theater_comedy)),
                  ButtonSegment(value: _Stage.village, label: Text('In village'), icon: Icon(Icons.cottage)),
                ],
                selected: {_stage},
                onSelectionChanged: (v) => setState(() => _stage = v.first),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildStage(rarity.color),
          const SizedBox(height: 12),
          if (_stage == _Stage.arena) _buildControls(),
          const SizedBox(height: 20),
          Text('Small sizes', style: AppText.heading(18)),
          const SizedBox(height: 8),
          _buildSizes(item),
          const SizedBox(height: 20),
          _InfoPanel(item: item),
        ],
      ),
    );
  }

  Widget _buildStage(Color rarityColor) {
    final def = _sprite;
    if (def != null && _stage == _Stage.village) {
      return LivingVillage(owned: {def.itemId}, height: 360);
    }
    return Container(
      height: 360,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [Color.lerp(rarityColor, const Color(0xFF26346E), 0.55)!, const Color(0xFF0E1228)],
          radius: 0.9,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline, width: 3),
      ),
      alignment: const Alignment(0, 0.75),
      child: def != null
          ? SpriteHero(
              key: ValueKey('${def.itemId}-$_auto'),
              def: def,
              height: 300 * _zoom,
              controller: _ctrl,
              hold: _hold,
              flip: _flip,
              autoEvery: _auto ? const Duration(seconds: 2) : null,
            )
          : _rigOrInitial(250 * _zoom),
    );
  }

  Widget _rigOrInitial(double h) {
    final slug = rigSlugForItemId(widget.itemId);
    if (slug == null) {
      return Text(Catalog.byId[widget.itemId]!.name.substring(0, 1), style: AppText.heading(h * 0.4));
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(_flip ? -1 : 1, 1, 1),
      child: CharacterRig(slug: slug, height: h, anim: _rigAnim),
    );
  }

  Widget _buildControls() {
    final def = _sprite;
    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (def != null) ...[
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            GameButton(
              label: 'Attack',
              icon: Icons.flash_on,
              style: GameButtonStyle.gold,
              compact: true,
              onPressed: _ctrl.attack,
            ),
            GameButton(
              label: _auto ? 'Stop loop' : 'Loop attack',
              icon: Icons.loop,
              style: GameButtonStyle.blue,
              compact: true,
              onPressed: () => setState(() => _auto = !_auto),
            ),
          ]),
          const SizedBox(height: 12),
          Text('Frames', style: AppText.headingPlain(15)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              label: const Text('Live idle'),
              selected: _hold == null,
              onSelected: (_) => setState(() => _hold = null),
            ),
            for (final f in _frames)
              ChoiceChip(
                label: Text(f),
                selected: _hold == f,
                onSelected: (_) => setState(() => _hold = f),
              ),
          ]),
        ] else ...[
          Text('Animations', style: AppText.headingPlain(15)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in RigAnim.values)
              ChoiceChip(
                label: Text(a.name),
                selected: _rigAnim == a,
                onSelected: (_) => setState(() => _rigAnim = a),
              ),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Text('Zoom', style: AppText.headingPlain(14)),
          Expanded(
            child: Slider(
              value: _zoom,
              min: 0.5,
              max: 1.15,
              onChanged: (v) => setState(() => _zoom = v),
            ),
          ),
          Text('Flip', style: AppText.headingPlain(14)),
          Switch(value: _flip, onChanged: (v) => setState(() => _flip = v)),
        ]),
      ]),
    );
  }

  Widget _buildSizes(ShopItem item) {
    final def = _sprite;
    return GamePanel(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in const [40.0, 64.0, 96.0])
            Column(mainAxisSize: MainAxisSize.min, children: [
              CharacterAvatar(item: item, size: s),
              const SizedBox(height: 4),
              Text('${s.toInt()} px', style: AppText.body(11)),
            ]),
          if (def != null)
            Column(mainAxisSize: MainAxisSize.min, children: [
              SpriteHero(def: def, height: 72, tapToAttack: true),
              const SizedBox(height: 4),
              Text('map 72 px', style: AppText.body(11)),
            ]),
        ],
      ),
    );
  }
}

class _InfoPanel extends ConsumerWidget {
  const _InfoPanel({required this.item});

  final ShopItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gameProvider);
    final owned = s.owned.contains(item.id);
    final equipped = s.equipped[item.slot] == item.id;
    final price = [
      if (item.goldPrice != null) '${item.goldPrice} gold',
      if (item.gemPrice != null) '${item.gemPrice} gems',
    ].join('  or  ');

    Widget action;
    if (equipped) {
      action = const GameButton(label: 'Equipped', onPressed: null);
    } else if (owned) {
      action = GameButton(
        label: 'Equip',
        style: GameButtonStyle.blue,
        onPressed: () => ref.read(gameProvider.notifier).equip(item.id),
      );
    } else if (item.forSale) {
      action = GameButton(
        label: 'Buy',
        style: GameButtonStyle.gold,
        onPressed: () => showPurchaseDialog(context, ref, item),
      );
    } else {
      action = const GameButton(label: 'Not for sale', onPressed: null);
    }

    return GamePanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CharacterAvatar(item: item, size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: AppText.headingPlain(20)),
              Text(item.rarity.name.toUpperCase(),
                  style: AppText.body(12, color: rarityOf(item.rarity).color)),
              if (!owned && price.isNotEmpty)
                Text(price, style: AppText.body(13, color: AppColors.panelPrimary)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Text(item.description, style: AppText.body(14)),
        const SizedBox(height: 12),
        Center(child: action),
      ]),
    );
  }
}
