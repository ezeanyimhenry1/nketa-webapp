import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/services/saved_words_service.dart';
import 'package:the_igbo_bible/screens/nsibidi_image_page.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:the_igbo_bible/data/image_templates.dart';
import 'package:the_igbo_bible/models/image_template.dart';
import 'package:the_igbo_bible/services/event_service.dart';
import 'package:the_igbo_bible/models/igbo_event.dart';
import 'package:the_igbo_bible/services/igbo_nsibidi_names_service.dart';
import 'package:the_igbo_bible/services/proverbs_service.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';
import 'package:the_igbo_bible/models/story_item.dart';
import 'package:the_igbo_bible/services/story_service.dart';
import 'package:the_igbo_bible/screens/story_detail_screen.dart';
import 'package:the_igbo_bible/services/cosmology_service.dart';
import 'package:the_igbo_bible/models/cosmology_item.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:the_igbo_bible/screens/support_screen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with TickerProviderStateMixin {
  // List<TranslationResult> _words = [];
  bool _loading = true;
  TranslationResult? _selectedWord;
  ImageTemplate? _selectedTemplate;
  final List<Color> _proverbColors = [
    Colors.orange[50]!,
    Colors.yellow[50]!,
    Colors.pink[50]!,
    Colors.blue[50]!,
    Colors.green[50]!,
    Colors.purple[50]!,
    Colors.teal[50]!,
  ];
  int _currentProverbColorIndex = 0;
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  final PageController _storiesPageController = PageController(
    viewportFraction: 0.85,
  );
  List<StoryItem>? _randomStories;
  bool _loadingStories = true;
  final PageController _cosmologyPageController = PageController(
    viewportFraction: 0.85,
  );
  List<CosmologyItem>? _randomCosmology;
  bool _loadingCosmology = true;
  final AudioPlayer _cosmoAudioPlayer = AudioPlayer();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _loadWords();
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _colorAnimation = ColorTween(
      begin: _proverbColors[0],
      end: _proverbColors[1],
    ).animate(_colorController);
    _colorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentProverbColorIndex =
              (_currentProverbColorIndex + 1) % _proverbColors.length;
          final nextIndex =
              (_currentProverbColorIndex + 1) % _proverbColors.length;
          _colorAnimation = ColorTween(
            begin: _proverbColors[_currentProverbColorIndex],
            end: _proverbColors[nextIndex],
          ).animate(_colorController);
        });
        _colorController.forward(from: 0);
      }
    });
    _colorController.forward();
    _loadRandomStories();
    _loadRandomCosmology();

    // Initialize shake animation
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shakeAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Start shake animation periodically
    _startShakeAnimation();
  }

  void _startShakeAnimation() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _shakeController.forward().then((_) {
          _shakeController.reverse().then((_) {
            _startShakeAnimation(); // Repeat
          });
        });
      }
    });
  }

  @override
  void dispose() {
    _colorController.dispose();
    _storiesPageController.dispose();
    _cosmologyPageController.dispose();
    _cosmoAudioPlayer.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    final saved = await SavedWordsService().getSavedWords();
    List<TranslationResult> randoms = [];
    try {
      randoms = await IgboNsibidiNamesService().fetchRandomResults();
    } catch (e) {
      // Fallback to hardcoded if fetch fails
      randoms = [];
    }
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

  Future<void> _loadRandomStories() async {
    setState(() {
      _loadingStories = true;
    });
    final allStories = await StoryService().fetchStories();
    allStories.shuffle();
    setState(() {
      _randomStories = allStories.take(5).toList();
      _loadingStories = false;
    });
  }

  Future<void> _loadRandomCosmology() async {
    setState(() {
      _loadingCosmology = true;
    });
    final allItems = await CosmologyService().fetchCosmologyItems();
    allItems.shuffle();
    setState(() {
      _randomCosmology = allItems.take(5).toList();
      _loadingCosmology = false;
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

  void _showCosmologyDetailsModal(BuildContext context, CosmologyItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (item.image != null && item.image!.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            item.image!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: Colors.deepPurple[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.audio != null && item.audio!.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.volume_up,
                              color: Colors.teal[700],
                            ),
                            onPressed: () async {
                              await _cosmoAudioPlayer.stop();
                              await _cosmoAudioPlayer.play(
                                UrlSource(item.audio!),
                              );
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.deepPurple[800],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getIgboGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Ụtụtụ ọma'; // Good morning
    } else if (hour >= 12 && hour < 17) {
      return 'Ehihie ọma'; // Good afternoon
    } else if (hour >= 17 && hour < 20) {
      return 'Mgbede ọma'; // Good evening
    } else {
      return 'Ka chi fo'; // Good night
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double cardHeight = MediaQuery.of(context).size.width * 0.45;
    if (_loading) {
      // Full-page shimmer placeholders for the entire browse page
      final screenWidth = MediaQuery.of(context).size.width;
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Events shimmer
              ShimmerLoader(height: 28, width: 180),
              SizedBox(height: AppSpacing.md.h),
              ...List.generate(
                2,
                (i) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                  child: ShimmerLoader(height: 60, width: screenWidth),
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),
              // Word card shimmer
              ShimmerLoader(height: 120, width: screenWidth),
              SizedBox(height: AppSpacing.lg.h),
              // Proverb card shimmer
              ShimmerLoader(height: 80, width: screenWidth),
              SizedBox(height: AppSpacing.lg.h),
              // Stories slider shimmer
              ShimmerLoader(height: 120, width: screenWidth),
              SizedBox(height: AppSpacing.lg.h),
              // Cosmology slider shimmer
              ShimmerLoader(height: 120, width: screenWidth),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SupportScreen()),
          );
        },
        backgroundColor: Colors.deepPurple,
        tooltip: 'Make Suggestions',
        child: const Icon(Icons.mail_outline, color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- USER GREETING ---
              StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    final user = snapshot.data!;
                    final displayName = user.displayName;
                    final email = user.email;
                    final greetingText =
                        displayName != null && displayName.isNotEmpty
                            ? '${_getIgboGreeting()}, $displayName'
                            : email != null
                            ? '${_getIgboGreeting()}, ${email.split('@')[0]}'
                            : '${_getIgboGreeting()}, User';

                    return Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.md.w),
                      margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.deepPurple[100]!,
                            Colors.deepPurple[50]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.deepPurple[200]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _shakeAnimation.value,
                                child: Icon(
                                  Icons.waving_hand,
                                  color: Colors.deepPurple[700],
                                  size: 24.sp,
                                ),
                              );
                            },
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          Expanded(
                            child: Text(
                              greetingText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.deepPurple[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),

              // Upcoming Events Section
              FutureBuilder<List<IgboEvent>>(
                future: EventService().loadEvents(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox();
                  }
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  // Compute next occurrence for each event
                  List<Map<String, dynamic>> eventWithNextDate =
                      snapshot.data!
                          .map((event) {
                            DateTime nextDate;
                            if (event.recurring) {
                              nextDate = DateTime(
                                today.year,
                                event.date.month,
                                event.date.day,
                              );
                              if (nextDate.isBefore(today)) {
                                nextDate = DateTime(
                                  today.year + 1,
                                  event.date.month,
                                  event.date.day,
                                );
                              }
                            } else {
                              nextDate = event.date;
                            }
                            return {'event': event, 'nextDate': nextDate};
                          })
                          .where((e) {
                            final nextDate = e['nextDate'] as DateTime?;
                            return nextDate != null &&
                                !nextDate.isBefore(today) &&
                                nextDate.difference(today).inDays <= 30;
                          })
                          .toList();
                  eventWithNextDate.sort(
                    (a, b) => a['nextDate'].compareTo(b['nextDate']),
                  );
                  if (eventWithNextDate.isEmpty) {
                    return SizedBox();
                  }
                  final nextEvents = eventWithNextDate.take(3).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Upcoming Igbo Events",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.green[900],
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      ...nextEvents.map((e) {
                        final event = e['event'] as IgboEvent;
                        final nextDate = e['nextDate'] as DateTime;
                        return Card(
                          color: Colors.green[50],
                          child: ListTile(
                            leading:
                                event.imageUrl != null
                                    ? Image.asset(
                                      event.imageUrl!,
                                      width: 40,
                                      height: 40,
                                    )
                                    : null,
                            title: Text(
                              event.name,
                              style: theme.textTheme.bodyLarge,
                            ),
                            subtitle: Text(
                              '${event.description}\n${nextDate.toLocal().toString().split(' ')[0]}${event.location != null ? '\n${event.location}' : ''}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: AppSpacing.lg.h),
                    ],
                  );
                },
              ),
              // Word card and Proverb card (was MasonryGridView)
              if (_selectedWord != null && _selectedTemplate != null)
                Container(
                  width: double.infinity,
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
                ),
              SizedBox(height: AppSpacing.lg.h),
              // Proverb card
              FutureBuilder<Map<String, String>>(
                future: ProverbsService().fetchProverbOfTheDay(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Container(
                      padding: EdgeInsets.all(AppSpacing.lg.w),
                      decoration: BoxDecoration(
                        color: _proverbColors[_currentProverbColorIndex],
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: const Center(
                        child: ShimmerLoader(height: 32, width: 32),
                      ),
                    );
                  }
                  final proverb = snapshot.data!;
                  return AnimatedBuilder(
                    animation: _colorAnimation,
                    builder: (context, child) {
                      return Container(
                        padding: EdgeInsets.all(AppSpacing.lg.w),
                        decoration: BoxDecoration(
                          color: _colorAnimation.value,
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
                            Text(
                              proverb['igbo'] ?? '',
                              style: theme.textTheme.bodyLarge,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppSpacing.sm.h),
                            Text(
                              proverb['english'] ?? '',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              // --- STORIES SLIDER ---
              _loadingStories ||
                      _randomStories == null ||
                      _randomStories!.isEmpty
                  ? const SizedBox()
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: AppSpacing.lg.h),
                      Text(
                        'Random Stories',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.deepPurple[900]),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      SizedBox(
                        height: cardHeight,
                        child: PageView.builder(
                          controller: _storiesPageController,
                          itemCount: _randomStories!.length,
                          itemBuilder: (context, idx) {
                            final story = _randomStories![idx];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (_) => StoryDetailScreen(story: story),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 200,
                                height: cardHeight,
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple[50],
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (story.coverImage != null &&
                                        story.coverImage!.isNotEmpty)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16.r),
                                          ),
                                          child: Image.network(
                                            story.coverImage!,
                                            height: cardHeight * 0.4,
                                            width: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stackTrace,
                                                ) => Container(
                                                  height: cardHeight * 0.4,
                                                  color: Colors.deepPurple[100],
                                                  child: Icon(
                                                    Icons.image,
                                                    color:
                                                        Colors.deepPurple[300],
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          AppSpacing.md.w,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AutoSizeText(
                                              story.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall?.copyWith(
                                                color: Colors.deepPurple[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              minFontSize: 10,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4),
                                            AutoSizeText(
                                              'By ${story.author}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: Colors.deepPurple[700],
                                              ),
                                              maxLines: 1,
                                              minFontSize: 8,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 6),
                                            Flexible(
                                              child: AutoSizeText(
                                                story.excerpt ??
                                                    story.text.substring(
                                                          0,
                                                          story.text.length > 60
                                                              ? 60
                                                              : story
                                                                  .text
                                                                  .length,
                                                        ) +
                                                        (story.text.length > 60
                                                            ? '...'
                                                            : ''),
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                maxLines: 2,
                                                minFontSize: 8,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
              // --- COSMOLOGY SLIDER ---
              _loadingCosmology ||
                      _randomCosmology == null ||
                      _randomCosmology!.isEmpty
                  ? const SizedBox()
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 32),
                      Text(
                        'Random Cosmology',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.teal[900]),
                      ),
                      SizedBox(height: AppSpacing.sm.h),
                      SizedBox(
                        height: cardHeight,
                        child: PageView.builder(
                          controller: _cosmologyPageController,
                          itemCount: _randomCosmology!.length,
                          itemBuilder: (context, idx) {
                            final item = _randomCosmology![idx];
                            return GestureDetector(
                              onTap:
                                  () =>
                                      _showCosmologyDetailsModal(context, item),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                width: 200,
                                height: cardHeight,
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (item.image != null &&
                                        item.image!.isNotEmpty)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(16.r),
                                          ),
                                          child: Image.network(
                                            item.image!,
                                            height: cardHeight * 0.4,
                                            width: 200,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      height: cardHeight * 0.4,
                                                      width: 200,
                                                      color: Colors.teal[100],
                                                      child: Icon(
                                                        Icons.image,
                                                        color: Colors.teal[300],
                                                      ),
                                                    ),
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                          AppSpacing.md.w,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            AutoSizeText(
                                              item.name,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall?.copyWith(
                                                color: Colors.teal[900],
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              minFontSize: 10,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4),
                                            AutoSizeText(
                                              item.section,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall?.copyWith(
                                                color: Colors.teal[700],
                                              ),
                                              maxLines: 1,
                                              minFontSize: 8,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 6),
                                            Flexible(
                                              child: AutoSizeText(
                                                item.description.length > 60
                                                    ? '${item.description.substring(0, 60)}...'
                                                    : item.description,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodySmall,
                                                maxLines: 2,
                                                minFontSize: 8,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
