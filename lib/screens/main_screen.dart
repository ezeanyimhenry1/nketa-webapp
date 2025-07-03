import 'package:flutter/material.dart';
import 'package:the_igbo_bible/screens/calendar_screen.dart';
import 'package:the_igbo_bible/screens/learn_screen.dart';
import 'package:the_igbo_bible/screens/translate_screen.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:the_igbo_bible/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/screens/saved_words_screen.dart';
import 'package:the_igbo_bible/screens/browse_screen.dart';
import 'package:the_igbo_bible/screens/settings_screen.dart';
import 'package:the_igbo_bible/screens/profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
                          const url = 'https://theigbobible.netlify.app';
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
