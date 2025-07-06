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

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) async {
        debugPrint('Notification response received: ${response.payload}');
      },
    );

    // Request permissions explicitly
    await _requestPermissions();
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true,
          );
      debugPrint('iOS notification permission result: $result');

      // Also check if we actually have permissions
      final settings =
          await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions();
      debugPrint('iOS permission settings: $settings');
    } else if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidPlugin != null) {
        // Request notification permission only
        final notificationPermission =
            await androidPlugin.requestNotificationsPermission();
        debugPrint('Android notification permission: $notificationPermission');
      }
    }
  }

  static Future<void> scheduleDailyProverbNotification(TimeOfDay time) async {
    // debugPrint('=== Starting Daily Proverb Notification Setup ===');
    // debugPrint('Time: ${time.hour}:${time.minute.toString().padLeft(2, '0')}');

    try {
      // Cancel any existing notifications first
      await cancelAllNotifications();

      // Check if we have permission
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        debugPrint('ERROR: No notification permission granted');
        return;
      }

      // Fetch proverb of the day from API
      final proverb = await ProverbsService().fetchProverbOfTheDay();
      // debugPrint('Proverb fetched: ${proverb['igbo']} | ${proverb['english']}');

      // Create notification channels for Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();

        // Check if we can schedule exact notifications
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        // Removed exact alarm permission checks - using standard notifications only
      }

      // Platform-specific notification details
      final androidDetails = AndroidNotificationDetails(
        'proverb_channel',
        'Proverb Notifications',
        channelDescription: 'Daily proverb of the day',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ticker: 'Daily Proverb',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Calculate schedule time
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

      // debugPrint('Current time: $now');
      // debugPrint('First notification time: $firstNotificationTime');
      // debugPrint('Scheduled time: $scheduleTime');
      // debugPrint('Time until notification: ${scheduleTime.difference(now)}');

      // Schedule notifications using inexact alarms (no exact alarm permission needed)
      await _notificationsPlugin.zonedSchedule(
        0,
        "Proverb of the Day",
        '${proverb['igbo'] ?? ''}\n${proverb['english'] ?? ''}',
        scheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      // debugPrint('Notification scheduled with inexact alarm');

      // debugPrint('Notification scheduled successfully');

      // Verify the notification was scheduled
      await debugNotificationStatus();
    } catch (e, stack) {
      debugPrint('ERROR scheduling notification: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  static Future<bool> _checkNotificationPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        // debugPrint('Android notifications enabled: $enabled');
        return enabled ?? false;
      }
    }
    return true; // Assume iOS has permission if we get here
  }

  static Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'proverb_channel',
            'Proverb Notifications',
            description: 'Daily proverb of the day',
            importance: Importance.max,
            showBadge: true,
            enableVibration: true,
            playSound: true,
          ),
        );
        // debugPrint('Android notification channel created');
      }
    }
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

  // Enhanced debug method
  static Future<void> debugNotificationStatus() async {
    try {
      debugPrint('=== Notification Debug Info ===');

      // Check pending notifications
      final pendingNotifications =
          await _notificationsPlugin.pendingNotificationRequests();
      debugPrint('Pending notifications: ${pendingNotifications.length}');

      for (final notification in pendingNotifications) {
        debugPrint('  - ID: ${notification.id}');
        debugPrint('    Title: ${notification.title}');
        debugPrint('    Body: ${notification.body}');
        debugPrint('    Payload: ${notification.payload}');
      }

      // Platform-specific checks
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

      // Timezone info
      final now = tz.TZDateTime.now(tz.local);
      debugPrint('Current timezone: ${tz.local.name}');
      debugPrint('Current time: $now');

      debugPrint('=== End Debug Info ===');
    } catch (e) {
      debugPrint('Error in debug notification status: $e');
    }
  }

  // Enhanced test notification with better error handling
  static Future<void> showTestNotification() async {
    try {
      debugPrint('=== Starting Test Notification ===');

      // Check permissions first
      final hasPermission = await _checkNotificationPermission();
      if (!hasPermission) {
        debugPrint('ERROR: No notification permission for test');
        return;
      }

      // Create channel if Android
      if (Platform.isAndroid) {
        await _createNotificationChannel();

        // Create test channel
        final androidPlugin =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();

        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'test_channel',
              'Test Notifications',
              description: 'Test notifications',
              importance: Importance.max,
              showBadge: true,
              enableVibration: true,
              playSound: true,
            ),
          );
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'test_channel',
        'Test Notifications',
        channelDescription: 'Test notifications',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
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

      // Show immediate notification
      debugPrint('Showing immediate test notification...');
      await _notificationsPlugin.show(
        999,
        'Test Notification',
        'This is a test notification from The Igbo Bible App',
        notificationDetails,
      );

      // Schedule a delayed notification
      debugPrint('Scheduling delayed test notification...');
      final scheduleTime = tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: 10));
      await _notificationsPlugin.zonedSchedule(
        998,
        'Delayed Test Notification',
        'This delayed notification should appear in 10 seconds',
        scheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Test notifications completed successfully');
      await debugNotificationStatus();
    } catch (e, stack) {
      debugPrint('ERROR in test notification: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  // Add this method to test scheduled notifications with short delay
  static Future<void> testScheduledNotification() async {
    try {
      debugPrint('=== Testing Scheduled Notification (30 seconds) ===');

      // Create channels
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      final androidDetails = AndroidNotificationDetails(
        'proverb_channel',
        'Proverb Notifications',
        channelDescription: 'Daily proverb of the day',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ticker: 'Test Scheduled',
      );

      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        badgeNumber: 1,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule for 30 seconds from now
      final scheduleTime = tz.TZDateTime.now(
        tz.local,
      ).add(Duration(seconds: 30));

      debugPrint('Scheduling test notification for: $scheduleTime');
      debugPrint('Current time: ${tz.TZDateTime.now(tz.local)}');

      // Removed exact alarm permission checks - using standard notifications only

      await _notificationsPlugin.zonedSchedule(
        777,
        'Test Scheduled Notification',
        'This should appear in 30 seconds - close the app now!',
        scheduleTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      debugPrint('Test scheduled notification set up successfully');
      debugPrint(
        'IMPORTANT: Close the app completely now and wait 30 seconds!',
      );

      await debugNotificationStatus();
    } catch (e, stack) {
      debugPrint('ERROR in test scheduled notification: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  static Future<void> scheduleEventNotifications() async {
    debugPrint('Scheduling event notifications...');
    try {
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
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );

        // debugPrint(
        //   'Scheduled event notification for ${event.name} on $scheduleTime',
        // );
      }
    } catch (e) {
      debugPrint('Error scheduling event notifications: $e');
    }
  }

  static Future<void> cancelEventNotifications() async {
    // debugPrint('Cancelling event notifications...');
    for (int i = 0; i < 1000; i++) {
      await _notificationsPlugin.cancel(1000 + i);
    }
  }
}
