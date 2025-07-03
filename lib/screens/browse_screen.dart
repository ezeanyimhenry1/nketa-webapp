import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
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
  }

  @override
  void dispose() {
    _colorController.dispose();
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
      return const Center(child: ShimmerLoader(height: 32, width: 32));
    }
    return Padding(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        children: [
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
                return Text('No upcoming events in the next 30 days.');
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
          Expanded(
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
                                    style: theme.textTheme.displayLarge
                                        ?.copyWith(
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
                                textStyle: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(fontSize: 14.sp),
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
                  // Proverb card (now dynamic, animated color)
                  return FutureBuilder<Map<String, String>>(
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
                                ),
                                SizedBox(height: AppSpacing.sm.h),
                                Text(
                                  proverb['english'] ?? '',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
