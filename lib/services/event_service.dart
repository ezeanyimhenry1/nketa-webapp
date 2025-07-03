import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/igbo_event.dart';

class EventService {
  static String eventsUrl =
      '${dotenv.env['JSON_URL']}igbo-events/main/events.json';

  Future<List<IgboEvent>> loadEvents() async {
    final response = await http.get(Uri.parse(eventsUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => IgboEvent.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load events');
    }
  }
}
