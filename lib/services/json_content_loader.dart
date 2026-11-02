import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class JsonContentLoader {
  static const Duration _timeout = Duration(seconds: 8);

  /// Loads JSON from [remoteUrl], falling back to a bundled [assetPath].
  /// HTML (or any non-JSON body) is treated as a miss so Netlify rewrites
  /// cannot hide the bundled file.
  static Future<String> load({
    required String remoteUrl,
    required String assetPath,
  }) async {
    try {
      final response = await http.get(Uri.parse(remoteUrl)).timeout(_timeout);
      final body = response.body.trim();
      if (response.statusCode == 200 && _looksLikeJson(body)) {
        return response.body;
      }
    } catch (_) {
      // Fall through to bundled asset.
    }
    return rootBundle.loadString(assetPath);
  }

  static bool _looksLikeJson(String body) {
    return body.startsWith('{') || body.startsWith('[');
  }
}
