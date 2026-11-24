import 'notification_planner.dart';

/// Delivers [PlannedNotification]s through the operating system.
abstract class NotificationService {
  /// False on platforms that cannot show scheduled notifications (web).
  bool get supported;

  /// Asks the OS for permission; true when granted.
  Future<bool> requestPermission();

  /// Cancels everything pending and schedules exactly [plan].
  Future<void> replaceAll(List<PlannedNotification> plan);

  /// Shows a notification right now (for the "send test" button).
  Future<void> sendTest();
}

/// Used on web and in tests: does nothing.
class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  bool get supported => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> replaceAll(List<PlannedNotification> plan) async {}

  @override
  Future<void> sendTest() async {}
}
