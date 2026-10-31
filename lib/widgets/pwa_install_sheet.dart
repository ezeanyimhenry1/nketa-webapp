import 'package:flutter/material.dart';
import 'package:nketa/theme/app_theme.dart';

Future<void> showPwaIosInstallSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Nketa to Home Screen',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'AguDisplay',
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'iPhone and iPad Safari cannot install the app from a button. Use these steps:',
            ),
            const SizedBox(height: 16),
            const _Step(
              number: '1',
              text: 'Tap the Share button at the bottom of Safari.',
            ),
            const _Step(
              number: '2',
              text: 'Scroll and tap Add to Home Screen.',
            ),
            const _Step(
              number: '3',
              text: 'Tap Add. Nketa then opens full screen from the icon.',
            ),
            const SizedBox(height: 8),
            Text(
              'Reminders also need this Home Screen icon on iPhone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primary,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
