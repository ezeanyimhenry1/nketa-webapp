import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// HTTPS proxy for secrets that must not ship in the web JS bundle.
class WebBackend {
  WebBackend._();

  static String get baseUrl {
    final raw = dotenv.env['WEB_API_BASE_URL'] ??
        'https://us-central1-the-igbo-bible.cloudfunctions.net';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  static bool get isEnabled => kIsWeb;

  static Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    return http
        .post(uri, headers: await _headers(), body: jsonEncode(body ?? {}))
        .timeout(const Duration(seconds: 130));
  }

  static Future<http.Response> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    return http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 60));
  }

  static dynamic decode(http.Response response) {
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}
