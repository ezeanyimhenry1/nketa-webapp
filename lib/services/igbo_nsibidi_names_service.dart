import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/models/translation_result.dart';
import 'package:nketa/services/json_content_loader.dart';
import 'package:diacritic/diacritic.dart';

class IgboNsibidiNamesService {
  static String resultsUrl =
      '${dotenv.env['JSON_URL']}igbonsibidi-names/main/dictionary.json';

  static const String _assetPath = 'assets/data/dictionary.json';

  static List<TranslationResult>? _cachedNames;

  /// Normalize Igbo text: remove diacritics, spaces, and lowercase
  static String normalizeIgbo(String input) {
    final noDiacritics = removeDiacritics(input.toLowerCase());
    return noDiacritics.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
  }

  /// Fetch and cache the names list
  Future<List<TranslationResult>> fetchNamesList() async {
    if (_cachedNames != null) return _cachedNames!;
    final body = await JsonContentLoader.load(
      remoteUrl: resultsUrl,
      assetPath: _assetPath,
    );
    final List<dynamic> data = jsonDecode(body);
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
    final names = await fetchNamesList();
    names.shuffle();
    return names;
  }
}
