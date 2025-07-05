import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:the_igbo_bible/screens/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:the_igbo_bible/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  await NotificationService.initialize();

  // Request notification permission on startup
  await requestNotificationPermissionOnStartup();

  // Check user preferences before scheduling notifications
  await _checkAndScheduleNotifications();

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

  runApp(const MyApp());
}

Future<void> requestNotificationPermissionOnStartup() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } else if (Platform.isAndroid) {
    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }
}

Future<void> _checkAndScheduleNotifications() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled =
        prefs.getBool('notifications_enabled') ?? false;

    if (notificationsEnabled) {
      final hour = prefs.getInt('notification_hour') ?? 8;
      final minute = prefs.getInt('notification_minute') ?? 0;
      final notificationTime = TimeOfDay(hour: hour, minute: minute);

      await NotificationService.scheduleDailyProverbNotification(
        notificationTime,
      );
    }
  } catch (e) {
    debugPrint('Error checking notification preferences: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844), // iPhone 13 Pro Max size
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          title: 'The Igbo Bible',
          theme: AppTheme.lightTheme,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en', '')],
          home: _showSplash ? const SplashScreen() : const MainScreen(),
        );
      },
    );
  }
}
