import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:the_igbo_bible/services/notification_service.dart';
import 'package:the_igbo_bible/services/usage_service.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:the_igbo_bible/theme/app_strings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';
import 'package:the_igbo_bible/screens/support_screen.dart';
import 'package:the_igbo_bible/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;
  bool _eventNotificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);
  bool _loading = true;
  bool _permissionGranted = false;

  // Usage tracking
  Map<String, int> _usageStats = {'translations': 0, 'images': 0};
  bool _isSubscribed = false;
  bool _loadingUsage = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkNotificationPermission();
    _loadUsageStats();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
        _eventNotificationsEnabled =
            prefs.getBool('event_notifications_enabled') ?? false;
        final hour = prefs.getInt('notification_hour') ?? 8;
        final minute = prefs.getInt('notification_minute') ?? 0;
        _notificationTime = TimeOfDay(hour: hour, minute: minute);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', _notificationsEnabled);
      await prefs.setBool(
        'event_notifications_enabled',
        _eventNotificationsEnabled,
      );
      await prefs.setInt('notification_hour', _notificationTime.hour);
      await prefs.setInt('notification_minute', _notificationTime.minute);
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  Future<void> _loadUsageStats() async {
    try {
      final usageService = UsageService();
      final stats = await usageService.getUsageStats();
      final subscribed = await usageService.isSubscribed();

      setState(() {
        _usageStats = stats;
        _isSubscribed = subscribed;
        _loadingUsage = false;
      });
    } catch (e) {
      debugPrint('Error loading usage stats: $e');
      setState(() => _loadingUsage = false);
    }
  }

  Future<void> _checkNotificationPermission() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        final granted = await androidPlugin.areNotificationsEnabled();
        setState(() {
          _permissionGranted =
              granted ?? true; // Default to true if we can't determine
        });
      } else {
        // If we can't check Android permissions, assume they're granted
        setState(() {
          _permissionGranted = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      // If there's an error checking permissions, assume they're granted
      setState(() {
        _permissionGranted = true;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      final androidPlugin =
          flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        setState(() {
          _permissionGranted =
              granted ?? true; // Default to true if we can't determine
        });

        if ((granted ?? true) && _notificationsEnabled) {
          await NotificationService.scheduleDailyProverbNotification(
            _notificationTime,
          );
        }
      } else {
        // If we can't request permissions, assume they're granted
        setState(() {
          _permissionGranted = true;
        });
        if (_notificationsEnabled) {
          await NotificationService.scheduleDailyProverbNotification(
            _notificationTime,
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
      // If there's an error, assume permissions are granted
      setState(() {
        _permissionGranted = true;
      });
      if (_notificationsEnabled) {
        await NotificationService.scheduleDailyProverbNotification(
          _notificationTime,
        );
      }
    }
  }

  Future<void> _pickNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null) {
      setState(() => _notificationTime = picked);
      await _saveSettings();
      if (_notificationsEnabled && _permissionGranted) {
        await NotificationService.scheduleDailyProverbNotification(picked);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification time updated to ${picked.format(context)}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _toggleNotifications(bool value) async {
    if (value && !_permissionGranted) {
      await _requestNotificationPermission();
      if (!_permissionGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notification permission is required to enable notifications',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
    }

    setState(() => _notificationsEnabled = value);
    await _saveSettings();

    if (value) {
      await NotificationService.scheduleDailyProverbNotification(
        _notificationTime,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Daily proverb notifications enabled for ${_notificationTime.format(context)}',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      await NotificationService.cancelAllNotifications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily proverb notifications disabled'),
          backgroundColor: AppColors.info,
        ),
      );
    }
  }

  void _openPrivacyPolicy() async {
    const url = 'https://theigbobible.netlify.app/privacy';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openTermsOfUse() async {
    const url = 'https://theigbobible.netlify.app/terms';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _contactSupport() async {
    final email = Uri(
      scheme: 'mailto',
      path: 'theigbobible@gmail.com',
      query: 'subject=The Igbo Bible App Support',
    );
    if (await canLaunchUrl(email)) {
      await launchUrl(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Settings',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontFamily: 'AguDisplay',
            ),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: ShimmerLoader(height: 32, width: 32)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontFamily: 'AguDisplay',
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: AppColors.background,
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg),
          children: [
            // App branding header
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Row(
                children: [
                  Text(
                    "運 ",
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Akagu',
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    AppStrings.appTitle,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'AguDisplay',
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // Notifications Section
            Text(
              'Notifications',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Column(
                children: [
                  if (!_permissionGranted)
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      margin: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withAlpha((0.1 * 255).toInt()),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.cardRadius,
                        ),
                        border: Border.all(
                          color: AppColors.warning.withAlpha(
                            (0.3 * 255).toInt(),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Notification permission required',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.warning,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    title: Text(
                      'Daily Proverb Notifications',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _notificationsEnabled
                          ? 'You\'ll receive daily proverbs at ${_notificationTime.format(context)}'
                          : 'Get inspired with daily Igbo proverbs',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    secondary: Icon(
                      Icons.notifications_active,
                      color:
                          _notificationsEnabled
                              ? AppColors.primary
                              : Colors.grey,
                      size: AppSpacing.iconSize,
                    ),
                    value: _notificationsEnabled,
                    onChanged: _permissionGranted ? _toggleNotifications : null,
                    activeColor: AppColors.primary,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.access_time,
                      color: AppColors.secondary,
                      size: AppSpacing.iconSize,
                    ),
                    title: Text(
                      'Notification Time',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      _notificationTime.format(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: OutlinedButton(
                      onPressed:
                          _notificationsEnabled ? _pickNotificationTime : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                        ),
                      ),
                      child: const Text('Change'),
                    ),
                    enabled: _notificationsEnabled,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      'Event Notifications',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Get notified on the day of Igbo events',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    secondary: Icon(
                      Icons.event,
                      color:
                          _eventNotificationsEnabled
                              ? AppColors.primary
                              : Colors.grey,
                      size: AppSpacing.iconSize,
                    ),
                    value: _eventNotificationsEnabled,
                    onChanged: (value) async {
                      setState(() => _eventNotificationsEnabled = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('event_notifications_enabled', value);
                      if (value) {
                        await NotificationService.scheduleEventNotifications();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Event notifications enabled'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else {
                        await NotificationService.cancelEventNotifications();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Event notifications disabled'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      }
                    },
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // Usage Tracking Section
            Text(
              'Usage Limits',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child:
                  _loadingUsage
                      ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: ShimmerLoader(
                          height: 60,
                          width: double.infinity,
                        ),
                      )
                      : Column(
                        children: [
                          if (_isSubscribed)
                            Container(
                              padding: EdgeInsets.all(AppSpacing.sm),
                              margin: EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(
                                  (0.1 * 255).toInt(),
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius,
                                ),
                                border: Border.all(
                                  color: AppColors.success.withAlpha(
                                    (0.3 * 255).toInt(),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                    size: 20,
                                  ),
                                  SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(
                                      'Unlimited access with subscription',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: AppColors.success,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ListTile(
                            leading: Icon(
                              Icons.translate,
                              color: AppColors.secondary,
                              size: AppSpacing.iconSize,
                            ),
                            title: Text(
                              'Translations Used',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _isSubscribed
                                  ? 'Unlimited'
                                  : '${_usageStats['translations']} /  ${UsageService.translationLimit}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    _isSubscribed
                                        ? AppColors.success
                                        : (_usageStats['translations']! >=
                                                UsageService.translationLimit
                                            ? AppColors.error
                                            : AppColors.primary),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing:
                                _isSubscribed
                                    ? Icon(
                                      Icons.all_inclusive,
                                      color: AppColors.success,
                                      size: 20,
                                    )
                                    : (_usageStats['translations']! >=
                                            UsageService.translationLimit
                                        ? Icon(
                                          Icons.block,
                                          color: AppColors.error,
                                          size: 20,
                                        )
                                        : Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                          size: 20,
                                        )),
                          ),
                          Divider(
                            height: 0,
                            color: AppColors.border,
                            indent: AppSpacing.lg,
                            endIndent: AppSpacing.lg,
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.image,
                              color: AppColors.secondary,
                              size: AppSpacing.iconSize,
                            ),
                            title: Text(
                              'Images Generated',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _isSubscribed
                                  ? 'Unlimited'
                                  : '${_usageStats['images']} /  ${UsageService.imageLimit}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    _isSubscribed
                                        ? AppColors.success
                                        : (_usageStats['images']! >=
                                                UsageService.imageLimit
                                            ? AppColors.error
                                            : AppColors.primary),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing:
                                _isSubscribed
                                    ? Icon(
                                      Icons.all_inclusive,
                                      color: AppColors.success,
                                      size: 20,
                                    )
                                    : (_usageStats['images']! >=
                                            UsageService.imageLimit
                                        ? Icon(
                                          Icons.block,
                                          color: AppColors.error,
                                          size: 20,
                                        )
                                        : Icon(
                                          Icons.check_circle,
                                          color: AppColors.success,
                                          size: 20,
                                        )),
                          ),
                          if (!_isSubscribed)
                            Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Text(
                                'Subscribe for unlimited access to translations and image generation. Limits are permanent until you subscribe.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
            ),
            SizedBox(height: AppSpacing.xl),

            // Go Premium Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: ListTile(
                leading: Icon(
                  _isSubscribed ? Icons.all_inclusive : Icons.workspace_premium,
                  color: _isSubscribed ? AppColors.success : AppColors.primary,
                  size: AppSpacing.iconSize,
                ),
                title: Text(
                  _isSubscribed ? 'Premium: Unlimited' : 'Go Premium',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _isSubscribed
                      ? 'You have unlimited access.'
                      : 'Unlock unlimited translations and images. Subscription renews monthly.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        _isSubscribed ? AppColors.success : AppColors.primary,
                  ),
                ),
                trailing:
                    _isSubscribed
                        ? null
                        : Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: AppColors.primary,
                        ),
                onTap:
                    _isSubscribed
                        ? null
                        : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProfileScreen()),
                          );
                        },
              ),
            ),
            SizedBox(height: AppSpacing.xl),

            // App Info & Support Section
            Text(
              'App Info & Support',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.privacy_tip,
                      color: AppColors.secondary,
                      size: AppSpacing.iconSize,
                    ),
                    title: Text(
                      'Privacy Policy',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    onTap: _openPrivacyPolicy,
                  ),
                  Divider(
                    height: 0,
                    color: AppColors.border,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.article,
                      color: AppColors.secondary,
                      size: AppSpacing.iconSize,
                    ),
                    title: Text(
                      'Terms of Use',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    onTap: _openTermsOfUse,
                  ),
                  Divider(
                    height: 0,
                    color: AppColors.border,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.mail_outline,
                      color: AppColors.secondary,
                      size: AppSpacing.iconSize,
                    ),
                    title: Text(
                      'Make Suggestions',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(
                    height: 0,
                    color: AppColors.border,
                    indent: AppSpacing.lg,
                    endIndent: AppSpacing.lg,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.email,
                      color: AppColors.secondary,
                      size: AppSpacing.iconSize,
                    ),
                    title: Text(
                      'Contact Support',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.secondary,
                      size: 16,
                    ),
                    onTap: _contactSupport,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
