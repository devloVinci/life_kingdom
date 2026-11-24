import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _tabs = [
    ('/home', Icons.castle, 'Kingdom'),
    ('/habits', Icons.checklist, 'Habits'),
    ('/quests', Icons.flag, 'Quests'),
    ('/shop', Icons.storefront, 'Shop'),
    ('/profile', Icons.person, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    var index = _tabs.indexWhere((t) => location.startsWith(t.$1));
    if (index < 0) index = 0;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].$1),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(icon: Icon(t.$2), label: t.$3),
        ],
      ),
    );
  }
}
