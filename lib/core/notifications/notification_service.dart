// coverage:ignore-file
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings(
      'animeroll_icon_violeta',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> scheduleEpisodeReminder({
    required int id,
    required String title,
    required DateTime at,
    String? body,
  }) async {
    await init();
    final permitted = await requestPermission();
    if (!permitted) return;
    final reminderAt = at.subtract(const Duration(minutes: 30));
    final scheduledAt = reminderAt.isAfter(DateTime.now())
        ? reminderAt
        : at.isAfter(DateTime.now())
        ? at
        : null;
    if (scheduledAt == null) return;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'schedule_reminders',
          'Recordatorios de horario',
          channelDescription: 'Avisos antes de que se emita un episodio',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'schedule:$id',
    );
  }

  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id: id);
  }
}
