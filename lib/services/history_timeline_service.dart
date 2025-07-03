import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HistoryTimelineService {
  static String timelineUrl =
      '${dotenv.env['JSON_URL']}igbo-history/main/timeline.json';

  Future<List<Map<String, dynamic>>> fetchTimeline() async {
    final response = await http.get(Uri.parse(timelineUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .toList();
    } else {
      throw Exception('Failed to load Igbo history timeline');
    }
  }
}
