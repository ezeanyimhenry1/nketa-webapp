import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/igbo_event.dart';

class EventService {
  Future<List<IgboEvent>> loadEvents() async {
    final String jsonString = await rootBundle.loadString(
      'assets/data/igbo_events.json',
    );
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => IgboEvent.fromJson(e)).toList();
  }
}
