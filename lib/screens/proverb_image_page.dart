import 'dart:io';
import 'dart:ui' as ui;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:nketa/data/image_templates.dart';
import 'package:nketa/theme/app_spacing.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/widgets/shimmer_loader.dart';
import 'package:nketa/services/usage_service.dart';

class ProverbImagePage extends StatefulWidget {
  final String igboText;
  final String englishText;

  const ProverbImagePage({
    super.key,
    required this.igboText,
    required this.englishText,
  });

  @override
  State<ProverbImagePage> createState() => _ProverbImagePageState();
}

class _ProverbImagePageState extends State<ProverbImagePage> {
  final GlobalKey _imageKey = GlobalKey();
  int _selectedTemplateIndex = 0;
  bool _isGenerating = false;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _checkSubscription();
  }

  Future<void> _checkSubscription() async {
    final subscribed = await UsageService().isSubscribed();
    if (mounted) {
      setState(() {
        _isSubscribed = subscribed;
      });
    }
  }

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Proverb Image'),
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
                  child: _buildImagePreview(squareSize),
                ),
              ),
            ),
          ),
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
                          final isPremium =
                              template.backgroundImageAsset != null;
                          final isLocked = isPremium && !_isSubscribed;
                          return GestureDetector(
                            onTap: () async {
                              if (isLocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'This template is for premium users.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                _selectedTemplateIndex = index;
                              });
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 60.w,
                                  margin: EdgeInsets.only(
                                    right: AppSpacing.sm.w,
                                  ),
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
                                if (isLocked)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withAlpha(
                                          (0.5 * 255).toInt(),
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.lock,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: AppSpacing.lg.h),
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

  Widget _buildImagePreview(double size) {
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
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            AutoSizeText(
              'Today\'s Proverb',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: template.textColor.withAlpha((0.9 * 255).toInt()),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              minFontSize: 8,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: AppSpacing.sm.h),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AutoSizeText(
                      widget.igboText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: template.textColor,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                      maxLines: 4,
                      minFontSize: 10,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.sm.h),
                    AutoSizeText(
                      widget.englishText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: template.textColor.withAlpha(
                          (0.9 * 255).toInt(),
                        ),
                        fontSize: 14.sp,
                        fontStyle: FontStyle.italic,
                        height: 1.3,
                      ),
                      maxLines: 3,
                      minFontSize: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
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
                  'Nketa',
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
      _showSubscriptionDialog();
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
      final imagePath = '${directory.path}/proverb_image_$timestamp.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageData);
      try {
        await Gal.putImage(file.path, album: 'Nketa');
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
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
      _showSubscriptionDialog();
      return;
    }
    setState(() => _isGenerating = true);
    try {
      final imageData = await _captureImage();
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/proverb_share_$timestamp.png';
      final file = File(imagePath);
      await file.writeAsBytes(imageData);
      await _shareImageFile(file);
      await usageService.incrementImage();
    } catch (e) {
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

  Future<Uint8List> _captureImage() async {
    final RenderRepaintBoundary boundary =
        _imageKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
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
        text: 'Check out today\'s proverb on Nketa',
        subject: 'Proverb of the Day',
      ),
    );
  }

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Image Generation Limit Reached'),
            content: const Text(
              'You\'ve reached your free image generation limit. Subscribe to get unlimited image generation and access to all features.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
