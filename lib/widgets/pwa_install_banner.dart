import 'package:flutter/material.dart';
import 'package:nketa/services/pwa_install.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/widgets/pwa_install_sheet.dart';

class PwaInstallBanner extends StatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => _visible = PwaInstall.shouldShowBanner);
  }

  Future<void> _onTap() async {
    if (PwaInstall.canPromptInstall) {
      final installed = await PwaInstall.promptInstall();
      if (installed && mounted) _refresh();
      return;
    }
    if (PwaInstall.isIosSafari && mounted) {
      await showPwaIosInstallSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final isIos = PwaInstall.isIosSafari;
    final label = isIos ? 'Add to Home Screen' : 'Install Nketa';
    final subtitle = isIos
        ? 'Use the Share button, then Add to Home Screen.'
        : 'Add Nketa to your home screen and app list.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isIos ? Icons.ios_share : Icons.download,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(onPressed: _onTap, child: Text(isIos ? 'How' : 'Install')),
        ],
      ),
    );
  }
}
