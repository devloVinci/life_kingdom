import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/buildings/building_detail_screen.dart';
import '../features/buildings/buildings_screen.dart';
import '../features/habits/habit_form_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/kingdom/kingdom_home_screen.dart';
import '../features/placeholder/coming_soon_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/shop/shop_screen.dart';

GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: '/home',
    routes: [
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) =>
            MainShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
              path: '/home', builder: (_, __) => const KingdomHomeScreen()),
          GoRoute(path: '/habits', builder: (_, __) => const HabitsScreen()),
          GoRoute(
              path: '/quests',
              builder: (_, __) => const ComingSoonScreen(title: 'Quests')),
          GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
          GoRoute(
              path: '/profile',
              builder: (_, __) => const ComingSoonScreen(title: 'Profile')),
        ],
      ),
      GoRoute(
        path: '/buildings',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const BuildingsScreen(),
      ),
      GoRoute(
        path: '/building/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            BuildingDetailScreen(buildingId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/habit/new',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const HabitFormScreen(),
      ),
      GoRoute(
        path: '/habit/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            HabitFormScreen(habitId: state.pathParameters['id']),
      ),
    ],
  );
}
