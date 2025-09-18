import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:the_igbo_bible/screens/payment_webview_screen.dart';

class AlternativePaymentService {
  // Flutterwave configuration
  static String get _flutterwaveSecretKey {
    final key = dotenv.env['FLUTTERWAVE_API_KEY'];
    debugPrint('Raw API key from env: $key');

    // Check if key is null or empty
    if (key == null || key.isEmpty) {
      debugPrint('API key is null or empty. Please check your .env file.');
      return 'FLWSECK_TEST-missing_key';
    }

    // If the key doesn't start with FLWSECK_ or FLWSECK-, it's probably the wrong format
    if (!key.startsWith('FLWSECK_') && !key.startsWith('FLWSECK-')) {
      debugPrint(
        'API key format incorrect. Expected FLWSECK_ or FLWSECK- prefix',
      );
      return 'FLWSECK_TEST-invalid_key_format';
    }

    return key;
  }

  // Country-specific pricing (in local currencies)
  static const Map<String, Map<String, dynamic>> countryPricing = {
    'NG': {'currency': 'NGN', 'amount': 1500, 'name': 'Nigeria'}, // ₦1,500
    'US': {'currency': 'USD', 'amount': 2.00, 'name': 'United States'}, // $2.00
    'GB': {
      'currency': 'GBP',
      'amount': 2.00,
      'name': 'United Kingdom',
    }, // £2.00
    'CA': {'currency': 'CAD', 'amount': 2.00, 'name': 'Canada'}, // C$2.00
    'AU': {'currency': 'AUD', 'amount': 2.00, 'name': 'Australia'}, // A$2.00
    'ZA': {'currency': 'ZAR', 'amount': 2.00, 'name': 'South Africa'}, // R2.00
    'KE': {'currency': 'KES', 'amount': 2.00, 'name': 'Kenya'}, // KSh2.00
    'GH': {'currency': 'GHS', 'amount': 2.00, 'name': 'Ghana'}, // GH₵2.00
    'TZ': {'currency': 'TZS', 'amount': 2.00, 'name': 'Tanzania'}, // TSh2.00
    'UG': {'currency': 'UGX', 'amount': 2.00, 'name': 'Uganda'}, // USh2.00
    'EU': {'currency': 'EUR', 'amount': 2.00, 'name': 'Europe'}, // €2.00
    'DEFAULT': {'currency': 'NGN', 'amount': 1500, 'name': 'Default'}, // ₦1,500
  };

  /// Show subscription options for Android users
  static Future<void> showAndroidSubscriptionOptions(
    BuildContext context,
  ) async {
    final countryCode = await getUserCountryCode();
    final pricing = countryPricing[countryCode] ?? countryPricing['DEFAULT']!;

    if (!context.mounted) return;

    // Check if API key is configured
    final apiKey = _flutterwaveSecretKey;
    final isApiKeyConfigured =
        !apiKey.contains('missing_key') &&
        !apiKey.contains('invalid_key_format');

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text(
                'Go Premium',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock unlimited translations and image generation.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Detected: ${pricing['name']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => _showCountrySelector(context),
                child: Text('Change Country', style: TextStyle(fontSize: 12)),
              ),
              SizedBox(height: 16),
              if (isApiKeyConfigured) ...[
                _buildSubscriptionOption(
                  'Monthly Premium',
                  '${_getCurrencySymbol(pricing['currency'])}${pricing['amount']}/month',
                  'Unlimited translations and images',
                  () => initiateSubscription(context, pricing),
                ),
                SizedBox(height: 16),
                Text(
                  'Payment processed securely via Flutterwave.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                SizedBox(height: 8),
                Text(
                  'Subscription will auto-renew monthly.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ] else ...[
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.info, color: Colors.orange[600], size: 24),
                      SizedBox(height: 8),
                      Text(
                        'In-App Payment Temporarily Unavailable',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Please use the web version to subscribe.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                _buildSubscriptionOption(
                  'Subscribe via Web',
                  'Same pricing available',
                  'Open web subscription page',
                  () => openWebSubscription(context),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildSubscriptionOption(
    String title,
    String price,
    String description,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    price,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  /// Get user's country code
  static Future<String> getUserCountryCode() async {
    try {
      // Try to get country from device locale
      final locale = Platform.localeName;
      debugPrint('Device locale: $locale');

      final countryCode = locale.split('_').last.toUpperCase();
      debugPrint('Detected country code: $countryCode');

      // If we have pricing for this country, use it
      if (countryPricing.containsKey(countryCode)) {
        debugPrint('Using country code: $countryCode');
        return countryCode;
      }

      // Fallback to common country codes based on locale
      if (locale.contains('en_NG') ||
          locale.contains('ig_NG') ||
          locale.contains('_NG')) {
        debugPrint('Detected Nigeria from locale');
        return 'NG';
      }
      if (locale.contains('en_US') || locale.contains('_US')) return 'US';
      if (locale.contains('en_GB') || locale.contains('_GB')) return 'GB';
      if (locale.contains('en_CA') || locale.contains('_CA')) return 'CA';
      if (locale.contains('en_AU') || locale.contains('_AU')) return 'AU';
      if (locale.contains('en_ZA') || locale.contains('_ZA')) return 'ZA';
      if (locale.contains('en_KE') || locale.contains('_KE')) return 'KE';
      if (locale.contains('en_GH') || locale.contains('_GH')) return 'GH';
      if (locale.contains('en_TZ') || locale.contains('_TZ')) return 'TZ';
      if (locale.contains('en_UG') || locale.contains('_UG')) return 'UG';

      debugPrint('Using default country code');
      return 'DEFAULT';
    } catch (e) {
      debugPrint('Error detecting country: $e');
      return 'DEFAULT';
    }
  }

  /// Get currency symbol for display
  static String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD':
        return '\$';
      case 'NGN':
        return '₦';
      case 'GBP':
        return '£';
      case 'CAD':
        return 'C\$';
      case 'AUD':
        return 'A\$';
      case 'ZAR':
        return 'R';
      case 'KES':
        return 'KSh';
      case 'GHS':
        return 'GH₵';
      case 'TZS':
        return 'TSh';
      case 'UGX':
        return 'USh';
      case 'EUR':
        return '€';
      default:
        return '$currency ';
    }
  }

  /// Get existing payment plan or create new one
  static Future<String?> _getOrCreatePaymentPlan(
    Map<String, dynamic> pricing,
  ) async {
    debugPrint('_getOrCreatePaymentPlan called with pricing: $pricing');
    // First, try to find an existing payment plan for this pricing
    final existingPlanId = await _findExistingPaymentPlan(pricing);
    if (existingPlanId != null) {
      debugPrint('Found existing payment plan: $existingPlanId');
      return existingPlanId;
    }

    // If no existing plan found, create a new one
    debugPrint('No existing plan found, creating new payment plan');
    return await _createPaymentPlan(pricing);
  }

  /// Find existing payment plan for the same pricing
  static Future<String?> _findExistingPaymentPlan(
    Map<String, dynamic> pricing,
  ) async {
    try {
      final apiKey = _flutterwaveSecretKey;
      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('Cannot find existing payment plan: API key not configured');
        return null;
      }

      debugPrint('_findExistingPaymentPlan called with pricing: $pricing');
      final url = Uri.parse('https://api.flutterwave.com/v3/payment-plans');

      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final plans = data['data'] as List;

          // Look for a plan with matching amount, currency, and interval
          for (final plan in plans) {
            if (plan['amount'] == pricing['amount'] &&
                plan['currency'] == pricing['currency'] &&
                plan['interval'] == 'monthly' &&
                plan['status'] == 'active') {
              debugPrint('Found matching existing plan: ${plan['id']}');
              return plan['id'].toString();
            }
          }
        }
      }

      debugPrint('No existing payment plan found');
      return null;
    } catch (e) {
      debugPrint('Error finding existing payment plan: $e');
      return null;
    }
  }

  /// Create Flutterwave Payment Plan
  static Future<String?> _createPaymentPlan(
    Map<String, dynamic> pricing,
  ) async {
    try {
      final apiKey = _flutterwaveSecretKey;
      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('Cannot create payment plan: API key not configured');
        return null;
      }

      final url = Uri.parse('https://api.flutterwave.com/v3/payment-plans');

      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = {
        'amount': pricing['amount'],
        'name': 'Igbo Bible Premium - ${pricing['name']}',
        'interval': 'monthly',
        'currency': pricing['currency'],
        'duration': 12, // 12 months maximum
      };

      debugPrint('Creating payment plan with body: ${json.encode(body)}');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Payment plan response status: ${response.statusCode}');
      debugPrint('Payment plan response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          return data['data']['id'].toString();
        }
      }

      // Handle specific error cases
      if (response.statusCode == 401) {
        debugPrint('Authentication failed. Check your API key.');
        return null;
      } else if (response.statusCode == 400) {
        debugPrint('Bad request. Check your payment plan parameters.');
        return null;
      }

      debugPrint('Failed to create payment plan: ${response.body}');
      return null;
    } catch (e) {
      debugPrint('Error creating payment plan: $e');
      return null;
    }
  }

  /// Initiate subscription via Flutterwave Payment Plans
  static Future<void> initiateSubscription(
    BuildContext context,
    Map<String, dynamic> pricing,
  ) async {
    debugPrint('Starting subscription process...');
    // Navigator.of(context).pop(); // Close the dialog

    try {
      // Check if API key is properly configured
      final apiKey = _flutterwaveSecretKey;
      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('API key not properly configured: $apiKey');
        _showPaymentError(
          context,
          'Payment service is not properly configured. Please contact support or try the web version.',
        );
        return;
      }

      debugPrint('Creating payment plan...');
      final planId = await _getOrCreatePaymentPlan(pricing).timeout(
        Duration(seconds: 30),
        onTimeout: () {
          debugPrint('Payment plan creation timed out');
          return null;
        },
      );
      debugPrint('Payment plan ID: $planId');

      if (planId == null) {
        if (!context.mounted) return;
        debugPrint('Failed to get/create payment plan');
        _showPaymentError(
          context,
          'Failed to create subscription plan. Please check your internet connection and try again.',
        );
        return;
      }

      debugPrint('PlanId is not null, initiating payment...');

      // Show loading dialog
      if (!context.mounted) return;
      _showPaymentLoading(context);

      // Create payment and get payment link
      final paymentData = await _createPaymentAndGetLink(planId, pricing);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (paymentData != null && paymentData['paymentLink'] != null) {
        if (!context.mounted) return;

        // Validate payment URL
        final paymentUrl = paymentData['paymentLink'];
        debugPrint('Payment URL to load: $paymentUrl');

        if (paymentUrl.isEmpty || !paymentUrl.startsWith('http')) {
          _showPaymentError(
            context,
            'Invalid payment URL generated. Please try again.',
          );
          return;
        }

        // Navigate to web view for payment
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder:
                (context) => PaymentWebViewScreen(
                  paymentUrl: paymentUrl,
                  txRef: paymentData['txRef'],
                ),
          ),
        );

        // Handle the result from web view
        if (result == true) {
          debugPrint('Payment completed successfully');
          // Process successful payment
          if (!context.mounted) return;
          await _processSuccessfulPaymentFromWebView(
            context,
            paymentData,
            pricing,
          );
        } else {
          debugPrint('Payment was cancelled or failed');
        }
      } else {
        if (!context.mounted) return;
        _showPaymentError(context, 'Failed to create payment link');
      }
    } catch (e) {
      // Close loading dialog if open
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (popError) {
          debugPrint('Error closing dialog: $popError');
        }
      }
      debugPrint('Payment error: $e');
      if (!context.mounted) return;
      _showPaymentError(context, 'Payment initialization failed: $e');
    }
  }

  /// Create payment and get payment link
  static Future<Map<String, dynamic>?> _createPaymentAndGetLink(
    String planId,
    Map<String, dynamic> pricing,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final customerEmail = user?.email ?? 'customer@example.com';
      final customerName = user?.displayName ?? 'Customer';

      final txRef =
          'igbo_bible_payment_${DateTime.now().millisecondsSinceEpoch}';

      // Check API key
      final apiKey = _flutterwaveSecretKey;
      debugPrint('API Key length: ${apiKey.length}');
      debugPrint('API Key starts with: ${apiKey.substring(0, 10)}...');

      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('API key not properly configured: $apiKey');
        // Return a test payment URL for development
        return {
          'paymentLink': 'https://rave.flutterwave.com/donate/test_payment',
          'txRef': txRef,
          'transactionId':
              'test_transaction_${DateTime.now().millisecondsSinceEpoch}',
          'planId': planId,
        };
      }

      final url = Uri.parse('https://api.flutterwave.com/v3/payments');
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      final body = {
        'tx_ref': txRef,
        'amount': pricing['amount'],
        'currency': pricing['currency'],
        'redirect_url': 'https://theigbobible.netlify.app/payment-success',
        'payment_options': 'card,mobilemoney,ussd,banktransfer',
        // Attach the recurring payment plan so Flutterwave can validate the request
        'payment_plan': planId,
        'customer': {'email': customerEmail, 'name': customerName},
        'customizations': {
          'title': 'Igbo Bible Premium Subscription',
          'description': 'Monthly premium subscription for unlimited access',
          'logo': 'https://theigbobible.netlify.app/logo.png',
        },
        'meta': {'payment_plan_id': planId, 'subscription_type': 'monthly'},
      };

      debugPrint('Creating payment with body: ${json.encode(body)}');
      debugPrint('Request URL: $url');
      debugPrint('Request headers: $headers');

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      debugPrint('Payment creation response status: ${response.statusCode}');
      debugPrint('Payment creation response headers: ${response.headers}');
      debugPrint('Payment creation response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final paymentLink = data['data']['link'];
          debugPrint('Payment link generated: $paymentLink');

          return {
            'paymentLink': paymentLink,
            'txRef': txRef,
            'transactionId': data['data']['id'],
            'planId': planId,
          };
        } else {
          debugPrint('Payment creation failed: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Payment creation HTTP error: ${response.statusCode}');
        debugPrint('Error response body: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error creating payment: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Process successful payment from web view
  static Future<void> _processSuccessfulPaymentFromWebView(
    BuildContext context,
    Map<String, dynamic> paymentData,
    Map<String, dynamic> pricing,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showPaymentError(context, 'Please log in to complete subscription');
        return;
      }

      // Show verification loading dialog
      _showPaymentVerificationLoadingDialog(context);

      // Verify payment with Flutterwave API (transactionId first, then tx_ref)
      Map<String, dynamic>? verificationResult =
          await _verifyPaymentWithFlutterwave(
            paymentData['txRef'],
            paymentData['transactionId'],
          );

      // Fallback: verify by reference if transactionId verification failed
      if (verificationResult == null ||
          verificationResult['status'] != 'success') {
        debugPrint(
          'Primary verification failed, attempting verify_by_reference using tx_ref...',
        );
        verificationResult = await _verifyPaymentWithFlutterwaveByTxRef(
          paymentData['txRef'],
        );
      }

      // Sometimes the gateway needs a moment to finalize; retry briefly if pending
      if (verificationResult == null ||
          verificationResult['status'] != 'success') {
        for (int attempt = 1; attempt <= 3; attempt++) {
          await Future.delayed(Duration(seconds: 2 * attempt));
          debugPrint('Retrying verification (attempt $attempt)...');
          verificationResult = await _verifyPaymentWithFlutterwaveByTxRef(
            paymentData['txRef'],
          );
          if (verificationResult != null &&
              verificationResult['status'] == 'success') {
            break;
          }
        }
      }

      // Close verification dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (verificationResult != null &&
          verificationResult['status'] == 'success') {
        // Payment verified successfully
        debugPrint(
          'Payment verified successfully: ${verificationResult['data']}',
        );

        // Calculate subscription expiry (monthly)
        final now = DateTime.now();
        final expiry = now.add(Duration(days: 30));

        // Update user subscription in Firebase
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'subscriptionActive': true,
          'subscriptionExpiry': expiry.toIso8601String(),
          'subscriptionType': 'monthly',
          'paymentAmount': pricing['amount'],
          'paymentCurrency': pricing['currency'],
          'paymentCountry': pricing['name'],
          'paymentTxRef': paymentData['txRef'],
          'paymentTransactionId': paymentData['transactionId'],
          'paymentMethod': 'flutterwave_payment',
          'paymentPlanId': paymentData['planId'],
          'paymentVerified': true,
          'paymentVerificationData': verificationResult['data'],
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (context.mounted) {
          _showPaymentSuccess(context);
        }
      } else {
        // Payment verification failed
        debugPrint('Payment verification failed: $verificationResult');
        if (context.mounted) {
          _showPaymentError(
            context,
            'Payment verification failed. If you were charged, please contact support with your reference: ${paymentData['txRef']}.',
          );
        }
      }
    } catch (e) {
      // Close verification dialog if open
      if (context.mounted) {
        try {
          Navigator.of(context).pop();
        } catch (popError) {
          debugPrint('Error closing verification dialog: $popError');
        }
      }

      debugPrint('Error processing payment: $e');
      if (context.mounted) {
        _showPaymentError(context, 'Failed to process payment:');
      }
    }
  }

  /// Verify payment with Flutterwave API
  static Future<Map<String, dynamic>?> _verifyPaymentWithFlutterwave(
    String txRef,
    String transactionId,
  ) async {
    try {
      final apiKey = _flutterwaveSecretKey;
      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('Cannot verify payment: API key not configured');
        return null;
      }

      // Use transaction ID for verification (more reliable than tx_ref)
      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/$transactionId/verify',
      );
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      debugPrint('Verifying payment with transaction ID: $transactionId');

      final response = await http.get(url, headers: headers);

      debugPrint(
        'Payment verification response status: ${response.statusCode}',
      );
      debugPrint('Payment verification response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final transactionData = data['data'];
          debugPrint(
            'Payment verification successful: ${transactionData['status']}',
          );

          // Check if payment was actually successful
          if (transactionData['status'] == 'successful' &&
              transactionData['amount'] != null &&
              transactionData['currency'] != null) {
            return {'status': 'success', 'data': transactionData};
          } else {
            debugPrint('Payment not successful: ${transactionData['status']}');
            return {'status': 'failed', 'data': transactionData};
          }
        } else {
          debugPrint('Payment verification API error: ${data['message']}');
          return null;
        }
      } else {
        debugPrint('Payment verification HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error verifying payment: $e');
      return null;
    }
  }

  /// Verify payment using tx_ref (verify_by_reference)
  static Future<Map<String, dynamic>?> _verifyPaymentWithFlutterwaveByTxRef(
    String txRef,
  ) async {
    try {
      final apiKey = _flutterwaveSecretKey;
      if (apiKey.contains('missing_key') ||
          apiKey.contains('invalid_key_format')) {
        debugPrint('Cannot verify payment by tx_ref: API key not configured');
        return null;
      }

      final url = Uri.parse(
        'https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=$txRef',
      );
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      };

      debugPrint('Verifying payment by reference: $txRef');

      final response = await http.get(url, headers: headers);

      debugPrint('Verify_by_reference status: ${response.statusCode}');
      debugPrint('Verify_by_reference body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final transactionData = data['data'];
          // Ensure the charge actually succeeded
          if (transactionData['status'] == 'successful') {
            return {'status': 'success', 'data': transactionData};
          }
          return {'status': 'failed', 'data': transactionData};
        }
        debugPrint('Verify_by_reference API error: ${data['message']}');
        return null;
      }

      debugPrint('Verify_by_reference HTTP error: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error verifying by tx_ref: $e');
      return null;
    }
  }

  /// Show payment verification loading dialog
  static void _showPaymentVerificationLoadingDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Verifying Payment...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait while we verify your payment.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show payment loading dialog
  static void _showPaymentLoading(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Processing Payment...',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Please wait while we set up your payment.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show payment success dialog
  static void _showPaymentSuccess(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text(
                'Payment Successful!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your monthly premium subscription has been activated successfully!',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'You now have unlimited access to all features.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                'Your subscription will auto-renew monthly.',
                style: TextStyle(fontSize: 12, color: Colors.blue[600]),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Trigger app-wide subscription status refresh
                _refreshSubscriptionStatus();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  /// Refresh subscription status across the app
  static void _refreshSubscriptionStatus() {
    // This will trigger a refresh of subscription status in all screens
    // The app's existing subscription checking mechanisms will pick up the updated status
    debugPrint(
      'Subscription status refreshed - app will update UI automatically',
    );
  }

  /// Show payment error dialog
  static void _showPaymentError(BuildContext context, String error) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 8),
              Text(
                'Payment Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, style: TextStyle(fontSize: 16)),
              SizedBox(height: 16),
              Text(
                'Please try again or contact support if the problem persists.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Open web-based subscription page
  static Future<void> openWebSubscription(BuildContext context) async {
    const url =
        'https://theigbobible.netlify.app/subscribe'; // Replace with your actual URL

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      _showPaymentError(context, 'Could not open subscription page');
    }
  }

  /// Show country selector for debugging
  static void _showCountrySelector(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Country'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  countryPricing.entries.map((entry) {
                    final countryCode = entry.key;
                    final pricing = entry.value;
                    return ListTile(
                      title: Text(pricing['name']),
                      subtitle: Text(
                        '${_getCurrencySymbol(pricing['currency'])}${pricing['amount']}/month',
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        // Show subscription options with selected country
                        _showAndroidSubscriptionOptionsWithCountry(
                          context,
                          countryCode,
                        );
                      },
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  /// Show subscription options with specific country
  static Future<void> _showAndroidSubscriptionOptionsWithCountry(
    BuildContext context,
    String countryCode,
  ) async {
    final pricing = countryPricing[countryCode] ?? countryPricing['DEFAULT']!;

    if (!context.mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text(
                'Go Premium',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unlock unlimited translations and image generation.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Selected: ${pricing['name']}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () => _showCountrySelector(context),
                child: Text('Change Country', style: TextStyle(fontSize: 12)),
              ),
              SizedBox(height: 16),
              _buildSubscriptionOption(
                'Monthly Premium',
                '${_getCurrencySymbol(pricing['currency'])}${pricing['amount']}/month',
                'Unlimited translations and images',
                () => initiateSubscription(context, pricing),
              ),
              SizedBox(height: 16),
              Text(
                'Payment processed securely via Flutterwave.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                'Subscription will auto-renew monthly.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Check if user should see alternative payment options
  static bool shouldShowAlternativePayment() {
    return Platform.isAndroid;
  }

  /// Get subscription status for Android users
  static Future<bool> isAndroidUserSubscribed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      if (data['subscriptionActive'] == true) {
        final expiry = DateTime.parse(data['subscriptionExpiry']);
        return expiry.isAfter(DateTime.now());
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
