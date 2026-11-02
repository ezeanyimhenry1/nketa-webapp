import 'dart:html' as html;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:nketa/services/app_env.dart';
import 'package:nketa/services/pwa_install.dart';
import 'package:nketa/services/web_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static Function(String)? _notificationCallback;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen((message) {
      _dispatchPayload(message);
      final title = message.notification?.title ?? 'Nketa';
      final body = message.notification?.body ?? '';
      if (html.Notification.permission == 'granted' && body.isNotEmpty) {
        html.Notification(title, body: body, icon: '/icons/Icon-192.png');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen(_dispatchPayload);

    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _dispatchPayload(initial);
    }
  }

  static void _dispatchPayload(RemoteMessage message) {
    final type = message.data['type'] ?? message.data['payload'];
    if (type is String && type.isNotEmpty) {
      _notificationCallback?.call(type);
    }
  }

  static void setNotificationCallback(Function(String) callback) {
    _notificationCallback = callback;
  }

  static Future<void> clearBadge() async {}

  static Future<bool> areNotificationsEnabled() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<bool> requestPermission() async {
    if (PwaInstall.isIosSafari && !PwaInstall.isStandalone) {
      return false;
    }
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> scheduleDailyProverbNotification(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', true);
    await prefs.setInt('notification_hour', time.hour);
    await prefs.setInt('notification_minute', time.minute);
    await _syncSubscription();
  }

  static Future<void> scheduleEventNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('event_notifications_enabled', true);
    await _syncSubscription();
  }

  static Future<void> cancelAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', false);
    await _syncSubscription();
  }

  static Future<void> cancelEventNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('event_notifications_enabled', false);
    await _syncSubscription();
  }

  static Future<void> _syncSubscription() async {
    if (!WebBackend.isEnabled) {
      debugPrint('WEB_API_BASE_URL is not set; skip web push registration');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final proverbEnabled = prefs.getBool('notifications_enabled') ?? false;
    final eventsEnabled = prefs.getBool('event_notifications_enabled') ?? false;
    final hour = prefs.getInt('notification_hour') ?? 8;
    final minute = prefs.getInt('notification_minute') ?? 0;

    if (!proverbEnabled && !eventsEnabled) {
      final existing = prefs.getString('web_push_token');
      if (existing != null && existing.isNotEmpty) {
        await WebBackend.post(
          '/registerWebPush',
          body: {'token': existing, 'enabled': false},
        );
      }
      return;
    }

    final vapidKey = AppEnv.get('FIREBASE_VAPID_KEY') ?? '';
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: vapidKey.isEmpty ? null : vapidKey,
    );
    if (token == null || token.isEmpty) {
      debugPrint('Failed to get FCM web token');
      return;
    }
    await prefs.setString('web_push_token', token);

    await WebBackend.post(
      '/registerWebPush',
      body: {
        'token': token,
        'enabled': true,
        'proverbEnabled': proverbEnabled,
        'eventsEnabled': eventsEnabled,
        'hour': hour,
        'minute': minute,
        'timezone': 'Africa/Lagos',
        'uid': FirebaseAuth.instance.currentUser?.uid,
      },
    );
  }
}
