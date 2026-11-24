import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_planner.dart';
import 'notification_service.dart';

NotificationService createPlatformNotificationService() {
  if (kIsWeb) return const NoopNotificationService();
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return const NoopNotificationService();
  }
  return _LocalNotificationService();
}

class _LocalNotificationService implements NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _init;
  List<PlannedNotification>? _last;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'life_kingdom_reminders',
      'Reminders',
      channelDescription: 'Habit and kingdom reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  bool get supported => true;

  Future<void> _ensureInit() => _init ??= _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );

  @override
  Future<bool> requestPermission() async {
    await _ensureInit();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return (await android.requestNotificationsPermission()) ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return (await ios?.requestPermissions(
            alert: true, badge: true, sound: true)) ??
        false;
  }

  @override
  Future<void> replaceAll(List<PlannedNotification> plan) async {
    // Skip the OS round trip when nothing changed.
    if (_last != null && listEquals(_last, plan)) return;
    await _ensureInit();
    await _plugin.cancelAll();
    var id = 1;
    for (final n in plan) {
      await _plugin.zonedSchedule(
        id++,
        n.title,
        n.body,
        // Only the instant matters for one-shot notifications.
        tz.TZDateTime.from(n.at, tz.UTC),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    _last = List.of(plan);
  }

  @override
  Future<void> sendTest() async {
    await _ensureInit();
    await _plugin.show(0, 'Life Kingdom',
        'Notifications work! Your kingdom will keep you on track.', _details);
  }
}
