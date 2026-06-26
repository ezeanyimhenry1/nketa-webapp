import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nketa/models/translation_result.dart';
import 'package:nketa/services/network_status_provider.dart';
import 'package:nketa/services/translation_service.dart';
import 'package:nketa/services/openai_service.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/widgets/custom_container.dart';
import 'package:nketa/theme/app_spacing.dart';
import 'package:nketa/theme/app_strings.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nketa/screens/nsibidi_image_page.dart';
import 'package:nketa/services/saved_words_service.dart';
import 'package:nketa/services/usage_service.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:nketa/data/constants.dart';
import 'package:nketa/widgets/shimmer_loader.dart';
import 'package:nketa/services/igbo_nsibidi_names_service.dart';
import 'package:provider/provider.dart';
import 'package:nketa/screens/subscription_screen.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

// Helper structure for ambiguous word selection
class _WordSelection {
  final int index;
  final String word;
  final List<TranslationResult> options;
  _WordSelection(this.index, this.word, this.options);
}

// Helper structure for word + class
class WordWithClass {
  final String word;
  final String? wordClass;
  WordWithClass(this.word, this.wordClass);
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _loading = false;
  String? _errorMessage;
  List<TranslationResult> _results = [];
  List<String> _originalWords = [];
  bool _usedAI = false; // Track whether AI was used
  bool _usedNamesList = false; // Track if result came from names list

  final TranslationService _translationService = TranslationService();
  final OpenAIService _openAIService = OpenAIService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  Map<String, int> _usageStats = {'translations': 0, 'images': 0};
  bool _loadingUsage = true;
  bool _isSubscribed = false; // Track subscription status

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUsageStats();
  }

  void _onTextChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _handleTranslate() async {
    setState(() => _loading = true);
    final usageService = UsageService();
    if (!await usageService.canUseTranslation()) {
      _showSubscriptionDialog();
      return;
    }

    final inputText = _controller.text.trim();

    if (inputText.isEmpty) {
      _showError('Please enter some text to translate');
      return;
    }

    if (inputText.length > 500) {
      _showError('Text is too long. Maximum 500 characters allowed.');
      return;
    }

    // Dismiss keyboard
    _focusNode.unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _results = [];
      _originalWords = [];
    });

    await usageService.incrementTranslation();

    try {
      // 1. Check for known name in Nsibidi names list (fuzzy)
      final nsibidiNameService = IgboNsibidiNamesService();
      final foundName = await nsibidiNameService.findName(inputText);
      if (foundName != null) {
        setState(() {
          _results = [foundName];
          _originalWords = [foundName.igboWord];
          _loading = false;
          _usedAI = false;
          _usedNamesList = true;
        });
        _scrollToResults();
        return;
      }

      // Use OpenAI to break text into words and word classes
      final wordBreakdownPrompt = '''
Break "$inputText" into Igbo word components and their word classes using these codes: WH (wh-word), AV (adverb), NNC (common noun), etc.
Respond with JSON: [{"word": "onye", "class": "WH"}, ...]
''';

      final aiResponse = await _openAIService.generateTranslation(
        wordBreakdownPrompt,
      );

      if (aiResponse == null || aiResponse.isEmpty) {
        throw Exception('Unable to process the text. Please try again.');
      }

      // Parse the AI response to get individual words and classes
      final List<dynamic> parsedJson = jsonDecode(aiResponse);
      final List<WordWithClass> wordsWithClass =
          parsedJson.map((item) {
            final map = item as Map<String, dynamic>;
            return WordWithClass(
              map['word'] as String,
              map['class'] as String?,
            );
          }).toList();
      final words = wordsWithClass.map((w) => w.word).toList();

      if (words.isEmpty) {
        throw Exception('No words found to translate.');
      }

      // Store original words for reference
      _originalWords = words;

      // Fetch all possible translations for each word, using word class
      final allTranslationOptions = await _fetchAllTranslationOptions(
        wordsWithClass,
      );

      // Use AI to select the most contextually appropriate translations
      final contextAwareResults = await _selectContextAwareTranslations(
        inputText,
        words,
        allTranslationOptions,
      );

      setState(() {
        _results = contextAwareResults;
        _loading = false;
        _usedAI = true;
        _usedNamesList = false;
      });

      // Auto-scroll to results
      if (_results.isNotEmpty) {
        _scrollToResults();
      }
    } catch (e) {
      debugPrint("Translation error: $e");
      _showError(_getErrorMessage(e));
      setState(() => _loading = false);
    }
    await _loadUsageStats();
  }

  Future<List<List<TranslationResult>>> _fetchAllTranslationOptions(
    List<WordWithClass> wordsWithClass,
  ) async {
    List<List<TranslationResult>> allOptions = [];

    for (final wc in wordsWithClass) {
      try {
        final translations = await _translationService.translate(
          wc.word.trim(),
          wordClass: wc.wordClass,
        );
        allOptions.add(translations);
      } catch (e) {
        debugPrint("Error fetching translations for '${wc.word}': $e");
        allOptions.add([]); // Empty list for words that failed
      }
    }

    return allOptions;
  }

  Future<List<TranslationResult>> _selectContextAwareTranslations(
    String originalText,
    List<String> words,
    List<List<TranslationResult>> allOptions, {
    String? intendedMeaning,
  }) async {
    // 1. Use heuristics for unambiguous words, collect ambiguous ones
    List<TranslationResult?> results = List.filled(words.length, null);
    List<_WordSelection> ambiguous = [];
    final contextString = (intendedMeaning ?? originalText).toLowerCase();

    for (int i = 0; i < words.length; i++) {
      final options = allOptions[i];
      if (options.isEmpty) {
        results[i] = TranslationResult(
          id: 'result_${i}_${words[i]}',
          igboWord: words[i],
          nsibidi: null,
          definitions: [],
          audioUrl: null,
        );
        continue;
      }
      // Heuristic: if only one option, pick it
      if (options.length == 1) {
        results[i] = options.first;
        continue;
      }
      // 1. Use igboNameFragments for names
      final nameFragmentMatch =
          options.where((o) {
            final word = o.igboWord.toLowerCase();
            return igboNameFragments.any((frag) => word.contains(frag));
          }).toList();
      if (nameFragmentMatch.length == 1) {
        results[i] = nameFragmentMatch.first;
        continue;
      }
      // 2. Use context/intended meaning
      final contextMatch =
          options
              .where(
                (o) => o.definitions
                    .expand((d) => d.definitions)
                    .any((def) => contextString.contains(def.toLowerCase())),
              )
              .toList();
      if (contextMatch.length == 1) {
        results[i] = contextMatch.first;
        continue;
      }
      // 3. Use tags for spiritual/name/personal/common
      final tagsMatch =
          options.where((o) {
            final tags = o.tags?.join(',').toLowerCase() ?? '';
            return tags.contains('name') ||
                tags.contains('personal') ||
                tags.contains('common');
          }).toList();
      if (tagsMatch.length == 1) {
        results[i] = tagsMatch.first;
        continue;
      }
      // 4. Otherwise, ambiguous: send to AI
      ambiguous.add(_WordSelection(i, words[i], options.take(3).toList()));
    }

    // 2. If no ambiguous, return results (all heuristics)
    if (ambiguous.isEmpty) {
      setState(() => _usedAI = false);
      return results.cast<TranslationResult>();
    }

    // 3. Build minimal AI prompt for ambiguous words only
    final aiPrompt = _buildMinimalAmbiguityPrompt(
      originalText,
      ambiguous,
      intendedMeaning: intendedMeaning,
    );
    // debugPrint("Sending minimal ambiguity prompt to AI: $aiPrompt");
    final aiSelection = await _openAIService.generateTranslation(aiPrompt);
    if (aiSelection == null || aiSelection.isEmpty) {
      // debugPrint("AI returned null or empty response, using fallback");
      // Fallback: use first available translation for ambiguous
      for (final amb in ambiguous) {
        results[amb.index] = amb.options.first;
      }
      setState(() => _usedAI = false);
      return results.cast<TranslationResult>();
    }
    try {
      final Map<String, dynamic> selection = jsonDecode(aiSelection.trim());
      final List<dynamic> selectedIndices = selection['selected_indices'] ?? [];
      for (int j = 0; j < ambiguous.length; j++) {
        final amb = ambiguous[j];
        final idx =
            (j < selectedIndices.length && selectedIndices[j] is int)
                ? selectedIndices[j]
                : 0;
        results[amb.index] = amb.options[(idx < amb.options.length) ? idx : 0];
      }
      setState(() => _usedAI = true);
      return results.cast<TranslationResult>();
    } catch (e) {
      debugPrint("Error parsing AI selection: $e");
      // Fallback: use first available translation for ambiguous
      for (final amb in ambiguous) {
        results[amb.index] = amb.options.first;
      }
      setState(() => _usedAI = false);
      return results.cast<TranslationResult>();
    }
  }

  String _buildMinimalAmbiguityPrompt(
    String originalText,
    List<_WordSelection> ambiguous, {
    String? intendedMeaning,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Given the Igbo phrase: "$originalText".');
    if (intendedMeaning != null && intendedMeaning.isNotEmpty) {
      buffer.writeln('Intended meaning: "$intendedMeaning".');
    }
    buffer.writeln(
      'For each ambiguous word, select the best translation in context:',
    );
    for (int i = 0; i < ambiguous.length; i++) {
      final amb = ambiguous[i];
      buffer.writeln('${i + 1}. ${amb.word}:');
      for (int j = 0; j < amb.options.length; j++) {
        final option = amb.options[j];
        final tags = option.tags?.join(', ') ?? '';
        buffer.writeln(
          '   $j: "${option.igboWord}" - "${option.definitions.expand((d) => d.definitions).join(', ')}" (tags: $tags)',
        );
      }
    }
    buffer.writeln(
      'Respond with JSON: {"selected_indices": [index_for_word1, ...]}',
    );
    return buffer.toString();
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('api') || errorStr.contains('key')) {
      return 'Service temporarily unavailable. Please try again later.';
    } else {
      return 'Translation failed. Please try again.';
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    // Only show SnackBar for non-network errors
    if (Provider.of<NetworkStatusProvider>(
          context,
          listen: false,
        ).bannerMessage ==
        null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSubscriptionDialog() {
    setState(() {
      _loading = false;
    });

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Translation Limit Reached'),
            content: const Text(
              'You\'ve reached your free translation limit. Subscribe to get unlimited translations and access to all features.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                child: const Text('Subscribe'),
              ),
            ],
          ),
    );
  }

  void _scrollToResults() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _clearText() {
    _controller.clear();
    setState(() {
      _results = [];
      _originalWords = [];
      _errorMessage = null;
      _usedAI = false;
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _playAudio(String? audioUrl) async {
    if (audioUrl == null || audioUrl.isEmpty) {
      _showError('Audio not available for this word');
      return;
    }

    try {
      await _audioPlayer.play(UrlSource(audioUrl));
    } catch (e) {
      debugPrint("Audio playback error: $e");
      _showError('Unable to play audio');
    }
  }

  Future<void> _loadUsageStats() async {
    try {
      final usageService = UsageService();
      final stats = await usageService.getUsageStats();
      final subscribed = await usageService.isSubscribed();
      setState(() {
        _usageStats = stats;
        _isSubscribed = subscribed;
        _loadingUsage = false;
      });
    } catch (e) {
      debugPrint('Error loading usage stats: $e');
      setState(() => _loadingUsage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final networkStatus = Provider.of<NetworkStatusProvider>(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.lg.w),
              child: Column(
                children: [
                  CustomContainer(
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(textTheme),
                        SizedBox(height: AppSpacing.md.h),
                        _buildInputSection(textTheme),
                        SizedBox(height: AppSpacing.md.h),
                        _buildActionButtons(textTheme, networkStatus),
                        if (_errorMessage != null) ...[
                          SizedBox(height: AppSpacing.md.h),
                          _buildErrorCard(textTheme),
                        ],
                        if (_results.isNotEmpty) ...[
                          SizedBox(height: AppSpacing.lg.h),
                          _buildResultsSection(textTheme),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.translate,
              color: Theme.of(context).colorScheme.primary,
              size: AppSpacing.iconSize.sp,
            ),
            SizedBox(width: AppSpacing.sm.w),
            Text(AppStrings.translateScreenTitle, style: textTheme.titleMedium),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          AppStrings.translateScreenSubtitle,
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey.withAlpha((0.6 * 255).toInt()),
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          "Tip: For better accuracy, you can split names or phrases into their morphemes. For example, instead of 'onyedikachukwu', try 'Onye dika Chukwu'.",
          style: textTheme.bodySmall?.copyWith(
            color: Colors.grey.withAlpha((0.5 * 255).toInt()),
            fontSize: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildInputSection(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          maxLines: 4,
          maxLength: 500,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _handleTranslate(),
          style: textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: AppStrings.inputHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSpacing.inputRadius),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(
                Radius.circular(AppSpacing.inputRadius),
              ),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            suffixIcon:
                _controller.text.isNotEmpty
                    ? IconButton(
                      icon: Icon(Icons.clear, size: AppSpacing.iconSize.sp),
                      onPressed: _clearText,
                    )
                    : null,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    TextTheme textTheme, [
    NetworkStatusProvider? networkStatus,
  ]) {
    // final isNetworkDown = networkStatus?.hasConnection == false;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _handleTranslate,
                icon:
                    _loading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: ShimmerLoader(
                            height: 16,
                            width: 16,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                        )
                        : Icon(
                          Icons.translate,
                          color: Colors.white,
                          size: AppSpacing.iconSize.sp,
                        ),
                label: Text(
                  _loading
                      ? AppStrings.translatingButton
                      : AppStrings.translateButton,
                  style: textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Translation Limit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            _loadingUsage
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ShimmerLoader(
                    height: 16,
                    width: 16,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                )
                : _isSubscribed
                ? Text(
                  'Unlimited',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                )
                : Text(
                  '${_usageStats['translations']} / ${UsageService.translationLimit}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        _usageStats['translations']! >=
                                UsageService.translationLimit
                            ? AppColors.error
                            : AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorCard(TextTheme textTheme) {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md.w),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red[700],
              size: AppSpacing.iconSize.sp,
            ),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(
              child: Text(
                _errorMessage!,
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection(TextTheme textTheme) {
    final foundWords = _results.where((r) => r.definitions.isNotEmpty).length;
    final totalWords = _results.length;
    final fullNsibidi = _results
        .map((result) => result.nsibidi)
        .where((nsibidi) => nsibidi != null && nsibidi.isNotEmpty)
        .join('');
    final originalInput = _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.library_books, size: AppSpacing.iconSize.sp),
            SizedBox(width: AppSpacing.sm.w),
            Text(
              AppStrings.translationResults,
              style: textTheme.titleMedium?.copyWith(color: Colors.grey[800]),
            ),
            const Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w,
                vertical: AppSpacing.xs.h,
              ),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Text(
                '$foundWords/$totalWords found',
                style: textTheme.labelLarge?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.sm.h),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: _usedAI ? Colors.blue[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            border: Border.all(
              color: _usedAI ? Colors.blue[200]! : Colors.green[200]!,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _usedAI ? Icons.psychology : Icons.auto_awesome,
                size: 16.sp,
                color: _usedAI ? Colors.blue[700] : Colors.green[700],
              ),
              SizedBox(width: AppSpacing.xs.w),
              Text(
                _usedAI ? AppStrings.aiContextAware : AppStrings.smartHeuristic,
                style: textTheme.labelLarge?.copyWith(
                  color: _usedAI ? Colors.blue[700] : Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
        if (fullNsibidi.isNotEmpty)
          Card(
            color: Colors.orange[50],
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Full Nsibidi for:',
                          style: textTheme.labelLarge?.copyWith(
                            color: Colors.orange[900],
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(originalInput, style: textTheme.titleMedium),
                        SizedBox(height: AppSpacing.xs.h),
                        Text(
                          fullNsibidi,
                          style: textTheme.displayLarge?.copyWith(
                            fontSize: 32.sp,
                            fontFamily: 'Akagu',
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs.h),
                        Row(
                          children: [
                            Text(
                              'Akagu: ',
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.orange[900],
                              ),
                            ),
                            Text(
                              originalInput,
                              style: textTheme.labelSmall?.copyWith(
                                fontFamily: 'Akagu',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.copy,
                          color: Colors.orange[900],
                          size: AppSpacing.iconSize.sp,
                        ),
                        tooltip: 'Copy Nsibidi',
                        onPressed: () => _copyToClipboard(fullNsibidi),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.image,
                          color: Colors.orange[900],
                          size: AppSpacing.iconSize.sp,
                        ),
                        tooltip: 'Generate Image',
                        onPressed: () async {
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => NsibidiImagePage(
                                    nsibidiText: fullNsibidi,
                                    originalInput: originalInput,
                                    results: _results,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        SizedBox(height: AppSpacing.md.h),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _results.length,
          separatorBuilder:
              (context, index) => SizedBox(height: AppSpacing.sm.h),
          itemBuilder:
              (context, index) => TranslationResultCard(
                result: _results[index],
                index: index,
                originalWord:
                    index < _originalWords.length
                        ? _originalWords[index]
                        : _results[index].igboWord,
                textTheme: textTheme,
                onViewDetails:
                    () => _showWordDetails(
                      _results[index],
                      index < _originalWords.length
                          ? _originalWords[index]
                          : _results[index].igboWord,
                      textTheme,
                    ),
              ),
        ),
      ],
    );
  }

  void _showWordDetails(
    TranslationResult result,
    String originalWord,
    TextTheme textTheme,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.3,
            expand: false,
            builder:
                (context, scrollController) => Column(
                  children: [
                    Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Text(
                        AppStrings.detailsFor.replaceFirst(
                          '{word}',
                          result.igboWord,
                        ),
                        style: textTheme.headlineMedium,
                      ),
                    ),
                    SizedBox(height: AppSpacing.md.h),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (originalWord != result.igboWord) ...[
                              _buildDetailRow(
                                AppStrings.originalWord,
                                originalWord,
                                textTheme,
                              ),
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            _buildDetailRow(
                              AppStrings.igboWord,
                              result.igboWord,
                              textTheme,
                            ),
                            SizedBox(height: AppSpacing.md.h),
                            if (result.nsibidi?.isNotEmpty == true) ...[
                              _buildDetailRow(
                                AppStrings.nsibidi,
                                result.nsibidi!,
                                textTheme,
                                isNsibidi: true,
                              ),
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            if (result.definitions.isNotEmpty) ...[
                              Text(
                                AppStrings.definitions,
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              ...result.definitions.map(
                                (def) => Container(
                                  padding: EdgeInsets.all(AppSpacing.md.w),
                                  margin: EdgeInsets.only(
                                    bottom: AppSpacing.sm.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.sm,
                                    ),
                                    border: Border.all(
                                      color: Colors.blue[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (def.wordClass != null &&
                                              def.wordClass!.isNotEmpty)
                                            Chip(
                                              label: Text(
                                                Definition.getWordClassLabel(
                                                  def.wordClass ?? '',
                                                ),
                                                style: textTheme.labelSmall
                                                    ?.copyWith(fontSize: 10.sp),
                                              ),
                                              backgroundColor:
                                                  Colors.purple[50],
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 4.w,
                                              ),
                                            ),
                                          SizedBox(width: AppSpacing.sm.w),
                                          Expanded(
                                            child: Text(
                                              def.definitions.join(', '),
                                              style: textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.blue[700],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (def.nsibidi != null &&
                                          def.nsibidi!.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 4.h),
                                          child: Row(
                                            children: [
                                              Text(
                                                'Nsibidi: ',
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.orange[900],
                                                    ),
                                              ),
                                              Text(
                                                '${def.nsibidi}',
                                                style: textTheme.bodySmall
                                                    ?.copyWith(
                                                      color: Colors.orange[900],
                                                      fontFamily: 'Akagu',
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (result.tenses?.isNotEmpty == true) ...[
                              Text(
                                AppStrings.tenses,
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              ...result.tenses!.entries
                                  .where(
                                    (entry) => entry.value?.isNotEmpty == true,
                                  )
                                  .map(
                                    (entry) => Padding(
                                      padding: EdgeInsets.only(
                                        left: 16.w,
                                        bottom: 4.h,
                                      ),
                                      child: Text(
                                        '${entry.key}: ${entry.value}',
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  ),
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            if (result.tags?.isNotEmpty == true) ...[
                              Text(
                                AppStrings.tags,
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: AppSpacing.sm.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 4.h,
                                children:
                                    result.tags!
                                        .map(
                                          (tag) => Chip(
                                            label: Text(
                                              tag,
                                              style: textTheme.labelLarge,
                                            ),
                                            backgroundColor: Colors.blue[100],
                                          ),
                                        )
                                        .toList(),
                              ),
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            if (result.relatedTerms?.isNotEmpty == true) ...[
                              Text(
                                AppStrings.relatedTerms,
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              if (_usedNamesList) ...[
                                // Just display as plain text
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 16.w,
                                    bottom: 4.h,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children:
                                        result.relatedTerms!
                                            .map(
                                              (term) => Text(
                                                '• $term',
                                                style: textTheme.bodyMedium,
                                              ),
                                            )
                                            .toList(),
                                  ),
                                ),
                              ] else ...[
                                FutureBuilder<List<TranslationResult?>>(
                                  future: Future.wait(
                                    result.relatedTerms!.map(
                                      (id) => TranslationService()
                                          .fetchWordById(id),
                                    ),
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          left: 16.w,
                                          bottom: 4.h,
                                        ),
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: ShimmerLoader(
                                            height: 24,
                                            width: 24,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(12),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final terms = snapshot.data!;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children:
                                          terms
                                              .where((term) => term != null)
                                              .map(
                                                (term) => Padding(
                                                  padding: EdgeInsets.only(
                                                    left: 16.w,
                                                    bottom: 4.h,
                                                  ),
                                                  child: Text(
                                                    '• \\${term!.igboWord} (\\${term.definitions.expand((def) => def.definitions).join(', ')})',
                                                    style: textTheme.bodyMedium,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                    );
                                  },
                                ),
                              ],
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            if (result.examples?.isNotEmpty == true) ...[
                              Text('Examples', style: textTheme.titleMedium),
                              SizedBox(height: AppSpacing.xs.h),
                              ...result.examples!.map(
                                (ex) => Padding(
                                  padding: EdgeInsets.only(
                                    left: 16.w,
                                    bottom: 4.h,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (ex.nsibidi != null &&
                                          ex.nsibidi!.isNotEmpty)
                                        Text(
                                          'Nsibidi: ${ex.nsibidi}',
                                          style: textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: AppSpacing.md.h),
                            ],
                            if (result.attributes != null) ...[
                              Text(
                                AppStrings.attributes,
                                style: textTheme.titleMedium,
                              ),
                              SizedBox(height: AppSpacing.xs.h),
                              _buildAttributeChips(
                                result.attributes!,
                                textTheme,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    TextTheme textTheme, {
    bool isNsibidi = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100.w,
          child: Text('$label:', style: textTheme.titleMedium),
        ),
        Expanded(
          child: Text(
            value,
            style:
                isNsibidi
                    ? textTheme.displayLarge?.copyWith(
                      fontSize: 20.sp,
                      fontFamily: 'Akagu',
                    )
                    : textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributeChips(Attributes attributes, TextTheme textTheme) {
    final activeAttributes = <String>[];

    if (attributes.isStandardIgbo) activeAttributes.add('Standard Igbo');
    if (attributes.isAccented) activeAttributes.add('Accented');
    if (attributes.isSlang) activeAttributes.add('Slang');
    if (attributes.isConstructedTerm) activeAttributes.add('Constructed');
    if (attributes.isBorrowedTerm) activeAttributes.add('Borrowed');
    if (attributes.isStem) activeAttributes.add('Stem');
    if (attributes.isCommon) activeAttributes.add('Common');

    if (activeAttributes.isEmpty) {
      return Text(
        AppStrings.none,
        style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 8.w,
      runSpacing: 4.h,
      children:
          activeAttributes
              .map(
                (attr) => Chip(
                  label: Text(
                    attr,
                    style: textTheme.labelLarge?.copyWith(fontSize: 12.sp),
                  ),
                  backgroundColor: Colors.green[100],
                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                ),
              )
              .toList(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// Extension to add convenience methods to TranslationResult
extension TranslationResultExtensions on TranslationResult {
  bool get hasTranslation =>
      definitions.isNotEmpty &&
      definitions.any((d) => d.definitions.isNotEmpty);
  bool get hasNsibidi => nsibidi?.isNotEmpty == true;
  bool get hasAudio => audioUrl?.isNotEmpty == true;

  String get primaryDefinition =>
      definitions.isNotEmpty && definitions.first.definitions.isNotEmpty
          ? definitions.first.definitions.first
          : 'No definition available';
}

class TranslationResultCard extends StatefulWidget {
  final TranslationResult result;
  final int index;
  final String originalWord;
  final TextTheme textTheme;
  final void Function()? onViewDetails;
  const TranslationResultCard({
    super.key,
    required this.result,
    required this.index,
    required this.originalWord,
    required this.textTheme,
    this.onViewDetails,
  });

  @override
  State<TranslationResultCard> createState() => _TranslationResultCardState();

  static bool hasRelevantAttributes(Attributes attributes) {
    return attributes.isStandardIgbo ||
        attributes.isCommon ||
        attributes.isStem;
  }

  static String getSelectionContext(TranslationResult result) {
    final reasons = <String>[];
    if (result.tags?.contains('name') == true) {
      reasons.add('Common name');
    }
    if (result.tags?.contains('personal') == true) {
      reasons.add('Personal use');
    }
    if (result.tags?.contains('common') == true) {
      reasons.add('Frequently used');
    }
    if (result.attributes?.isStandardIgbo == true) {
      reasons.add('Standard Igbo');
    }
    if (result.attributes?.isCommon == true) {
      reasons.add('Common word');
    }
    if (reasons.isEmpty) {
      return 'Selected for best contextual fit';
    }
    return 'Selected: ${reasons.join(', ')}';
  }
}

class _TranslationResultCardState extends State<TranslationResultCard> {
  bool _isSaved = false;
  final _service = SavedWordsService();

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _service.isWordSaved(widget.result);
    setState(() => _isSaved = saved);
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _service.removeWord(widget.result);
      setState(() => _isSaved = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Removed from saved words')));
    } else {
      await _service.saveWord(widget.result);
      setState(() => _isSaved = true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    // final index = widget.index;
    final textTheme = widget.textTheme;
    final hasTranslation = result.definitions.isNotEmpty;
    final hasNsibidi = result.nsibidi?.isNotEmpty == true;
    final hasAudio = result.audioUrl?.isNotEmpty == true;
    final originalWord = widget.originalWord;

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.md.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Igbo word column first
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AutoSizeText(
                            result.igboWord,
                            style: textTheme.headlineMedium,
                            maxLines: 1,
                            minFontSize: 8,
                            stepGranularity: 0.5,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
                      if (originalWord != result.igboWord)
                        Text(
                          '${AppStrings.originalWord}: $originalWord',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Container(
                    // constraints: BoxConstraints(minWidth: 48, maxWidth: 80),
                    padding: EdgeInsets.all(AppSpacing.sm.w),
                    decoration: BoxDecoration(
                      color: hasNsibidi ? Colors.orange[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: AutoSizeText(
                      hasNsibidi ? result.nsibidi! : '❌',
                      style: textTheme.displayLarge?.copyWith(
                        fontSize: 24.sp,
                        fontFamily: 'Akagu',
                      ),
                      maxLines: 1,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isSaved ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 18.sp,
                        ),
                        onPressed: _toggleSave,
                        tooltip: _isSaved ? 'Unsave' : 'Save',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                      if (hasAudio)
                        IconButton(
                          icon: Icon(Icons.volume_up, size: 18.sp),
                          onPressed:
                              () => (context as Element)
                                  .findAncestorStateOfType<
                                    _TranslateScreenState
                                  >()
                                  ?._playAudio(result.audioUrl),
                          tooltip: AppStrings.playPronunciation,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      IconButton(
                        icon: Icon(Icons.copy, size: 18.sp),
                        onPressed:
                            () => (context as Element)
                                .findAncestorStateOfType<
                                  _TranslateScreenState
                                >()
                                ?._copyToClipboard(result.igboWord),
                        tooltip: AppStrings.copyWord,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (hasTranslation) ...[
              SizedBox(height: AppSpacing.md.h),
              Container(
                padding: EdgeInsets.all(AppSpacing.md.w),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16.sp,
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        Expanded(
                          child: Text(
                            result.definitions
                                .expand((def) => def.definitions)
                                .join(', '),
                            style: textTheme.bodyMedium?.copyWith(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (result.tags?.isNotEmpty == true ||
                        TranslationResultCard.hasRelevantAttributes(
                          result.attributes!,
                        )) ...[
                      SizedBox(height: AppSpacing.sm.h),
                      Container(
                        padding: EdgeInsets.all(AppSpacing.sm.w),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6.r),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14.sp,
                              color: Colors.green[700],
                            ),
                            SizedBox(width: AppSpacing.xs.w),
                            Expanded(
                              child: Text(
                                TranslationResultCard.getSelectionContext(
                                  result,
                                ),
                                style: textTheme.labelLarge?.copyWith(
                                  color: Colors.green[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (result.tags?.isNotEmpty == true) ...[
              SizedBox(height: AppSpacing.sm.h),
              Wrap(
                spacing: 4.w,
                children:
                    result.tags!
                        .take(3)
                        .map(
                          (tag) => Chip(
                            label: Text(
                              tag,
                              style: textTheme.labelLarge?.copyWith(
                                fontSize: 10.sp,
                              ),
                            ),
                            backgroundColor: Colors.green[100],
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                          ),
                        )
                        .toList(),
              ),
            ],
            if (hasTranslation)
              TextButton.icon(
                onPressed: widget.onViewDetails,
                icon: Icon(Icons.info, size: 16.sp),
                label: Text(
                  AppStrings.viewDetails,
                  style: widget.textTheme.labelLarge?.copyWith(fontSize: 12.sp),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
