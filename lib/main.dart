import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'core/data/game_repository.dart';
import 'core/notifications/notification_providers.dart';
import 'core/notifications/notification_service_stub.dart'
    if (dart.library.io) 'core/notifications/notification_service_mobile.dart';
import 'features/ow/ow_style.dart';

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
    return MaterialApp.router(
      title: 'المملكة',
      debugShowCheckedModeBanner: false,
      theme: Ow.theme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(_routerProvider),
    );
  }
}
