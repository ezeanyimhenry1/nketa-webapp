import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/services/saved_words_service.dart';

class SavedWordsScreen extends StatefulWidget {
  const SavedWordsScreen({super.key});

  @override
  State<SavedWordsScreen> createState() => _SavedWordsScreenState();
}

class _SavedWordsScreenState extends State<SavedWordsScreen> {
  List<TranslationResult> _savedWords = [];
  bool _loading = true;
  final _service = SavedWordsService();

  @override
  void initState() {
    super.initState();
    _loadSavedWords();
  }

  Future<void> _loadSavedWords() async {
    setState(() => _loading = true);
    final words = await _service.getSavedWords();
    setState(() {
      _savedWords = words;
      _loading = false;
    });
  }

  Future<void> _removeWord(TranslationResult word) async {
    await _service.removeWord(word);
    await _loadSavedWords();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Removed from saved words')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Saved Words')),
      body:
          _loading
              ? Center(child: CircularProgressIndicator())
              : _savedWords.isEmpty
              ? Center(child: Text('No saved words yet.'))
              : ListView.builder(
                itemCount: _savedWords.length,
                itemBuilder: (context, index) {
                  final word = _savedWords[index];
                  return ListTile(
                    title: Text(word.igboWord),
                    subtitle:
                        word.nsibidi != null && word.nsibidi!.isNotEmpty
                            ? Text(word.nsibidi!)
                            : null,
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeWord(word),
                      tooltip: 'Remove',
                    ),
                  );
                },
              ),
    );
  }
}
