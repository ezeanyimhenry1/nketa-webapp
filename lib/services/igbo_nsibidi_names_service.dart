import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:the_igbo_bible/models/translation_result.dart';

class IgboNsibidiNamesService {
  static String resultsUrl =
      '${dotenv.env['JSON_URL']}igbonsibidi-names/main/dictionary.json';

  Future<List<TranslationResult>> fetchRandomResults() async {
    final response = await http.get(Uri.parse(resultsUrl));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final List<Map<String, dynamic>> mapped =
          data.map((e) {
            final map = Map<String, dynamic>.from(e);
            if (map['igboWord'] != null) {
              map['word'] = map['igboWord'];
            }
            if (map['nsibidi'] != null &&
                map['definitions'] is List &&
                map['definitions'].isNotEmpty) {
              final def = Map<String, dynamic>.from(map['definitions'][0]);
              if (def['nsibidi'] == null ||
                  (def['nsibidi'] as String?)?.isEmpty != false) {
                def['nsibidi'] = map['nsibidi'];
                map['definitions'][0] = def;
              }
            }
            return map;
          }).toList();
      return mapped.map((e) => TranslationResult.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load random results');
    }
  }
}
