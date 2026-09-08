import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class JsonContentLoader {
  static const Duration _timeout = Duration(seconds: 8);

  /// Loads JSON from [remoteUrl], falling back to a bundled [assetPath].
  static Future<String> load({
    required String remoteUrl,
    required String assetPath,
  }) async {
    try {
      final response = await http.get(Uri.parse(remoteUrl)).timeout(_timeout);
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body;
      }
    } catch (_) {
      // Fall through to bundled asset.
    }
    return rootBundle.loadString(assetPath);
  }
}
