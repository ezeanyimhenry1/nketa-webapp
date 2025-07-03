import 'package:flutter/material.dart';
import 'package:the_igbo_bible/models/story_item.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

class StoryDetailScreen extends StatelessWidget {
  final StoryItem story;
  const StoryDetailScreen({super.key, required this.story});

  int _estimateReadTime(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil(); // 200 words per minute
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioPlayer = AudioPlayer();
    final readTime = _estimateReadTime(story.text);
    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.xl),
        children: [
          if (story.coverImage != null && story.coverImage!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius * 2),
              child: Image.network(
                story.coverImage!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder:
                    (context, error, stackTrace) => Container(
                      height: 200,
                      color: AppColors.secondary.withAlpha(30),
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: AppColors.secondary,
                      ),
                    ),
              ),
            ),
          SizedBox(height: AppSpacing.lg),
          Text(
            story.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'By ${story.author}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.secondary,
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              story.category,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.timer, size: 18, color: AppColors.secondary),
              SizedBox(width: 4),
              Text(
                '$readTime min read',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          if (story.source != null && story.source!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.xs),
            InkWell(
              onTap: () async {
                final uri = Uri.parse(story.source!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, color: AppColors.primary, size: 18),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Source',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: AppSpacing.lg),
          if (story.audio != null && story.audio!.isNotEmpty)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.volume_up, color: AppColors.secondary),
                  onPressed: () async {
                    await audioPlayer.stop();
                    await audioPlayer.play(UrlSource(story.audio!));
                  },
                ),
                Text('Listen to audio', style: theme.textTheme.bodyMedium),
              ],
            ),
          SizedBox(height: AppSpacing.lg),
          MarkdownBody(
            data: story.text,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyLarge?.copyWith(color: AppColors.primary),
              h1: theme.textTheme.headlineMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
              strong: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
              em: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: AppColors.primary,
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.secondary,
                fontStyle: FontStyle.italic,
              ),
              listBullet: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
