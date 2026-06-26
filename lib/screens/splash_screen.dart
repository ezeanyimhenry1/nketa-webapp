import 'package:flutter/material.dart';
import 'package:nketa/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nketa/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary, AppColors.secondary],
          ),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "運 ",
                style: textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontFamily: 'Akagu',
                  fontSize: 40.sp,
                ),
              ),
              Text(
                AppStrings.appTitle,
                style: textTheme.titleMedium!.copyWith(
                  color: Colors.white,
                  fontFamily: 'AguDisplay',
                  fontSize: 32.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
