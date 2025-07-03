import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/services/saved_words_service.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:the_igbo_bible/data/image_templates.dart';
import 'package:the_igbo_bible/screens/word_detail_screen.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Saved Words')),
      body:
          _loading
              ? const Center(child: ShimmerLoader(height: 32, width: 32))
              : _savedWords.isEmpty
              ? Center(child: Text('No saved words yet.'))
              : Padding(
                padding: EdgeInsets.all(16.0),
                child: MasonryGridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  itemCount: _savedWords.length,
                  itemBuilder: (context, index) {
                    final word = _savedWords[index];
                    final template =
                        imageTemplates[index % imageTemplates.length];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WordDetailScreen(word: word),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: template.gradient,
                          image:
                              template.backgroundImageAsset != null
                                  ? DecorationImage(
                                    image: AssetImage(
                                      template.backgroundImageAsset!,
                                    ),
                                    fit: BoxFit.cover,
                                    colorFilter: ColorFilter.mode(
                                      Colors.black.withAlpha(
                                        (0.2 * 255).toInt(),
                                      ),
                                      BlendMode.darken,
                                    ),
                                  )
                                  : null,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Card(
                          color: Colors.transparent,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  word.igboWord,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: template.textColor,
                                  ),
                                ),
                                if (word.nsibidi != null &&
                                    word.nsibidi!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      word.nsibidi!,
                                      style: theme.textTheme.displayLarge
                                          ?.copyWith(
                                            fontFamily: 'Akagu',
                                            fontSize: 32,
                                            color: template.textColor,
                                          ),
                                    ),
                                  ),
                                if (word.definitions.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      word
                                              .definitions
                                              .first
                                              .definitions
                                              .isNotEmpty
                                          ? word
                                              .definitions
                                              .first
                                              .definitions
                                              .first
                                          : '',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: template.textColor),
                                    ),
                                  ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color: template.textColor,
                                    ),
                                    onPressed: () => _removeWord(word),
                                    tooltip: 'Remove',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
