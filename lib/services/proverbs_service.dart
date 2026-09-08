import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/services/json_content_loader.dart';

class ProverbsService {
  static String proverbsUrl =
      '${dotenv.env['JSON_URL']}igbo-proverbs/main/proverbs.json';

  static const String _assetPath = 'assets/data/proverbs.json';

  Future<List<Map<String, String>>> fetchProverbs() async {
    final body = await JsonContentLoader.load(
      remoteUrl: proverbsUrl,
      assetPath: _assetPath,
    );
    final List<dynamic> data = jsonDecode(body);
    return data.map<Map<String, String>>((e) => Map<String, String>.from(e)).toList();
  }

  /// Returns the proverb of the day, matching the old logic
  Future<Map<String, String>> fetchProverbOfTheDay() async {
    final proverbs = await fetchProverbs();
    if (proverbs.isEmpty) {
      return {
        'igbo': 'Proverb of the Day',
        'english': 'Tap to see today\'s wisdom',
      };
    }
    final todayIndex =
        DateTime.now().difference(DateTime(2024, 1, 1)).inDays %
        proverbs.length;
    return proverbs[todayIndex];
  }
}
