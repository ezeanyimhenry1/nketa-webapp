import 'dart:convert';
import 'package:nketa/services/app_env.dart';
import 'package:nketa/services/json_content_loader.dart';

class HistoryTimelineService {
  static String get timelineUrl =>
      AppEnv.jsonFile('igbo-history/main/timeline.json');

  static const String _assetPath = 'assets/data/timeline.json';

  Future<List<Map<String, dynamic>>> fetchTimeline() async {
    final body = await JsonContentLoader.load(
      remoteUrl: timelineUrl,
      assetPath: _assetPath,
    );
    final List<dynamic> data = jsonDecode(body);
    return data
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
