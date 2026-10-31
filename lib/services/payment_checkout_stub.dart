import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool?> openPaymentCheckout(
  BuildContext context, {
  required String paymentUrl,
  required String txRef,
}) async {
  final uri = Uri.parse(paymentUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
  if (!context.mounted) return false;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Complete payment'),
      content: const Text(
        'Finish checkout in the browser window, then tap I have paid.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('I have paid'),
        ),
      ],
    ),
  );
}
