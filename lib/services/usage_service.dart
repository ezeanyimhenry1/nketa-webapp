import 'package:shared_preferences/shared_preferences.dart';

class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const int translationLimit = 3;
  static const int imageLimit = 5;

  Future<bool> isSubscribed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_subscribed') ?? false;
  }

  Future<Map<String, int>> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'translations': prefs.getInt('translations_used') ?? 0,
      'images': prefs.getInt('images_used') ?? 0,
    };
  }

  Future<bool> canUseTranslation() async {
    if (await isSubscribed()) return true;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('translations_used') ?? 0) < translationLimit;
  }

  Future<bool> canUseImage() async {
    if (await isSubscribed()) return true;
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('images_used') ?? 0) < imageLimit;
  }

  Future<void> incrementTranslation() async {
    final prefs = await SharedPreferences.getInstance();
    int used = prefs.getInt('translations_used') ?? 0;
    await prefs.setInt('translations_used', used + 1);
  }

  Future<void> incrementImage() async {
    final prefs = await SharedPreferences.getInstance();
    int used = prefs.getInt('images_used') ?? 0;
    await prefs.setInt('images_used', used + 1);
  }

  Future<void> resetDailyUsage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('translations_used', 0);
    await prefs.setInt('images_used', 0);
  }
}
