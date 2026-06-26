import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:nketa/models/translation_result.dart';
import 'package:nketa/services/api_service.dart';

class TranslationService extends ApiService {
  TranslationService()
    : super(
        baseUrl: dotenv.env['IGBO_API_BASE_URL'] ?? '',
        defaultHeaders: {
          'X-API-Key': dotenv.env['IGBO_API_KEY'] ?? '',
          'Accept': 'application/json',
        },
      );

  /// Translate an English word to Igbo using IgboAPI
  Future<String?> translateToIgbo(String englishWord) async {
    try {
      final result = await get(
        '/words',
        queryParams: {
          'keyword': englishWord,
          'strict': 'false', // allows more flexible matching
        },
      );

      if (result is List && result.isNotEmpty) {
        final igboWord = result[0]['word'];
        return igboWord;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Translation failed: $e');
      return null;
    }
  }

  Future<List<TranslationResult>> translate(
    String word, {
    String? wordClass,
  }) async {
    final queryParams = {
      'keyword': word,
      'strict': 'false',
      if (wordClass != null && wordClass.isNotEmpty) 'wordClass': wordClass,
    };
    final result = await get('/words', queryParams: queryParams);

    if (result == null || result['data'] == null) return [];

    final dataList = result['data'] as List<dynamic>;
    return dataList
        .map((item) => TranslationResult.fromJson(item))
        .where((tr) => tr.igboWord.isNotEmpty)
        .toList();
  }

  Future<List<TranslationResult>> fetchWords({
    String? keyword,
    int page = 1,
    int range = 25,
  }) async {
    final queryParameters = {
      'strict': 'false',
      if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
      'page': page.toString(),
      'range': range.toString(),
    };

    try {
      final result = await get('/words', queryParams: queryParameters);

      if (result == null || result['data'] == null) return [];

      final data = result['data'] as List<dynamic>;

      return data
          .map((jsonWord) => TranslationResult.fromJson(jsonWord))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch words: $e');
    }
  }

  Future<TranslationResult?> fetchWordById(String id) async {
    try {
      final result = await get('/words/$id');
      // print(result['data']);
      if (result != null && result['data'] != null) {
        return TranslationResult.fromJson(result['data']);
      }
      return null;
    } catch (e) {
      debugPrint('Failed to fetch word by id: $e');
      return null;
    }
  }
}
