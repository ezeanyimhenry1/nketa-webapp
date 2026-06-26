import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nketa/models/story_item.dart';

class StoryService {
  // Replace with your actual GitHub raw URL
  static String storiesUrl =
      '${dotenv.env['JSON_URL']}igbo-history/main/stories.json';

  Future<List<StoryItem>> fetchStories() async {
    try {
      final response = await http.get(Uri.parse(storiesUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => StoryItem.fromJson(e)).toList();
      } else {
        throw Exception('Failed to load stories');
      }
    } catch (e) {
      // Return empty list on error
      return [];
    }
  }
}
