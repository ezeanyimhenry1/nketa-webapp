import 'dart:convert';
import 'package:nketa/services/app_env.dart';
import 'package:nketa/services/json_content_loader.dart';
import '../models/igbo_event.dart';

class EventService {
  static String get eventsUrl =>
      AppEnv.jsonFile('igbo-events/main/events.json');

  static const String _assetPath = 'assets/data/events.json';

  Future<List<IgboEvent>> loadEvents() async {
    final body = await JsonContentLoader.load(
      remoteUrl: eventsUrl,
      assetPath: _assetPath,
    );
    final List<dynamic> data = jsonDecode(body);
    return data.map((e) => IgboEvent.fromJson(e)).toList();
  }
}
