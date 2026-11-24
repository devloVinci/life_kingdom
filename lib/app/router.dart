import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/buildings/building_detail_screen.dart';
import '../features/buildings/buildings_screen.dart';
import '../features/collection/character_detail_screen.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/companions_screen.dart';
import '../features/habits/habit_form_screen.dart';
import '../features/habits/habits_screen.dart';
import '../features/kingdom/kingdom_home_screen.dart';
import '../features/profile/achievements_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/quests/quest_detail_screen.dart';
import '../features/quests/quests_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/calendar_stats_screen.dart';
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
          GoRoute(path: '/quests', builder: (_, __) => const QuestsScreen()),
          GoRoute(path: '/shop', builder: (_, __) => const ShopScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/achievements',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/calendar',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const CalendarStatsScreen(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const SettingsScreen(),
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
        path: '/collection',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const CollectionScreen(),
      ),
      GoRoute(
        path: '/character/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            CharacterDetailScreen(characterId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/companions',
        parentNavigatorKey: rootKey,
        builder: (_, __) => const CompanionsScreen(),
      ),
      GoRoute(
        path: '/quest/:key',
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            QuestDetailScreen(questKey: state.pathParameters['key']!),
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
