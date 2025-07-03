import 'package:flutter/material.dart';
import 'package:the_igbo_bible/services/story_service.dart';
import 'package:the_igbo_bible/models/story_item.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:the_igbo_bible/screens/story_detail_screen.dart';

class ContentHubScreen extends StatefulWidget {
  const ContentHubScreen({super.key});

  @override
  State<ContentHubScreen> createState() => _ContentHubScreenState();
}

class _ContentHubScreenState extends State<ContentHubScreen> {
  late Future<List<StoryItem>> _futureStories;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _futureStories = StoryService().fetchStories();
  }

  void _openStoryDetail(BuildContext context, StoryItem story) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => StoryDetailScreen(story: story)));
  }

  List<String> _getCategories(List<StoryItem> stories) {
    final cats = stories.map((s) => s.category).toSet().toList();
    cats.sort();
    return ['All', ...cats];
  }

  List<StoryItem> _filterStories(List<StoryItem> stories) {
    return stories.where((story) {
      final matchesCategory =
          _selectedCategory == 'All' || story.category == _selectedCategory;
      final q = _searchQuery.toLowerCase();
      final matchesSearch =
          story.title.toLowerCase().contains(q) ||
          story.author.toLowerCase().contains(q) ||
          (story.excerpt?.toLowerCase().contains(q) ?? false) ||
          story.text.toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Igbo Content Hub'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<StoryItem>>(
        future: _futureStories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ShimmerLoader(height: 32, width: 32));
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No stories found.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }
          final stories = snapshot.data!;
          final categories = _getCategories(stories);
          final filteredStories = _filterStories(stories);
          final isWide = MediaQuery.of(context).size.width > 600;
          return Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search stories...',
                    prefixIcon: Icon(Icons.search, color: AppColors.primary),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.secondary,
                              ),
                              onPressed:
                                  () => setState(() => _searchQuery = ''),
                            )
                            : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppColors.primary.withAlpha(80),
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                SizedBox(height: AppSpacing.md),
                // Category chips
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      final selected = cat == _selectedCategory;
                      return ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected:
                            (_) => setState(() => _selectedCategory = cat),
                        selectedColor: AppColors.primary,
                        labelStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: selected ? Colors.white : AppColors.primary,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: AppColors.primary.withAlpha(30),
                      );
                    },
                  ),
                ),
                SizedBox(height: AppSpacing.md),
                // Stories grid
                Expanded(
                  child:
                      filteredStories.isEmpty
                          ? Center(
                            child: Text(
                              'No stories match your search/filter.',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                          : SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            child: StaggeredGrid.count(
                              crossAxisCount: isWide ? 3 : 1,
                              mainAxisSpacing: AppSpacing.lg,
                              crossAxisSpacing: AppSpacing.lg,
                              children: List.generate(filteredStories.length, (
                                i,
                              ) {
                                final story = filteredStories[i];
                                return StaggeredGridTile.fit(
                                  crossAxisCellCount: 1,
                                  child: GestureDetector(
                                    onTap:
                                        () => _openStoryDetail(context, story),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.cardRadius * 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black12,
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (story.coverImage != null &&
                                              story.coverImage!.isNotEmpty)
                                            _StoryImageWithShimmer(
                                              url: story.coverImage!,
                                            ),
                                          Padding(
                                            padding: EdgeInsets.fromLTRB(
                                              AppSpacing.md,
                                              AppSpacing.md,
                                              AppSpacing.md,
                                              AppSpacing.sm,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  story.title,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.primary,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: AppSpacing.xs),
                                                Text(
                                                  'By ${story.author}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.secondary,
                                                      ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: AppSpacing.xs),
                                                Text(
                                                  story.excerpt != null &&
                                                          story
                                                              .excerpt!
                                                              .isNotEmpty
                                                      ? story.excerpt!
                                                      : (story.text
                                                              .replaceAll(
                                                                RegExp(
                                                                  r'[#*_>`\\-]',
                                                                ),
                                                                '',
                                                              )
                                                              .split('\n')
                                                              .first
                                                              .trim()
                                                              .substring(
                                                                0,
                                                                story.text.length >
                                                                        100
                                                                    ? 100
                                                                    : story
                                                                        .text
                                                                        .length,
                                                              ) +
                                                          (story.text.length >
                                                                  100
                                                              ? '...'
                                                              : '')),
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        color:
                                                            AppColors.secondary,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: AppSpacing.xs),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withAlpha(30),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    story.category,
                                                    style: theme
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StoryImageWithShimmer extends StatefulWidget {
  final String url;
  const _StoryImageWithShimmer({required this.url});

  @override
  State<_StoryImageWithShimmer> createState() => _StoryImageWithShimmerState();
}

class _StoryImageWithShimmerState extends State<_StoryImageWithShimmer> {
  bool _loading = true;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadius * 2),
          ),
          child: Image.network(
            widget.url,
            height: 90,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 90,
                  color: AppColors.secondary.withAlpha(30),
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: AppColors.secondary,
                  ),
                ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                if (_loading) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _loading = false),
                  );
                }
                return child;
              } else {
                if (!_loading) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => setState(() => _loading = true),
                  );
                }
                return SizedBox(height: 90, width: double.infinity);
              }
            },
          ),
        ),
        if (_loading)
          Positioned.fill(
            child: ShimmerLoader(height: 90, width: double.infinity),
          ),
      ],
    );
  }
}
