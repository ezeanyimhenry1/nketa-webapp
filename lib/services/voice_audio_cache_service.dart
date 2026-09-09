import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Disk cache for TTS audio keyed by text + voice settings.
class VoiceAudioCacheService {
  static const String _cacheDirName = 'intron_tts_cache';
  static Directory? _cacheDir;

  static Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${base.path}/$_cacheDirName');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  static String cacheKey({
    required String text,
    required String language,
    required String accent,
    required String gender,
  }) {
    final payload = '$text|$language|$accent|$gender';
    return sha256.convert(utf8.encode(payload)).toString();
  }

  static Future<File?> getCachedFile(String key, {String ext = 'opus'}) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/$key.$ext');
    if (await file.exists() && await file.length() > 0) {
      return file;
    }
    return null;
  }

  static Future<File> saveBytes(String key, List<int> bytes, {String ext = 'opus'}) async {
    final dir = await _getCacheDir();
    final file = File('${dir.path}/$key.$ext');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Returns a local file path — from cache or by downloading [remoteUrl].
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
    final cached = await getCachedFile(key, ext: ext);
    if (cached != null) return cached.path;

    if (remoteUrl == null || remoteUrl.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(remoteUrl));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final file = await saveBytes(key, response.bodyBytes, ext: ext);
        return file.path;
      }
    } catch (e) {
      debugPrint('VoiceAudioCacheService download failed: $e');
    }
    return null;
  }

  static Future<void> clearCache() async {
    final dir = await _getCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _cacheDir = null;
    }
  }
}
