import 'package:go_router/go_router.dart';

import '../features/ow/gallery/gallery_screen.dart';
import '../features/ow/ow_shell.dart';
import '../features/settings/settings_screen.dart';
import '../features/stats/calendar_stats_screen.dart';

GoRouter buildRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => const OwShell()),
        GoRoute(
            path: '/settings', builder: (_, __) => const SettingsScreen()),
        GoRoute(
            path: '/calendar',
            builder: (_, __) => const CalendarStatsScreen()),
        GoRoute(path: '/gallery', builder: (_, __) => const GalleryScreen()),
      ],
    );
