import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// v22.3.0 exposes requestExactAlarmsPermission() (no canScheduleExactAlarms).

/// Two daily logging nudges. Adaptive exact -> inexact so a revoked or
/// OEM-neutered exact-alarm permission never silently kills the feature.
/// `ponytail:` ceiling — two fixed times now; custom reminders are v0.2.

class NotificationService {
  final FlutterLocalNotificationsPlugin _p = FlutterLocalNotificationsPlugin();

  static const int _idAfternoon = 1;
  static const int _idNight = 2;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // fallback to UTC if it fails
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _p.initialize(settings: const InitializationSettings(android: android));
  }

  Future<void> _scheduleDaily(int id, int hour, int minute, String title, String body) async {
    // Best-effort exact: if the user grants exact-alarm, use it; else inexact.
    final android = _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final exact = (await android?.requestExactAlarmsPermission()) ?? false;

    await _p.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Daily logging nudges',
          channelDescription: 'Remind you to log your day',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> scheduleReminders({
    required bool afternoonOn,
    required bool nightOn,
    required int afternoonHour,
    required int afternoonMinute,
    required int nightHour,
    required int nightMinute,
  }) async {
    await _p.cancel(id: _idAfternoon);
    await _p.cancel(id: _idNight);
    if (afternoonOn) {
      await _scheduleDaily(_idAfternoon, afternoonHour, afternoonMinute,
          'Discipline', "Mark today's ledger.");
    }
    if (nightOn) {
      await _scheduleDaily(_idNight, nightHour, nightMinute,
          'Day\'s end', 'Log what you did. Then rest.');
    }
  }

  /// Ask for runtime notification permission (Android 13+). Returns granted.
  Future<bool> requestPermission() async {
    final ios = await _p
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _p
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return android ?? ios ?? true;
  }

  Future<void> cancelAll() async {
    await _p.cancelAll();
  }
}
