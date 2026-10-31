import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Web TTS cache is in-memory only; browsers play remote URLs directly.
class VoiceAudioCacheService {
  static final Map<String, String> _memory = {};

  static String cacheKey({
    required String text,
    required String language,
    required String accent,
    required String gender,
  }) {
    final payload = '$text|$language|$accent|$gender';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static Future<String?> getCachedPath(String key, {String ext = 'opus'}) async =>
      _memory[key];

  static Future<String?> resolveAudioPath({
    required String text,
    required String language,
    required String accent,
    required String gender,
    String? remoteUrl,
    String ext = 'opus',
  }) async {
    final key = cacheKey(
      text: text,
      language: language,
      accent: accent,
      gender: gender,
    );
    final cached = _memory[key];
    if (cached != null) return cached;
    if (remoteUrl == null || remoteUrl.isEmpty) return null;
    _memory[key] = remoteUrl;
    return remoteUrl;
  }

  static Future<void> clearCache() async {
    _memory.clear();
  }
}
