import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/characters/skinned/skinned_character.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/game_button.dart';
import '../../core/widgets/game_panel.dart';
import '../kingdom/living_village.dart';

/// Proof-of-concept screen for the painted, skinned hero.
/// Shows every clip and the same character reused at the sizes the app
/// needs (dashboard, profile, level-up, achievements, lists).
class CharacterLabScreen extends StatefulWidget {
  const CharacterLabScreen({super.key});

  @override
  State<CharacterLabScreen> createState() => _CharacterLabScreenState();
}

class _CharacterLabScreenState extends State<CharacterLabScreen> {
  final _stage = CharacterAnimController();
  final _profile = CharacterAnimController();
  bool _walking = false;

  static const _clips = [
    ('victory', 'Victory', GameButtonStyle.gold),
    ('levelUp', 'Level up', GameButtonStyle.gold),
    ('skill', 'Skill', GameButtonStyle.blue),
    ('hit', 'Damage', GameButtonStyle.danger),
  ];

  @override
  void dispose() {
    _stage.dispose();
    _profile.dispose();
    super.dispose();
  }

  Future<void> _showLevelUp() async {
    final c = CharacterAnimController();
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC0B1026),
      builder: (ctx) {
        WidgetsBinding.instance.addPostFrameCallback((_) => c.play('levelUp'));
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('LEVEL UP!', style: AppText.heading(34, color: AppColors.gold)),
            SizedBox(height: 320, child: SkinnedCharacter(controller: c)),
            Text('Level 12 reached', style: AppText.heading(18)),
            const SizedBox(height: 12),
            GameButton(label: 'Awesome', onPressed: () => Navigator.pop(ctx)),
          ]),
        );
      },
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1228),
      appBar: AppBar(
        title: const Text('Character Lab'),
        backgroundColor: AppColors.panelDeep,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 0. kingdom revamp: living village preview with the new heroes
          Text('Living village (revamp preview)', style: AppText.heading(20)),
          const SizedBox(height: 4),
          Text('Tap Dhul-Qurayn to attack; tap Hayyab in the sky to make him land and breathe fire.',
              style: AppText.body(12, color: Colors.white70)),
          const SizedBox(height: 10),
          const LivingVillage(
            owned: {'char_juggernaut', 'char_dragon_hayyab'},
            height: 320,
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
            for (final id in const ['char_juggernaut', 'char_dragon_hayyab'])
              GameButton(
                label: 'Preview ${id == 'char_juggernaut' ? 'Dhul-Qurayn' : 'Hayyab'}',
                icon: Icons.visibility,
                compact: true,
                style: GameButtonStyle.blue,
                onPressed: () => context.push('/hero/$id'),
              ),
          ]),
          const SizedBox(height: 24),
          // 1. stage with every clip
          Container(
            height: 380,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Color(0xFF26346E), Color(0xFF0E1228)],
                radius: 0.9,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline, width: 3),
            ),
            child: SkinnedCharacter(
              key: const Key('lab_stage'),
              controller: _stage,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              GameButton(
                label: _walking ? 'Stop' : 'Walk',
                compact: true,
                onPressed: () {
                  setState(() => _walking = !_walking);
                  _stage.setLoop(_walking ? 'walk' : 'idle');
                },
              ),
              for (final c in _clips)
                GameButton(
                  label: c.$2,
                  style: c.$3,
                  compact: true,
                  onPressed: () => _stage.play(c.$1),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Reused across the app', style: AppText.heading(20)),
          const SizedBox(height: 12),

          // 2. dashboard hero card
          GamePanel(
            color: AppColors.panelPrimary,
            child: Row(children: [
              const SizedBox(width: 110, height: 150, child: SkinnedCharacter()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: AppText.heading(18)),
                    Text('Idle loop with breathing and blinking',
                        style: AppText.body(12, color: Colors.white70)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // 3. profile header: tap to celebrate
          GamePanel(
            child: Row(children: [
              GestureDetector(
                onTap: () => _profile.play('victory'),
                child: Container(
                  width: 96,
                  height: 96,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.panelLight,
                    border: Border.all(color: AppColors.outline, width: 3),
                  ),
                  child: Transform.scale(
                    scale: 1.9,
                    alignment: const Alignment(0, -0.55),
                    child: SkinnedCharacter(
                        controller: _profile, showShadow: false),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Profile avatar (tap it)',
                    style: AppText.headingPlain(16)),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          // 4. level-up celebration overlay
          Center(
            child: GameButton(
              label: 'Show level-up celebration',
              style: GameButtonStyle.gold,
              onPressed: _showLevelUp,
            ),
          ),
          const SizedBox(height: 12),

          // 5. achievement tile and still thumbnails (cheap, not animated)
          GamePanel(
            child: Row(children: [
              const SizedBox(
                width: 70,
                height: 90,
                child: SkinnedCharacter(clip: 'victory'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Achievement: 30-day streak',
                    style: AppText.headingPlain(15)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          GamePanel(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < 4; i++)
                  const SizedBox(
                    width: 56,
                    height: 72,
                    child: SkinnedCharacter(animate: false, showShadow: false),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
