import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/screens/word_detail_screen.dart';
import 'package:the_igbo_bible/services/translation_service.dart';
import 'package:the_igbo_bible/widgets/custom_container.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final TranslationService _translationService;

  List<TranslationResult> _words = [];
  bool _loading = false;
  bool _showAll = false;
  String _searchKeyword = '';

  final List<String> _randomKeywords = [
    'fire',
    'water',
    'family',
    'moon',
    'love',
    'God',
    'death',
    'life',
    'earth',
    'father',
    'tree',
    'bird',
    'wind',
    'woman',
    'cloud',
    'rain',
  ];

  @override
  void initState() {
    super.initState();

    _translationService = TranslationService();

    _loadInitialWords();
  }

  void _loadInitialWords() {
    final randomKeyword = (_randomKeywords..shuffle()).first;
    _searchController.text = randomKeyword;
    _fetchWords(keyword: randomKeyword);
  }

  Future<void> _fetchWords({String? keyword}) async {
    setState(() => _loading = true);

    try {
      final results = await _translationService.fetchWords(
        keyword: keyword,
        // page: 1,
        // range: 100,
      );

      // Filter only words with a non-empty nsibidi field
      final filteredResults =
          results.where((r) => r.nsibidi?.trim().isNotEmpty == true).toList();

      filteredResults.shuffle();

      setState(() {
        _words = filteredResults;
        _showAll = false;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      debugPrint('Error fetching words: $e');
    }
  }

  void _onSearch(String keyword) {
    _searchKeyword = keyword.trim();
    _fetchWords(keyword: _searchKeyword.isEmpty ? null : _searchKeyword);
  }

  void _onWordTap(TranslationResult word) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => WordDetailScreen(word: word)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final displayedWords = _showAll ? _words : _words.take(6).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        child: Column(
          children: [
            CustomContainer(
              content: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search symbols...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: AppSpacing.iconSize.sp,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                  ),
                ),
                onSubmitted: _onSearch,
                style: textTheme.bodyLarge,
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            if (_loading)
              Center(child: CircularProgressIndicator())
            else if (_words.isEmpty)
              Text(
                'No Nsibidi symbols found for "${_searchController.text}".',
                style: textTheme.bodyMedium,
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppSpacing.sm.w,
                mainAxisSpacing: AppSpacing.sm.h,
                children: [
                  ...displayedWords.map(
                    (word) => GestureDetector(
                      onTap: () => _onWordTap(word),
                      child: CustomContainer(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                word.nsibidi ?? '',
                                style: textTheme.displayLarge?.copyWith(
                                  fontSize: 42.sp,
                                  fontFamily: 'Akagu',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs.h),
                            Text(
                              word.igboWord,
                              style: textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppSpacing.xs.h),
                            if (word.definitions.isNotEmpty)
                              Flexible(
                                child: Text(
                                  word.definitions
                                      .expand((d) => d.definitions)
                                      .join('; '),
                                  style: textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            SizedBox(height: AppSpacing.xs.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: AppSpacing.md.h),
            CustomContainer(
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About NSIBIDI',
                    textAlign: TextAlign.left,
                    style: textTheme.titleMedium,
                  ),
                  Text(
                    'NSIBIDI is an ancient symbol system used by the Igbo, Efik, and other groups in southeastern Nigeria. These symbols represent concepts and ideas, serving as both writing and artistic expression.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
