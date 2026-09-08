import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/models/story_item.dart';
import 'package:nketa/services/json_content_loader.dart';

class StoryService {
  static String storiesUrl =
      '${dotenv.env['JSON_URL']}igbo-history/main/stories.json';

  static const String _assetPath = 'assets/data/stories.json';

  Future<List<StoryItem>> fetchStories() async {
    try {
      final body = await JsonContentLoader.load(
        remoteUrl: storiesUrl,
        assetPath: _assetPath,
      );
      final List<dynamic> data = json.decode(body);
      return data.map((e) => StoryItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }
}
