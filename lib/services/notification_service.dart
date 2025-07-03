import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'dart:io' show Platform;
import 'package:the_igbo_bible/services/event_service.dart';
import 'package:the_igbo_bible/services/proverbs_service.dart';

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
    final DarwinInitializationSettings initializationSettingsIOS =
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

    // Explicitly request permissions on iOS
    if (Platform.isIOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      debugPrint('iOS notification permission result: $result');
    }
  }

  static Future<void> scheduleDailyProverbNotification(TimeOfDay time) async {
    // debugPrint(
    //   'scheduleDailyProverbNotification called with time: [1m${time.hour}:${time.minute.toString().padLeft(2, '0')}[0m',
    // );
    // Cancel any existing notifications first
    await cancelAllNotifications();

    // Fetch proverb of the day from API
    final proverb = await ProverbsService().fetchProverbOfTheDay();
    // debugPrint(
    //   'Proverb to schedule: [1m${proverb['igbo']} | ${proverb['english']}[0m',
    // );

    // Platform-specific notification details
    final androidDetails = AndroidNotificationDetails(
      'proverb_channel',
      'Proverb Notifications',
      channelDescription: 'Daily proverb of the day',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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
    // debugPrint('Now: $now');
    // debugPrint('First notification time: $firstNotificationTime');
    // debugPrint('Schedule time: $scheduleTime');

    try {
      await _notificationsPlugin.zonedSchedule(
        0,
        "Proverb of the Day",
        '${proverb['igbo'] ?? ''}\n${proverb['english'] ?? ''}',
        scheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      // debugPrint('zonedSchedule called successfully');

      // For testing on iOS simulator, also schedule a test notification in 5 seconds
      // if (Platform.isIOS) {
      //   await _notificationsPlugin.zonedSchedule(
      //     1,
      //     "Test Notification",
      //     "This is a test notification from The Igbo Bible",
      //     tz.TZDateTime.now(tz.local).add(Duration(seconds: 5)),
      //     notificationDetails,
      //     androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      //     uiLocalNotificationDateInterpretation:
      //         UILocalNotificationDateInterpretation.absoluteTime,
      //   );
      //   debugPrint('Test notification scheduled for iOS (5 seconds from now)');
      // }
    } catch (e, stack) {
      debugPrint('Error scheduling notification: $e');
      debugPrint('Stack trace: $stack');
    }
    // debugPrint('scheduleDailyProverbNotification finished');
  }

  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    // debugPrint('All notifications cancelled');
  }

  static Future<bool> areNotificationsScheduled() async {
    final pendingNotifications =
        await _notificationsPlugin.pendingNotificationRequests();
    return pendingNotifications.isNotEmpty;
  }

  // Debug method to check notification status
  static Future<void> debugNotificationStatus() async {
    try {
      debugPrint('=== Notification Debug Info ===');

      // Check pending notifications
      final pendingNotifications =
          await _notificationsPlugin.pendingNotificationRequests();
      debugPrint('Pending notifications: ${pendingNotifications.length}');
      for (final notification in pendingNotifications) {
        debugPrint('  - ID: ${notification.id}, Title: ${notification.title}');
      }

      // Check if notifications are enabled (Android)
      if (Platform.isAndroid) {
        final androidPlugin =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        if (androidPlugin != null) {
          final enabled = await androidPlugin.areNotificationsEnabled();
          debugPrint('Android notifications enabled: $enabled');
        }
      }

      debugPrint('=== End Debug Info ===');
    } catch (e) {
      debugPrint('Error in debug notification status: $e');
    }
  }

  // For testing notifications immediately
  static Future<void> showTestNotification() async {
    try {
      debugPrint('Starting test notification...');

      final androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notifications',
        importance: Importance.max,
        priority: Priority.high,
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      debugPrint('Showing test notification...');
      await _notificationsPlugin.show(
        999,
        'Test Notification',
        'This is a test notification from The Igbo Bible App',
        notificationDetails,
      );
      debugPrint('Test notification show() completed successfully');

      // Also try scheduling a notification for 3 seconds from now
      debugPrint('Scheduling delayed test notification...');
      await _notificationsPlugin.zonedSchedule(
        998,
        'Delayed Test Notification',
        'This is a delayed test notification',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: 3)),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Delayed test notification scheduled');
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  static Future<void> scheduleEventNotifications() async {
    // debugPrint('Scheduling event notifications...');
    final events = await EventService().loadEvents();
    final now = DateTime.now();
    int baseId = 1000;
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      DateTime eventDate = event.date;
      if (event.recurring) {
        // Find next occurrence
        final today = DateTime(now.year, now.month, now.day);
        eventDate = DateTime(today.year, event.date.month, event.date.day);
        if (eventDate.isBefore(today)) {
          eventDate = DateTime(
            today.year + 1,
            event.date.month,
            event.date.day,
          );
        }
      }
      if (eventDate.isBefore(now)) continue;
      final scheduleTime = tz.TZDateTime(
        tz.local,
        eventDate.year,
        eventDate.month,
        eventDate.day,
        8, // 8:00 AM
        0,
      );
      final androidDetails = AndroidNotificationDetails(
        'event_channel',
        'Event Notifications',
        channelDescription: 'Igbo event reminders',
        importance: Importance.max,
        priority: Priority.high,
      );
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notificationsPlugin.zonedSchedule(
        baseId + i,
        'Igbo Event: ${event.name}',
        '${event.description}\n${eventDate.toLocal().toString().split(' ')[0]}${event.location != null ? '\n${event.location}' : ''}',
        scheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );
      // debugPrint(
      //   'Scheduled event notification for ${event.name} on $scheduleTime',
      // );
    }
  }

  static Future<void> cancelEventNotifications() async {
    // debugPrint('Cancelling event notifications...');
    for (int i = 0; i < 1000; i++) {
      await _notificationsPlugin.cancel(1000 + i);
    }
  }
}
