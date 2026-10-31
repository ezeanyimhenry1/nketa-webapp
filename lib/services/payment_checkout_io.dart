import 'package:flutter/material.dart';
import 'package:nketa/screens/payment_webview_screen.dart';

Future<bool?> openPaymentCheckout(
  BuildContext context, {
  required String paymentUrl,
  required String txRef,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (context) => PaymentWebViewScreen(
        paymentUrl: paymentUrl,
        txRef: txRef,
      ),
    ),
  );
}
