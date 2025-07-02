import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/services/saved_words_service.dart';
import 'package:the_igbo_bible/screens/nsibidi_image_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:the_igbo_bible/data/proverbs.dart';
import 'package:the_igbo_bible/data/image_templates.dart';
import 'package:the_igbo_bible/models/image_template.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  // List<TranslationResult> _words = [];
  bool _loading = true;
  TranslationResult? _selectedWord;
  ImageTemplate? _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    final saved = await SavedWordsService().getSavedWords();
    final List<TranslationResult> randoms = [
      TranslationResult(
        igboWord: 'Chinonso',
        nsibidi: '魂帰鉱',
        definitions: [
          Definition(
            wordClass: null,
            definitions: ['God is nearby'],
            nsibidi: null,
          ),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: ['name'],
        relatedTerms: ['Chukwu', 'Onye'],
      ),
      TranslationResult(
        igboWord: 'Obinna',
        nsibidi: '心穏',
        definitions: [
          Definition(
            wordClass: null,
            definitions: ["Father's heart"],
            nsibidi: null,
          ),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: ['name'],
        relatedTerms: ['Nna', 'Obi'],
      ),
      TranslationResult(
        igboWord: 'Adaeze',
        nsibidi: '割王',
        definitions: [
          Definition(
            wordClass: null,
            definitions: ['daughter of a king', 'princess'],
            nsibidi: null,
          ),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: ['name'],
        relatedTerms: ['Ada', 'Eze'],
      ),
      TranslationResult(
        igboWord: 'Chukwu',
        nsibidi: '魂大',
        definitions: [
          Definition(
            wordClass: null,
            definitions: ['God exists'],
            nsibidi: null,
          ),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: ['name'],
        relatedTerms: ['Chi', 'Ukwu'],
      ),
      TranslationResult(
        igboWord: 'Uche',
        nsibidi: '虞',
        definitions: [
          Definition(
            wordClass: null,
            definitions: ['Thought, will'],
            nsibidi: null,
          ),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: [],
        relatedTerms: ['Obi', 'Mmụọ'],
      ),
      TranslationResult(
        igboWord: 'Nkem',
        nsibidi: '外花',
        definitions: [
          Definition(wordClass: null, definitions: ['Mine'], nsibidi: null),
        ],
        audioUrl: null,
        tenses: null,
        attributes: null,
        tags: [],
        relatedTerms: ['Nke', 'Mu'],
      ),
    ];
    final all = [...saved, ...randoms];
    all.shuffle();
    final word = all.isNotEmpty ? all.first : null;
    final List<ImageTemplate> browseImageTemplates =
        imageTemplates.where((t) => t.backgroundImageAsset != null).toList();
    browseImageTemplates.shuffle();
    final selectedTemplate =
        browseImageTemplates.isNotEmpty ? browseImageTemplates.first : null;
    setState(() {
      // _words = all;
      _selectedWord = word;
      _selectedTemplate = selectedTemplate;
      _loading = false;
    });
  }

  void _viewAsImage(TranslationResult word) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => NsibidiImagePage(
              nsibidiText: word.nsibidi ?? '',
              originalInput: word.igboWord,
              results: [word],
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    // Pick a proverb of the day based on date
    final todayIndex =
        DateTime.now().difference(DateTime(2024, 1, 1)).inDays %
        proverbs.length;
    final proverb = proverbs[todayIndex];
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: MasonryGridView.count(
        crossAxisCount: 1,
        mainAxisSpacing: AppSpacing.lg.h,
        crossAxisSpacing: AppSpacing.lg.w,
        itemCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          if (index == 0 &&
              _selectedWord != null &&
              _selectedTemplate != null) {
            // Word card
            return Container(
              decoration: BoxDecoration(
                gradient: _selectedTemplate!.gradient,
                image:
                    _selectedTemplate!.backgroundImageAsset != null
                        ? DecorationImage(
                          image: AssetImage(
                            _selectedTemplate!.backgroundImageAsset!,
                          ),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withAlpha((0.2 * 255).toInt()),
                            BlendMode.darken,
                          ),
                        )
                        : null,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _selectedWord!.igboWord,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: _selectedTemplate!.textColor,
                            fontSize: 36.sp,
                            fontFamily: 'AguDisplay',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedWord!.nsibidi != null &&
                          _selectedWord!.nsibidi!.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md.h,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _selectedWord!.nsibidi!,
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontSize: 48.sp,
                                fontFamily: 'Akagu',
                                color: _selectedTemplate!.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      if (_selectedWord!.definitions.isNotEmpty)
                        Text(
                          _selectedWord!.definitions.isNotEmpty &&
                                  _selectedWord!
                                      .definitions
                                      .first
                                      .definitions
                                      .isNotEmpty
                              ? _selectedWord!
                                  .definitions
                                  .first
                                  .definitions
                                  .first
                              : '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _selectedTemplate!.textColor,
                            fontSize: 16.sp,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      SizedBox(height: AppSpacing.lg.h),
                      ElevatedButton.icon(
                        onPressed: () => _viewAsImage(_selectedWord!),
                        icon: const Icon(Icons.image),
                        label: const Text('View as Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedTemplate!.accentColor,
                          foregroundColor: _selectedTemplate!.textColor,
                          padding: EdgeInsets.symmetric(
                            vertical: AppSpacing.sm.h,
                            horizontal: AppSpacing.md.w,
                          ),
                          textStyle: Theme.of(
                            context,
                          ).textTheme.labelSmall!.copyWith(fontSize: 14.sp),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else if (index == 1) {
            // Proverb card
            return Container(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Proverb",
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.orange[900],
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(proverb['igbo']!, style: theme.textTheme.bodyLarge),
                  SizedBox(height: AppSpacing.sm.h),
                  Text(
                    proverb['english']!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
