import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nketa/models/translation_result.dart';

class SavedWordsService {
  static final SavedWordsService _instance = SavedWordsService._internal();
  factory SavedWordsService() => _instance;
  SavedWordsService._internal();

  static const String _key = 'saved_words';

  Future<List<TranslationResult>> getSavedWords() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    return saved
        .map((jsonStr) => TranslationResult.fromMap(json.decode(jsonStr)))
        .toList();
  }

  Future<void> saveWord(TranslationResult word) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    final wordJson = json.encode(word.toMap());
    if (!saved.contains(wordJson)) {
      saved.add(wordJson);
      await prefs.setStringList(_key, saved);
    }
  }

  Future<void> removeWord(TranslationResult word) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    saved.removeWhere((jsonStr) {
      final savedWord = TranslationResult.fromMap(json.decode(jsonStr));
      return savedWord.id == word.id;
    });
    await prefs.setStringList(_key, saved);
  }

  Future<bool> isWordSaved(TranslationResult word) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_key) ?? [];
    final wordJson = json.encode(word.toMap());
    return saved.contains(wordJson);
  }
}
