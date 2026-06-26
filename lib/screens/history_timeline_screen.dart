import 'package:flutter/material.dart';
import 'package:nketa/widgets/shimmer_loader.dart';
import 'package:nketa/services/history_timeline_service.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/theme/app_spacing.dart';

class HistoryTimelineScreen extends StatefulWidget {
  const HistoryTimelineScreen({super.key});

  @override
  State<HistoryTimelineScreen> createState() => _HistoryTimelineScreenState();
}

class _HistoryTimelineScreenState extends State<HistoryTimelineScreen> {
  late Future<List<Map<String, dynamic>>> _timelineFuture;
  final Set<String> _expandedEvents =
      {}; // Use event unique key (e.g. title+period)

  @override
  void initState() {
    super.initState();
    _timelineFuture = HistoryTimelineService().fetchTimeline();
  }

  String _eventKey(Map<String, dynamic> event) =>
      '${event['era']}|${event['title']}|${event['period']}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Igbo History Timeline'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _timelineFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ShimmerLoader(height: 32, width: 32));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load timeline.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }
          final timeline = snapshot.data!;
          // Group events by era
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (final event in timeline) {
            grouped.putIfAbsent(event['era'], () => []).add(event);
          }
          return ListView(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.md,
            ),
            children:
                grouped.entries.map((entry) {
                  final era = entry.key;
                  final events = entry.value;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Era header only
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(
                          bottom: AppSpacing.sm,
                          top: AppSpacing.lg,
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                          horizontal: AppSpacing.lg,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.cardRadius,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timeline,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                era,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Timeline
                      ...List.generate(events.length, (i) {
                        final event = events[i];
                        final isFirst = i == 0;
                        final isLast = i == events.length - 1;
                        final eventKey = _eventKey(event);
                        final isEventExpanded = _expandedEvents.contains(
                          eventKey,
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Timeline line and dot
                            Container(
                              margin: EdgeInsets.only(
                                left: AppSpacing.lg,
                                right: AppSpacing.md,
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 4,
                                    height: isFirst ? 24 : 12,
                                    color:
                                        isFirst
                                            ? Colors.transparent
                                            : AppColors.primary.withAlpha(80),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.secondary,
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        event['icon'] ?? '',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 4,
                                    height: isLast ? 24 : 36,
                                    color:
                                        isLast
                                            ? Colors.transparent
                                            : AppColors.primary.withAlpha(80),
                                  ),
                                ],
                              ),
                            ),
                            // Event card
                            Expanded(
                              child: Card(
                                margin: EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                  top: 0,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.cardRadius,
                                  ),
                                ),
                                color: Colors.white,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.cardRadius,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (isEventExpanded) {
                                        _expandedEvents.remove(eventKey);
                                      } else {
                                        _expandedEvents.add(eventKey);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.all(AppSpacing.md),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                event['title'],
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            ),
                                            AnimatedRotation(
                                              turns:
                                                  isEventExpanded ? 0.5 : 0.0,
                                              duration: const Duration(
                                                milliseconds: 300,
                                              ),
                                              child: Icon(
                                                Icons.expand_more,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: AppSpacing.xs),
                                        Text(
                                          event['period'],
                                          style: theme.textTheme.labelLarge
                                              ?.copyWith(
                                                color: AppColors.secondary,
                                              ),
                                        ),
                                        SizedBox(height: AppSpacing.xs),
                                        Text(
                                          event['description'],
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: AppColors.secondary,
                                              ),
                                        ),
                                        if (isEventExpanded &&
                                            (event['story']
                                                    ?.toString()
                                                    .isNotEmpty ??
                                                false))
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: AppSpacing.sm,
                                            ),
                                            child: Text(
                                              event['story'],
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: AppColors.primary,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  );
                }).toList(),
          );
        },
      ),
    );
  }
}
