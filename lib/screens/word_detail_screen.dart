import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/widgets/custom_container.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:the_igbo_bible/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/services/saved_words_service.dart';
import 'package:the_igbo_bible/services/translation_service.dart';

class WordDetailScreen extends StatefulWidget {
  final TranslationResult word;

  const WordDetailScreen({required this.word, super.key});

  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  bool _isSaved = false;
  final _savedWordsService = SavedWordsService();

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _savedWordsService.isWordSaved(widget.word);
    setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _savedWordsService.removeWord(widget.word);
      setState(() => _isSaved = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed from saved words')));
    } else {
      await _savedWordsService.saveWord(widget.word);
      setState(() => _isSaved = true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final player = AudioPlayer();
    final hasAudio =
        widget.word.audioUrl != null && widget.word.audioUrl!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.word.igboWord, style: textTheme.titleMedium),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.star : Icons.star_border),
            tooltip: _isSaved ? 'Unsave' : 'Save',
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg.w),
        child: CustomContainer(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.word.nsibidi != null &&
                  widget.word.nsibidi!.isNotEmpty)
                Center(
                  child: Text(
                    widget.word.nsibidi!,
                    style: textTheme.displayLarge?.copyWith(
                      fontSize: 72.sp,
                      fontFamily: 'Akagu',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: AppSpacing.lg.h),
              Center(
                child: Text(
                  widget.word.igboWord,
                  style: textTheme.headlineMedium,
                ),
              ),
              SizedBox(height: AppSpacing.md.h),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.volume_up, size: AppSpacing.iconSize.sp),
                    onPressed:
                        hasAudio
                            ? () async {
                              await player.play(
                                UrlSource(widget.word.audioUrl!),
                              );
                            }
                            : null,
                    tooltip: AppStrings.playPronunciation,
                    color: hasAudio ? theme.colorScheme.primary : Colors.grey,
                  ),
                  Text(
                    AppStrings.playPronunciation,
                    style: textTheme.bodyMedium?.copyWith(
                      color: hasAudio ? theme.colorScheme.primary : Colors.grey,
                    ),
                  ),
                  if (!hasAudio)
                    Padding(
                      padding: EdgeInsets.only(left: AppSpacing.sm.w),
                      child: Text(
                        '(unavailable)',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.red,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                ],
              ),
              Divider(height: AppSpacing.lg.h * 1.2),
              if (widget.word.definitions.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.definitions, style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    ...widget.word.definitions.map(
                      (def) => Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.md.w,
                          bottom: AppSpacing.xs.h,
                        ),
                        child: Text(
                          '• ${def.definitions.join('; ')}',
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ],
                ),
              if (widget.word.tenses != null && widget.word.tenses!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),
                    Text(AppStrings.tenses, style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    ...widget.word.tenses!.entries
                        .where(
                          (entry) =>
                              entry.value != null && entry.value!.isNotEmpty,
                        )
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.md.w,
                              bottom: AppSpacing.xs.h,
                            ),
                            child: Text(
                              '${entry.key}: ${entry.value}',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ),
                  ],
                ),
              if (widget.word.attributes != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),
                    Text(AppStrings.attributes, style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    Wrap(
                      spacing: AppSpacing.sm.w,
                      runSpacing: AppSpacing.xs.h,
                      children: [
                        if (widget.word.attributes!.isStandardIgbo)
                          Chip(
                            label: Text(
                              'Standard Igbo',
                              style: textTheme.labelLarge,
                            ),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isAccented)
                          Chip(
                            label: Text(
                              'Accented',
                              style: textTheme.labelLarge,
                            ),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isSlang)
                          Chip(
                            label: Text('Slang', style: textTheme.labelLarge),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isBorrowedTerm)
                          Chip(
                            label: Text(
                              'Borrowed',
                              style: textTheme.labelLarge,
                            ),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isConstructedTerm)
                          Chip(
                            label: Text(
                              'Constructed',
                              style: textTheme.labelLarge,
                            ),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isStem)
                          Chip(
                            label: Text('Stem', style: textTheme.labelLarge),
                            backgroundColor: Colors.green[100],
                          ),
                        if (widget.word.attributes!.isCommon)
                          Chip(
                            label: Text('Common', style: textTheme.labelLarge),
                            backgroundColor: Colors.green[100],
                          ),
                      ],
                    ),
                  ],
                ),
              if (widget.word.tags?.isNotEmpty == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),
                    Text(AppStrings.tags, style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    Wrap(
                      spacing: AppSpacing.xs.w,
                      children:
                          widget.word.tags!
                              .map(
                                (tag) => Chip(
                                  label: Text(tag, style: textTheme.labelLarge),
                                  backgroundColor: Colors.green[100],
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
              if (widget.word.relatedTerms?.isNotEmpty == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),
                    Text(AppStrings.relatedTerms, style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    FutureBuilder<List<TranslationResult?>>(
                      future: Future.wait(
                        widget.word.relatedTerms!.map(
                          (id) => TranslationService().fetchWordById(id),
                        ),
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Padding(
                            padding: EdgeInsets.only(
                              left: AppSpacing.md.w,
                              bottom: AppSpacing.xs.h,
                            ),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final terms = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              terms
                                  .where((term) => term != null)
                                  .map(
                                    (term) => Padding(
                                      padding: EdgeInsets.only(
                                        left: AppSpacing.md.w,
                                        bottom: AppSpacing.xs.h,
                                      ),
                                      child: Text(
                                        '• ${term!.igboWord} (${term.definitions.expand((def) => def.definitions).join(', ')})',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    ),
                  ],
                ),
              if (widget.word.examples?.isNotEmpty == true)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: AppSpacing.md.h),
                    Text('Examples', style: textTheme.titleMedium),
                    SizedBox(height: AppSpacing.xs.h),
                    ...widget.word.examples!.map(
                      (ex) => Padding(
                        padding: EdgeInsets.only(
                          left: AppSpacing.md.w,
                          bottom: AppSpacing.xs.h,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Igbo: ${ex.igbo}',
                              style: textTheme.bodyMedium,
                            ),
                            Text(
                              'English: ${ex.english}',
                              style: textTheme.bodySmall,
                            ),
                            if (ex.pronunciation != null &&
                                ex.pronunciation!.isNotEmpty)
                              Text(
                                'Pronunciation: ${ex.pronunciation}',
                                style: textTheme.bodySmall,
                              ),
                            if (ex.nsibidi != null && ex.nsibidi!.isNotEmpty)
                              Text(
                                'Nsibidi: ${ex.nsibidi}',
                                style: textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
