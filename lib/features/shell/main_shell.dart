import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';

/// Bottom navigation: round coloured buttons, the Kingdom button in the
/// middle is bigger (Figma Home).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    _Tab('/habits', Icons.checklist, 'Habits', AppColors.buttonGreen),
    _Tab('/quests', Icons.flag, 'Quests', Color(0xFFFF8A3D)),
    _Tab('/home', Icons.castle, 'Kingdom', AppColors.gold, big: true),
    _Tab('/heroes', Icons.shield, 'Heroes', AppColors.gem),
    _Tab('/shop', Icons.storefront, 'Shop', AppColors.buttonBlue),
  ];

  @override
  Widget build(BuildContext context) {
    final onHome = location.startsWith('/home');
    return Scaffold(
      extendBody: onHome,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.panelDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(
            top: BorderSide(color: AppColors.outline, width: 4),
            left: BorderSide(color: AppColors.outline, width: 4),
            right: BorderSide(color: AppColors.outline, width: 4),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 78,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final t in _tabs)
                  _NavButton(
                    tab: t,
                    selected: location.startsWith(t.path),
                    onTap: () => context.go(t.path),
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
  const _NavButton(
      {required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = tab.big ? 58.0 : 46.0;
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 64,
          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              margin: EdgeInsets.only(bottom: selected ? 4 : 0),
              decoration: BoxDecoration(
                color: tab.color,
                shape: BoxShape.circle,
                border: Border.all(
                    color: selected ? Colors.white : AppColors.outline,
                    width: 3),
                boxShadow: [
                  BoxShadow(
                      color: selected
                          ? tab.color.withOpacity(.8)
                          : AppColors.outline,
                      offset: selected ? Offset.zero : const Offset(0, 3),
                      blurRadius: selected ? 10 : 0),
                ],
              ),
              child: Icon(tab.icon, color: Colors.white, size: size * .5),
            ),
            const SizedBox(height: 3),
            Text(tab.label,
                style: AppText.body(12,
                    color: selected ? Colors.white : const Color(0xFFB9C8EA),
                    weight: FontWeight.w800)),
            const SizedBox(height: 6),
          ]),
        ),
      ),
    );
  }
}
