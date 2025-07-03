import 'package:flutter/material.dart';
import 'package:the_igbo_bible/services/cosmology_service.dart';
import 'package:the_igbo_bible/models/cosmology_item.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:audioplayers/audioplayers.dart';

class CosmologyScreen extends StatefulWidget {
  const CosmologyScreen({super.key});

  @override
  State<CosmologyScreen> createState() => _CosmologyScreenState();
}

class _CosmologyScreenState extends State<CosmologyScreen> {
  late Future<List<CosmologyItem>> _futureItems;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _futureItems = CosmologyService().fetchCosmologyItems();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _showDetailsModal(BuildContext context, CosmologyItem item) {
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
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (item.image != null && item.image!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          item.image!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.audio != null && item.audio!.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              Icons.volume_up,
                              color: AppColors.secondary,
                            ),
                            onPressed: () async {
                              await _audioPlayer.stop();
                              await _audioPlayer.play(UrlSource(item.audio!));
                            },
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      item.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary,
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

  Widget _buildSectionHeader(String section) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: AppSpacing.md, top: AppSpacing.xl),
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(180),
            AppColors.secondary.withAlpha(120),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(40),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        section,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCosmologyCard(CosmologyItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.image != null && item.image!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppSpacing.cardRadius * 2),
              ),
              child: Image.network(
                item.image!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      height: 180,
                      color: AppColors.secondary.withAlpha(30),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: AppColors.secondary,
                      ),
                    ),
              ),
            ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (item.audio != null && item.audio!.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.volume_up, color: AppColors.secondary),
                        onPressed: () async {
                          await _audioPlayer.stop();
                          await _audioPlayer.play(UrlSource(item.audio!));
                        },
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm),
                Text(
                  item.description.length > 100
                      ? item.description.substring(0, 100) + '...'
                      : item.description,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.secondary),
                ),
                SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () => _showDetailsModal(context, item),
                    child: Text('Learn More'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Igbo Cosmology'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<CosmologyItem>>(
        future: _futureItems,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ShimmerLoader(height: 32, width: 32));
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'Failed to load cosmology data.',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }
          final items = snapshot.data!;
          // Group by section
          final Map<String, List<CosmologyItem>> grouped = {};
          for (final item in items) {
            grouped.putIfAbsent(item.section, () => []).add(item);
          }
          return ListView(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.lg,
              horizontal: AppSpacing.md,
            ),
            children:
                grouped.entries.expand((entry) {
                  final section = entry.key;
                  final sectionItems = entry.value;
                  return [
                    _buildSectionHeader(section),
                    ...sectionItems.map(_buildCosmologyCard),
                  ];
                }).toList(),
          );
        },
      ),
    );
  }
}
