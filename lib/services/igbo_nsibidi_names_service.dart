import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:the_igbo_bible/models/translation_result.dart';

class IgboNsibidiNamesService {
  static String resultsUrl =
      '${dotenv.env['JSON_URL']}igbonsibidi-names/main/dictionary.json';
  static List<TranslationResult>? _cachedNames;

  /// Normalize Igbo text: remove diacritics, spaces, and lowercase
  static String normalizeIgbo(String input) {
    // Remove diacritics using Unicode normalization
    final normalized = input
        .toLowerCase()
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '') // Remove combining marks
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''); // Remove non-alphanum
    // Remove spaces
    return normalized.replaceAll(' ', '');
  }

  /// Fetch and cache the names list
  Future<List<TranslationResult>> fetchNamesList() async {
    if (_cachedNames != null) return _cachedNames!;
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
      _cachedNames = mapped.map((e) => TranslationResult.fromJson(e)).toList();
      return _cachedNames!;
    } else {
      throw Exception('Failed to load names list');
    }
  }

  /// Fuzzy search for a name in the list
  Future<TranslationResult?> findName(String input) async {
    final names = await fetchNamesList();
    final normalizedInput = normalizeIgbo(input);
    for (final name in names) {
      final normalizedName = normalizeIgbo(name.igboWord);
      if (normalizedInput == normalizedName) {
        return name;
      }
    }
    // Try partial match (for cases like extra spaces or diacritics)
    for (final name in names) {
      final normalizedName = normalizeIgbo(name.igboWord);
      if (normalizedInput.contains(normalizedName) ||
          normalizedName.contains(normalizedInput)) {
        return name;
      }
    }
    return null;
  }

  /// Fetch random results (for browse screen compatibility)
  Future<List<TranslationResult>> fetchRandomResults() async {
    // This just calls fetchNamesList and shuffles the result
    final names = await fetchNamesList();
    names.shuffle();
    return names;
  }
}
