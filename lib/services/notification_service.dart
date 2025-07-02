import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:the_igbo_bible/data/proverbs.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static bool _tzInitialized = false;

  static Future<void> initialize() async {
    if (!_tzInitialized) {
      tzdata.initializeTimeZones();
      _tzInitialized = true;
    }
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );
    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> scheduleDailyProverbNotification(TimeOfDay time) async {
    final proverb = getProverbOfTheDay();
    final androidDetails = AndroidNotificationDetails(
      'proverb_channel',
      'Proverb Notifications',
      channelDescription: 'Daily proverb of the day',
      importance: Importance.max,
      priority: Priority.high,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);
    final now = tz.TZDateTime.now(tz.local);
    final firstNotificationTime = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    final scheduleTime =
        firstNotificationTime.isAfter(now)
            ? firstNotificationTime
            : firstNotificationTime.add(Duration(days: 1));
    await _notificationsPlugin.zonedSchedule(
      0,
      "Proverb of the Day",
      '${proverb['igbo']}\n${proverb['english']}',
      scheduleTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
