import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:the_igbo_bible/models/translation_result.dart';
import 'package:the_igbo_bible/theme/app_spacing.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:the_igbo_bible/services/openai_service.dart';
import 'package:the_igbo_bible/data/image_templates.dart';
import 'package:the_igbo_bible/theme/app_theme.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';
import 'package:the_igbo_bible/services/usage_service.dart';

class NsibidiImagePage extends StatefulWidget {
  final String nsibidiText;
  final String originalInput;
  final List<TranslationResult> results;

  const NsibidiImagePage({
    super.key,
    required this.nsibidiText,
    required this.originalInput,
    required this.results,
  });

  @override
  State<NsibidiImagePage> createState() => _NsibidiImagePageState();
}

class _NsibidiImagePageState extends State<NsibidiImagePage> {
  final GlobalKey _imageKey = GlobalKey();

  int _selectedTemplateIndex = 0;
  bool _showDefinition = true;
  bool _showOriginalText = true;
  bool _showAkaguText = true;
  bool _isGenerating = false;
  String? _aiMeaning;
  bool _loadingMeaning = false;

  // Heuristic for full meaning/definition or AI fallback
  String get _heuristicMeaning {
    // final input = widget.originalInput.trim();
    final definitions =
        widget.results
            .where(
              (r) =>
                  r.definitions.isNotEmpty &&
                  r.definitions.first.definitions.isNotEmpty,
            )
            .map((r) => r.definitions.first.definitions.first.trim())
            .toList();
    if (definitions.isEmpty) return '';
    if (definitions.length == 1) return definitions.first;
    // If all definitions are the same, show one
    if (definitions.toSet().length == 1) return definitions.first;
    // If input is a single word, show its definition
    if (widget.results.length == 1) return definitions.first;
    // If input is a phrase or name, prefer AI if available
    return '';
  }

  @override
  void initState() {
    super.initState();
    _fetchMeaningIfNeeded();
  }

  Future<void> _fetchMeaningIfNeeded() async {
    final input = widget.originalInput.trim();
    if (_heuristicMeaning.isNotEmpty) {
      // Heuristic is good enough
      return;
    }
    // Use AI for phrase/name
    setState(() {
      _loadingMeaning = true;
    });
    try {
      final ai = OpenAIService();
      final prompt =
          "In one short sentence, what is the meaning of the Igbo name or phrase: '$input'? Respond with only the meaning.";
      final aiResult = await ai.generateTranslation(prompt, maxTokens: 24);
      setState(() {
        _aiMeaning = aiResult?.trim();
      });
    } catch (e) {
      setState(() {
        _aiMeaning = null;
      });
    } finally {
      setState(() {
        _loadingMeaning = false;
      });
    }
  }

  // Use gal's recommended permission handling
  Future<bool> _requestGalleryAccess() async {
    bool hasAccess = await Gal.hasAccess();
    if (!hasAccess) {
      await Gal.requestAccess();
      hasAccess = await Gal.hasAccess();
    }
    return hasAccess;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final squareSize = size.width - AppSpacing.lg.w * 2;
    final meaning =
        _heuristicMeaning.isNotEmpty ? _heuristicMeaning : (_aiMeaning ?? '');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Nsibidi Image'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _isGenerating ? null : _generateAndSaveImage,
            tooltip: 'Save to Gallery',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isGenerating ? null : _generateAndShareImage,
            tooltip: 'Share Image',
          ),
        ],
      ),
      body: Column(
        children: [
          // Image Preview (always square)
          Center(
            child: Container(
              width: squareSize,
              height: squareSize,
              margin: EdgeInsets.all(AppSpacing.md.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: RepaintBoundary(
                  key: _imageKey,
                  child: _buildImagePreview(squareSize, meaning),
                ),
              ),
            ),
          ),

          // Controls
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.md.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Template Selection
                    Text(
                      'Choose Template',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    SizedBox(
                      height: 80.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageTemplates.length,
                        itemBuilder: (context, index) {
                          final template = imageTemplates[index];
                          final isSelected = index == _selectedTemplateIndex;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedTemplateIndex = index;
                              });
                            },
                            child: Container(
                              width: 60.w,
                              margin: EdgeInsets.only(right: AppSpacing.sm.w),
                              decoration: BoxDecoration(
                                gradient: template.gradient,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? theme.colorScheme.primary
                                          : Colors.transparent,
                                  width: 3,
                                ),
                                image:
                                    template.backgroundImageAsset != null
                                        ? DecorationImage(
                                          image: AssetImage(
                                            template.backgroundImageAsset!,
                                          ),
                                          fit: BoxFit.cover,
                                          colorFilter: ColorFilter.mode(
                                            template.overlay ??
                                                Colors.black.withAlpha(
                                                  (0.2 * 255).toInt(),
                                                ),
                                            BlendMode.darken,
                                          ),
                                        )
                                        : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  template.backgroundImageAsset != null
                                      ? Icon(
                                        Icons.image,
                                        color: template.textColor,
                                        size: 20.sp,
                                      )
                                      : Text(
                                        '𝔸',
                                        style: TextStyle(
                                          color: template.textColor,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    template.name,
                                    style: TextStyle(
                                      color: template.textColor,
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    // Display Options
                    Text(
                      'Display Options',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    SwitchListTile(
                      title: const Text('Show Original Text'),
                      subtitle: Text(widget.originalInput),
                      value: _showOriginalText,
                      onChanged: (value) {
                        setState(() {
                          _showOriginalText = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    SwitchListTile(
                      title: const Text('Show Akagu Text'),
                      subtitle: Text(
                        widget.originalInput,
                        style: TextStyle(fontFamily: 'Akagu'),
                      ),
                      value: _showAkaguText,
                      onChanged: (value) {
                        setState(() {
                          _showAkaguText = value;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile(
                      title: const Text('Show Meaning'),
                      subtitle:
                          _loadingMeaning
                              ? const Text('Loading...')
                              : Text(
                                meaning.isNotEmpty
                                    ? meaning.length > 30
                                        ? '${meaning.substring(0, 30)}...'
                                        : meaning
                                    : 'No meaning available',
                              ),
                      value: _showDefinition && meaning.isNotEmpty,
                      onChanged:
                          meaning.isNotEmpty
                              ? (value) {
                                setState(() {
                                  _showDefinition = value;
                                });
                              }
                              : null,
                      contentPadding: EdgeInsets.zero,
                    ),
                    SizedBox(height: AppSpacing.lg.h),
                    // Action Buttons
                    if (Platform.isAndroid)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isGenerating
                                      ? null
                                      : _generateAndShareToTikTok,
                              icon: const Icon(Icons.video_library),
                              label: const Text('TikTok'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpacing.md.h,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.buttonRadius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: AppSpacing.sm.h),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                _isGenerating ? null : _generateAndSaveImage,
                            icon:
                                _isGenerating
                                    ? SizedBox(
                                      width: 16.w,
                                      height: 16.w,
                                      child: const ShimmerLoader(
                                        height: 16,
                                        width: 16,
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(8),
                                        ),
                                      ),
                                    )
                                    : const Icon(
                                      Icons.download,
                                      color: Colors.white,
                                    ),
                            label: Text(
                              _isGenerating
                                  ? 'Generating...'
                                  : 'Save to Gallery',
                              style: const TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.md.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: AppSpacing.md.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _isGenerating ? null : _generateAndShareImage,
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.md.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(double size, String meaning) {
    final template = imageTemplates[_selectedTemplateIndex];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: template.gradient,
        image:
            template.backgroundImageAsset != null
                ? DecorationImage(
                  image: AssetImage(template.backgroundImageAsset!),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    template.overlay ??
                        Colors.black.withAlpha((0.2 * 255).toInt()),
                    BlendMode.darken,
                  ),
                )
                : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(height: AppSpacing.sm.h),
            // Original text
            if (_showOriginalText)
              AutoSizeText(
                widget.originalInput,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: template.textColor.withAlpha((0.9 * 255).toInt()),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                minFontSize: 8,
                overflow: TextOverflow.ellipsis,
              ),
            if (_showOriginalText) SizedBox(height: AppSpacing.sm.h),
            // Nsibidi text (main focus)
            Expanded(
              flex: 2,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    children: [
                      AutoSizeText(
                        widget.nsibidiText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: template.textColor,
                          fontSize: 42.sp,
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Akagu',
                          letterSpacing: 2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        minFontSize: 10,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_showAkaguText)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AutoSizeText(
                              "Akagu: ",
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(color: template.textColor),
                            ),
                            AutoSizeText(
                              widget.originalInput,
                              textAlign: TextAlign.center,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall!.copyWith(
                                color: template.textColor,
                                fontFamily: 'Akagu',
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            // Meaning/definition
            if (_showDefinition && (meaning.isNotEmpty || _loadingMeaning))
              Expanded(
                flex: 1,
                child: Container(
                  padding: EdgeInsets.all(AppSpacing.sm.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha((0.2 * 255).toInt()),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child:
                        _loadingMeaning
                            ? SizedBox(
                              height: 28,
                              width: 28,
                              child: const ShimmerLoader(
                                height: 28,
                                width: 28,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(14),
                                ),
                              ),
                            )
                            : AutoSizeText(
                              meaning,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: template.textColor.withAlpha(
                                  (0.9 * 255).toInt(),
                                ),
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w400,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              minFontSize: 8,
                              overflow: TextOverflow.ellipsis,
                            ),
                  ),
                ),
              ),
            SizedBox(height: AppSpacing.sm.h),
            // Footer
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AutoSizeText(
                  'Created with',
                  style: TextStyle(
                    color: template.textColor.withAlpha((0.8 * 255).toInt()),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  minFontSize: 6,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(width: AppSpacing.sm),
                Container(
                  padding: EdgeInsets.all(2.sp),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  ),
                  child: AutoSizeText(
                    "\u904b ",
                    style: TextStyle(
                      color: template.textColor,
                      fontFamily: 'Akagu',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                    maxLines: 1,
                    minFontSize: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: AppSpacing.xs),
                AutoSizeText(
                  'The Igbo Bible App',
                  style: TextStyle(
                    color: template.textColor.withAlpha((0.8 * 255).toInt()),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  minFontSize: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateAndSaveImage() async {
    final usageService = UsageService();
    if (!await usageService.canUseImage()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image generation limit reached. Subscribe for unlimited access.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final hasAccess = await _requestGalleryAccess();
      if (!hasAccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gallery access denied. Cannot save to gallery.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
        setState(() => _isGenerating = false);
        return;
      }
      final imageData = await _captureImage();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/nsibidi_image_$timestamp.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageData);
      try {
        await Gal.putImage(file.path, album: 'The Igbo Bible');
        await usageService.incrementImage();
      } on GalException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.type.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isGenerating = false);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Image saved to gallery successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Share',
            textColor: Colors.white,
            onPressed: () => _shareImageFile(file),
          ),
        ),
      );
      Future.delayed(const Duration(seconds: 5), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    } catch (e) {
      debugPrint('Error saving image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save image to gallery'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateAndShareImage() async {
    final usageService = UsageService();
    if (!await usageService.canUseImage()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Image generation limit reached. Subscribe for unlimited access.',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final imageData = await _captureImage();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/nsibidi_share_$timestamp.png';

      final file = File(imagePath);
      await file.writeAsBytes(imageData);

      await _shareImageFile(file);
      await usageService.incrementImage();
    } catch (e) {
      debugPrint('Error sharing image: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share image'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateAndShareToTikTok() async {
    setState(() => _isGenerating = true);
    try {
      final imageData = await _captureImage();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/nsibidi_tiktok_$timestamp.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageData);

      if (Platform.isAndroid) {
        // Save to gallery to ensure TikTok can access it
        await Gal.putImage(file.path, album: 'The Igbo Bible');
        // Use share_plus to open the share sheet
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text:
                'Check out this beautiful Nsibidi translation: "${widget.originalInput}"',
            subject: 'Nsibidi Translation from The Igbo Bible',
          ),
        );
      } else {
        // iOS: just use the share sheet
        await _shareImageFile(file);
      }
    } catch (e) {
      debugPrint('Error sharing to TikTok: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share image to TikTok'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<Uint8List> _captureImage() async {
    final RenderRepaintBoundary boundary =
        _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

    // Capture at high resolution for better quality
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    return byteData!.buffer.asUint8List();
  }

  Future<void> _shareImageFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text:
            'Check out this beautiful Nsibidi translation: "${widget.originalInput}"',
        subject: 'Nsibidi Translation from The Igbo Bible',
      ),
    );
  }
}
