import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Bottom navigation. The Kingdom button sits raised in the middle.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    _Tab('/habits', Icons.checklist_rounded, 'Today', Color(0xFF3FAE73)),
    _Tab('/quests', Icons.flag_rounded, 'Quests', Color(0xFFFF8A3D)),
    _Tab('/home', Icons.castle_rounded, 'Kingdom', Color(0xFFE8B84A), big: true),
    _Tab('/heroes', Icons.shield_rounded, 'Heroes', Color(0xFFA855F7)),
    _Tab('/shop', Icons.storefront_rounded, 'Shop', Color(0xFF4C7BE0)),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final onHome = location.startsWith('/home');
    return Scaffold(
      extendBody: onHome,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.navBar,
          borderRadius: BorderRadius.vertical(top: Radius.circular(p.chunky ? 26 : 22)),
          border: p.chunky
              ? Border(
                  top: BorderSide(color: AppColors.outline, width: 4),
                  left: BorderSide(color: AppColors.outline, width: 4),
                  right: BorderSide(color: AppColors.outline, width: 4),
                )
              : Border(top: BorderSide(color: Colors.white.withValues(alpha: p.isDark ? 0.08 : 0.0))),
          boxShadow: p.chunky
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: p.isDark ? 0.45 : 0.12), blurRadius: 24)],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final t in _tabs)
                  Expanded(
                    child: _NavButton(
                      tab: t,
                      selected: location.startsWith(t.path),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go(t.path);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.path, this.icon, this.label, this.color, {this.big = false});
  final String path;
  final IconData icon;
  final String label;
  final Color color;
  final bool big;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.palette;
    final muted = p.chunky
        ? const Color(0xFFB9C8EA)
        : (p.isDark ? p.textMuted : p.textMuted);
    final active = p.chunky ? Colors.white : (p.isDark ? Colors.white : p.text);

    final Widget icon;
    if (tab.big) {
      icon = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(tab.color, Colors.white, 0.35)!, tab.color, Color.lerp(tab.color, Colors.black, 0.35)!],
            stops: const [0, 0.6, 1],
          ),
          border: Border.all(
              color: p.chunky ? (selected ? Colors.white : AppColors.outline) : Colors.white.withValues(alpha: selected ? 0.7 : 0.25),
              width: p.chunky ? 3 : 1.5),
          boxShadow: [
            BoxShadow(color: tab.color.withValues(alpha: selected ? 0.6 : 0.3), blurRadius: selected ? 18 : 8),
          ],
        ),
        child: Icon(tab.icon, color: const Color(0xFF2A1C04), size: 26),
      );
    } else if (p.chunky) {
      icon = AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: tab.color,
          shape: BoxShape.circle,
          border: Border.all(color: selected ? Colors.white : AppColors.outline, width: 3),
        ),
        child: Icon(tab.icon, color: Colors.white, size: 21),
      );
    } else {
      icon = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tab.color.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedScale(
          scale: selected ? 1.12 : 1,
          duration: const Duration(milliseconds: 200),
          child: Icon(tab.icon, color: selected ? tab.color : muted, size: 23),
        ),
      );
    }

    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: icon)),
            const SizedBox(height: 3),
            Text(tab.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: AppText.body(11, color: selected ? active : muted, weight: selected ? FontWeight.w900 : FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}
