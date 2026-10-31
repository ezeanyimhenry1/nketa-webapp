import 'package:flutter/foundation.dart';

/// Platform checks that compile on web (no dart:io).
class AppPlatform {
  AppPlatform._();

  static bool get isWeb => kIsWeb;

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static bool get isMobile => isAndroid || isIOS;

  static String get operatingSystem {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String get operatingSystemVersion =>
      kIsWeb ? 'Web' : defaultTargetPlatform.name;

  static String get localeName {
    final locale = PlatformDispatcher.instance.locale;
    final country = locale.countryCode;
    if (country == null || country.isEmpty) return locale.languageCode;
    return '${locale.languageCode}_$country';
  }
}
