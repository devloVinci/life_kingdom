import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/data/game_repository.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service_stub.dart'
    if (dart.library.io) 'core/notifications/notification_service_mobile.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = SharedPrefsGameRepository();
  final state = await repo.load();
  runApp(ProviderScope(
    overrides: [
      gameRepositoryProvider.overrideWithValue(repo),
      initialGameStateProvider.overrideWithValue(state),
      notificationServiceProvider
          .overrideWithValue(createPlatformNotificationService()),
    ],
    child: const LifeKingdomApp(),
  ));
}

final _routerProvider = Provider((ref) => buildRouter());

class LifeKingdomApp extends ConsumerWidget {
  const LifeKingdomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationSyncProvider);
    final palette = ref.watch(uiPaletteProvider);
    // Interface colours are read statically; switching the UI theme rebuilds
    // the whole tree (the router keeps its location).
    AppColors.palette = palette;
    return MaterialApp.router(
      key: ValueKey(palette.id),
      title: 'Life Kingdom',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(palette),
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
