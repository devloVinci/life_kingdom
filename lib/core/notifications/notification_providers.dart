import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'notification_planner.dart';
import 'notification_service.dart';

/// Overridden in main() with the real platform service.
final notificationServiceProvider =
    Provider<NotificationService>((ref) => const NoopNotificationService());

/// Keeps the OS schedule in sync with the game state. Watch it once at app
/// start; it re-plans on app open and on every state change.
final notificationSyncProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final clock = ref.watch(clockProvider);

  Future<void> sync() async {
    if (!service.supported) return;
    try {
      await service.replaceAll(
          NotificationPlanner.plan(ref.read(gameProvider), clock()));
    } catch (_) {
      // Scheduling is best-effort and must never break the app.
    }
  }

  ref.listen(gameProvider, (_, __) => sync());
  sync();
});
