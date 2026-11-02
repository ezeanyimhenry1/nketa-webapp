import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Reads public runtime config without throwing when dotenv is missing.
class AppEnv {
  static const String jsonUrlDefault =
      'https://raw.githubusercontent.com/ezeanyimhenry1/';

  static String? get(String key) {
    if (!dotenv.isInitialized) return null;
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String jsonUrl() {
    final raw = get('JSON_URL') ?? jsonUrlDefault;
    return raw.endsWith('/') ? raw : '$raw/';
  }

  static String jsonFile(String path) {
    final trimmed = path.startsWith('/') ? path.substring(1) : path;
    return '${jsonUrl()}$trimmed';
  }
}
