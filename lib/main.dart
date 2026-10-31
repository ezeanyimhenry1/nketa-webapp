import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/screens/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nketa/screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:nketa/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:nketa/services/network_status_provider.dart';
import 'package:nketa/widgets/global_network_banner.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await dotenv.load(fileName: ".env");

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

    WidgetsBinding.instance.addObserver(this);

    _initializeServicesAsync();

    NotificationService.clearBadge();

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

    if (state == AppLifecycleState.resumed) {
      NotificationService.clearBadge();
    }
  }

  Future<void> _initializeServicesAsync() async {
    try {
      await NotificationService.initialize();

      NotificationService.setNotificationCallback((payload) {
        if (!mounted) return;
        if (payload == 'proverb_of_the_day') {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        } else if (payload == 'event') {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        }
      });

      if (kIsWeb) return;

      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? false;
      final eventNotificationsEnabled =
          prefs.getBool('event_notifications_enabled') ?? false;

      final permissionGranted =
          await NotificationService.areNotificationsEnabled();

      if (permissionGranted &&
          (!notificationsEnabled || !eventNotificationsEnabled)) {
        final hour = prefs.getInt('notification_hour') ?? 8;
        final minute = prefs.getInt('notification_minute') ?? 0;
        final notificationTime = TimeOfDay(hour: hour, minute: minute);

        if (!notificationsEnabled) {
          await prefs.setBool('notifications_enabled', true);
          await prefs.setInt('notification_hour', hour);
          await prefs.setInt('notification_minute', minute);
          await NotificationService.scheduleDailyProverbNotification(
            notificationTime,
          );
        }
        if (!eventNotificationsEnabled) {
          await prefs.setBool('event_notifications_enabled', true);
          await NotificationService.scheduleEventNotifications();
        }
      }

      await _checkAndScheduleNotifications();
    } catch (e) {
      debugPrint('Error initializing services: $e');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en', '')],
      builder: (context, child) {
        final framed = _webPhoneFrame(context, child ?? const SizedBox.shrink());
        return ScreenUtilInit(
          designSize: const Size(390, 844),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) => framed,
        );
      },
      home: GlobalNetworkBanner(
        child: _showSplash ? const SplashScreen() : const MainScreen(),
      ),
    );
  }

  Widget _webPhoneFrame(BuildContext context, Widget child) {
    if (!kIsWeb) return child;
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 430) return child;
    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: Container(
          width: 390,
          height: size.height,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(390, size.height),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
