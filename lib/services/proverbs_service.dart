import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ProverbsService {
  static String proverbsUrl =
      '${dotenv.env['JSON_URL']}igbo-proverbs/main/proverbs.json';

  Future<List<Map<String, String>>> fetchProverbs() async {
    final response = await http.get(Uri.parse(proverbsUrl));
    if (response.statusCode == 200) {
      // print(response.body);
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map<Map<String, String>>((e) => Map<String, String>.from(e))
          .toList();
    } else {
      throw Exception('Failed to load proverbs');
    }
  }

  /// Returns the proverb of the day, matching the old logic
  Future<Map<String, String>> fetchProverbOfTheDay() async {
    final proverbs = await fetchProverbs();
    final todayIndex =
        DateTime.now().difference(DateTime(2024, 1, 1)).inDays %
        proverbs.length;
    return proverbs[todayIndex];
  }
}
