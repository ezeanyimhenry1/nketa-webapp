import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nketa/screens/calendar_screen.dart';
import 'package:nketa/screens/learn_screen.dart';
import 'package:nketa/screens/translate_screen.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/theme/app_spacing.dart';
import 'package:nketa/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nketa/screens/saved_words_screen.dart';
import 'package:nketa/screens/browse_screen.dart';
import 'package:nketa/screens/settings_screen.dart';
import 'package:nketa/screens/profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nketa/screens/history_timeline_screen.dart';
import 'package:nketa/screens/cosmology_screen.dart';
import 'package:nketa/screens/content_hub_screen.dart';
import 'package:nketa/services/usage_service.dart';
import 'package:nketa/services/review_service.dart';
import 'package:nketa/screens/subscription_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSubscribed = false;
  final ReviewService _reviewService = ReviewService();

  @override
  void initState() {
    super.initState();
    _loadSubscriptionStatus();
    _checkForReviewPrompt();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      // UsageService is used in settings for subscription status
      final usageService = UsageService();
      final subscribed = await usageService.isSubscribed();
      if (mounted) {
        setState(() {
          _isSubscribed = subscribed;
        });
      }
    } catch (e) {
      // ignore error
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Track app usage for review prompt timing
    _reviewService.incrementAppUsage();

    // Check for review prompt after navigation (with a delay)
    Future.delayed(Duration(seconds: 2), () {
      _checkForReviewPrompt();
    });
  }

  Future<void> _checkForReviewPrompt() async {
    try {
      final shouldShow = await _reviewService.shouldShowReviewPrompt();
      if (shouldShow && mounted) {
        await _reviewService.showCustomReviewDialog(context);
      }
    } catch (e) {
      // Silently handle errors to avoid disrupting user experience
      debugPrint('Error checking for review prompt: $e');
    }
  }

  final List<Widget> _screens = [
    BrowseScreen(),
    CalendarScreen(),
    LearnScreen(),
    TranslateScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                children: [
                  DrawerHeader(
                    child: Row(
                      children: [
                        Text(
                          "\u904b ",
                          style: textTheme.headlineMedium!.copyWith(
                            fontFamily: 'Akagu',
                          ),
                        ),
                        Text(
                          AppStrings.appTitle,
                          style: textTheme.headlineMedium!.copyWith(
                            fontFamily: 'AguDisplay',
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.star,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text('Saved Words', style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SavedWordsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.timeline,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Igbo History Timeline',
                      style: textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryTimelineScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.auto_awesome,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text('Igbo Cosmology', style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CosmologyScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.menu_book,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Igbo Stories & Essays',
                      style: textTheme.bodyLarge,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ContentHubScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.settings,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text('Settings', style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen()),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.person,
                      size: AppSpacing.iconSize.sp,
                      color: AppColors.primary,
                    ),
                    title: Text('Profile', style: textTheme.bodyLarge),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen()),
                      );
                    },
                  ),
                  if (Platform.isIOS)
                    ListTile(
                      leading: Icon(
                        Icons.star,
                        size: AppSpacing.iconSize.sp,
                        color: Colors.amber,
                      ),
                      title: Text('Rate App', style: textTheme.bodyLarge),
                      onTap: () {
                        Navigator.pop(context);
                        _reviewService.requestReview();
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      _isSubscribed
                          ? Icons.all_inclusive
                          : Icons.workspace_premium,
                      size: AppSpacing.iconSize.sp,
                      color:
                          _isSubscribed ? AppColors.success : AppColors.primary,
                    ),
                    title: Text(
                      _isSubscribed ? 'Premium: Unlimited' : 'Go Premium',
                      style: textTheme.bodyLarge,
                    ),
                    subtitle:
                        _isSubscribed
                            ? Text(
                              'You have unlimited access.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                            )
                            : Text(
                              'Unlock unlimited translations and images.',
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                    onTap:
                        _isSubscribed
                            ? null
                            : () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubscriptionScreen(),
                                ),
                              );
                            },
                  ),
                ],
              ),
            ),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData ? snapshot.data!.version : '';
                return Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.lg.h, top: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: AssetImage('assets/icons/appicon.png'),
                        backgroundColor: Colors.transparent,
                      ),
                      SizedBox(height: 8),
                      Text('Version $version', style: textTheme.bodySmall),
                      SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // Replace with your app store URL
                          final url =
                              Platform.isAndroid
                                  ? 'https://drive.google.com/file/d/1NRwjGUIKJrFspVAH4CAawgnxDOcw6Fzt/view?usp=drive_link'
                                  : 'https://apps.apple.com/us/app/the-igbo-bible/id6748525748';
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: Icon(Icons.system_update),
                        label: Text('Check for Update'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          textStyle: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "運 ",
              style: textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontFamily: 'Akagu',
              ),
            ),
            Text(
              AppStrings.appTitle,
              style: textTheme.titleMedium!.copyWith(
                color: Colors.white,
                fontFamily: 'AguDisplay',
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.menu,
              color: Colors.white,
              size: AppSpacing.iconSize.sp,
            ),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      body: SafeArea(child: _screens[_selectedIndex]),
      bottomNavigationBar: Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withAlpha(20),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildNavItem(0, Icons.home, 'Home', textTheme),
            _buildNavItem(1, Icons.event_note, 'Calendar', textTheme),
            _buildNavItem(2, Icons.menu_book_rounded, 'Learn', textTheme),
            _buildNavItem(3, Icons.translate, 'Translate', textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    TextTheme textTheme,
  ) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Container(
          color: isSelected ? AppColors.primary.withAlpha(66) : Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.secondary,
                size: AppSpacing.iconSize.sp,
              ),
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
