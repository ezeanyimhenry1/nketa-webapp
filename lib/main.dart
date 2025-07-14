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
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:the_igbo_bible/services/network_status_provider.dart';
import 'package:the_igbo_bible/widgets/global_network_banner.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper options first
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize timezone data
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Africa/Lagos'));

  runApp(
    ChangeNotifierProvider(
      create: (_) => NetworkStatusProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);

    // Initialize non-critical services after app starts
    _initializeServicesAsync();

    // Clear badge on iOS when app is opened
    NotificationService.clearBadge();

    // Set up notification tap handler
    _setupNotificationHandler();

    // Show splash for shorter duration
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showSplash = false);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Clear badge when app is resumed
    if (state == AppLifecycleState.resumed) {
      NotificationService.clearBadge();
    }
  }

  Future<void> _initializeServicesAsync() async {
    try {
      // Initialize notification service
      await NotificationService.initialize();

      // Request notification permissions
      await _requestNotificationPermissions();

      // Schedule notifications
      await _checkAndScheduleNotifications();
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  Future<void> _requestNotificationPermissions() async {
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
      final eventNotificationsEnabled =
          prefs.getBool('event_notifications_enabled') ?? false;

      if (notificationsEnabled) {
        final hour = prefs.getInt('notification_hour') ?? 8;
        final minute = prefs.getInt('notification_minute') ?? 0;
        final notificationTime = TimeOfDay(hour: hour, minute: minute);

        await NotificationService.scheduleDailyProverbNotification(
          notificationTime,
        );
      }

      if (eventNotificationsEnabled) {
        await NotificationService.scheduleEventNotifications();
      }
    } catch (e) {
      debugPrint('Error checking notification preferences: $e');
    }
  }

  void _setupNotificationHandler() {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (response) async {
        // Clear badge on tap (no dialog needed)
        NotificationService.clearBadge();
      },
    );
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
          home: GlobalNetworkBanner(
            child: _showSplash ? const SplashScreen() : const MainScreen(),
          ),
        );
      },
    );
  }
}
