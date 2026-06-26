import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String txRef;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.txRef,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _currentUrl = '';
  String _errorMessage = '';
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _validateAndCheckConnection();
  }

  Future<void> _validateAndCheckConnection() async {
    // Validate URL format
    if (!_validateUrl()) return;

    // Check internet connection
    final isConnected = await _checkInternetConnection();
    if (!isConnected) {
      setState(() {
        _hasError = true;
        _isConnected = false;
        _errorMessage =
            'No internet connection. Please check your network and try again.';
      });
    }
  }

  bool _validateUrl() {
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid payment URL format. Please contact support.';
        });
        return false;
      }
      debugPrint('Payment URL validated: ${widget.paymentUrl}');
      return true;
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Invalid payment URL: $e';
      });
      debugPrint('URL validation error: $e');
      return false;
    }
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'google.com',
      ).timeout(Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Internet connection check failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Complete Payment',
          style: TextStyle(
            fontFamily: 'AguDisplay',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_isLoading && !_hasError)
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          // Add refresh button
          if (!_isLoading)
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshWebView,
            ),
        ],
      ),
      body: _hasError ? _buildErrorView() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Column(
      children: [
        // URL bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _currentUrl.startsWith('https') ? Icons.lock : Icons.lock_open,
                size: 16,
                color:
                    _currentUrl.startsWith('https')
                        ? AppColors.success
                        : AppColors.warning,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentUrl.isNotEmpty ? _currentUrl : widget.paymentUrl,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.secondary.withValues(alpha: 0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Web view
        Expanded(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.paymentUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              iframeAllow: "camera; microphone",
              iframeAllowFullscreen: true,
              allowsBackForwardNavigationGestures: true,
              allowsLinkPreview: false,
              isFraudulentWebsiteWarningEnabled: false,
              clearCache: true,
              cacheEnabled: true,
              // Use default user agent to avoid third-party blocking heuristics
              userAgent: null,
              // Mixed content handling for Android
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              // Android-specific: allow third-party cookies and relax safe browsing for payment flows
              thirdPartyCookiesEnabled: true,
              safeBrowsingEnabled: false,
              // Additional security settings
              allowsPictureInPictureMediaPlayback: true,
              resourceCustomSchemes: [],
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
              debugPrint('WebView created successfully');
            },
            onLoadStart: (controller, url) {
              debugPrint('WebView started loading: $url');
              setState(() {
                _isLoading = true;
                _hasError = false;
                _currentUrl = url.toString();
              });
            },
            onLoadStop: (controller, url) {
              debugPrint('WebView finished loading: $url');
              setState(() {
                _isLoading = false;
                _currentUrl = url.toString();
              });

              // Check if this is a success or failure URL
              _checkPaymentStatus(url.toString());
            },
            onProgressChanged: (controller, progress) {
              debugPrint('WebView loading progress: $progress%');
            },
            onReceivedError: (controller, request, error) {
              debugPrint('=== WebView Error Details ===');
              debugPrint('Error Description: ${error.description}');
              debugPrint('Error Type: ${error.type}');
              debugPrint('Request URL: ${request.url}');
              debugPrint('Request Method: ${request.method}');

              // Ignore subresource errors and ORB blocking which can occur for third-party assets
              final isMainFrame = request.isForMainFrame ?? true;
              final isOrbBlocked = error.description.toUpperCase().contains(
                'ERR_BLOCKED_BY_ORB',
              );

              if (!isMainFrame || isOrbBlocked) {
                debugPrint(
                  'Ignoring non-fatal webview error (mainFrame=$isMainFrame, ORB=$isOrbBlocked)',
                );
                return;
              }

              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = _getDetailedErrorMessage(error);
              });
            },
            onReceivedHttpError: (controller, request, errorResponse) {
              debugPrint('=== HTTP Error Details ===');
              debugPrint('HTTP Status Code: ${errorResponse.statusCode}');
              debugPrint('HTTP Reason: ${errorResponse.reasonPhrase}');
              debugPrint('Request URL: ${request.url}');

              final isMainFrame = request.isForMainFrame ?? true;
              if (!isMainFrame) {
                debugPrint('Ignoring HTTP error for subresource');
                return;
              }

              setState(() {
                _isLoading = false;
                _hasError = true;
                _errorMessage = _getHttpErrorMessage(errorResponse.statusCode);
              });
            },
            onReceivedServerTrustAuthRequest: (controller, challenge) async {
              debugPrint(
                'SSL Certificate challenge for: ${challenge.protectionSpace.host}',
              );
              return ServerTrustAuthResponse(
                action: ServerTrustAuthResponseAction.PROCEED,
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final url = navigationAction.request.url.toString();
              debugPrint('Navigation attempt to: $url');

              // Check if this is a success or failure URL
              if (_checkPaymentStatus(url)) {
                return NavigationActionPolicy.CANCEL;
              }

              return NavigationActionPolicy.ALLOW;
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint('WebView Console: ${consoleMessage.message}');
            },
          ),
        ),
        // Bottom instructions
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Complete your payment in the form above. You will be redirected back to the app automatically.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.security, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment is processed securely by Flutterwave.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isConnected ? Icons.error_outline : Icons.wifi_off,
              size: 64,
              color: AppColors.error,
            ),
            SizedBox(height: 16),
            Text(
              _isConnected ? 'Payment Page Error' : 'Connection Error',
              style: TextStyle(
                fontFamily: 'AguDisplay',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _errorMessage,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.secondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),

            // Retry button
            ElevatedButton.icon(
              onPressed: _refreshWebView,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 12),

            // Open in browser button (for testing)
            OutlinedButton.icon(
              onPressed: _openInBrowser,
              icon: Icon(Icons.open_in_browser),
              label: Text('Open in Browser'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 12),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel Payment',
                style: GoogleFonts.inter(
                  color: AppColors.secondary.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDetailedErrorMessage(WebResourceError error) {
    final String typeLabel = error.type.toString().split('.').last;
    switch (typeLabel.toLowerCase()) {
      case 'host_lookup':
        return 'Cannot find the payment server. Please check your internet connection and try again.';
      case 'timeout':
        return 'Payment page took too long to load. Please check your internet connection and try again.';
      case 'connect':
        return 'Cannot connect to payment server. Please check your internet connection.';
      case 'io':
        return 'Network error occurred. Please check your internet connection.';
      case 'cancelled':
      case 'canceled':
        return 'Payment page loading was cancelled.';
      case 'ssl_handshake':
      case 'ssl_error':
        return 'Secure connection failed. Please try again or contact support.';
      default:
        return 'Failed to load payment page ($typeLabel): ${error.description}';
    }
  }

  String _getHttpErrorMessage(int? statusCode) {
    if (statusCode == null) {
      return 'Unknown HTTP error. Please try again or contact support.';
    }
    switch (statusCode) {
      case 400:
        return 'Invalid payment request. Please check your payment details and try again.';
      case 401:
        return 'Payment authentication failed. Please contact support.';
      case 403:
        return 'Payment access denied. Please contact support.';
      case 404:
        return 'Payment page not found. Please try again or contact support.';
      case 408:
        return 'Payment page request timed out. Please try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'Payment server error. Please try again later.';
      case 502:
        return 'Payment gateway error. Please try again later.';
      case 503:
        return 'Payment service temporarily unavailable. Please try again later.';
      default:
        return 'HTTP Error $statusCode. Please try again or contact support.';
    }
  }

  void _refreshWebView() async {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });

    // Check connection again
    final isConnected = await _checkInternetConnection();
    if (!isConnected) {
      setState(() {
        _hasError = true;
        _isConnected = false;
        _isLoading = false;
        _errorMessage =
            'No internet connection. Please check your network and try again.';
      });
      return;
    }

    setState(() {
      _isConnected = true;
    });

    if (webViewController != null) {
      await webViewController!.reload();
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Cannot open payment URL in browser');
      }
    } catch (e) {
      debugPrint('Error opening URL in browser: $e');
      _showSnackBar('Error opening payment URL: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  bool _checkPaymentStatus(String url) {
    debugPrint('Checking payment status for URL: $url');

    // Check for success URLs - more comprehensive patterns
    final successPatterns = [
      'payment-success',
      'success',
      'completed',
      'transaction_id',
      'status=successful',
      'status=success',
      'payment_status=successful',
      'tx_status=successful',
      'flw_status=successful',
    ];

    for (String pattern in successPatterns) {
      if (url.toLowerCase().contains(pattern.toLowerCase())) {
        debugPrint('Payment success detected with pattern: $pattern');
        _showSuccessDialog();
        return true;
      }
    }

    // Check for failure URLs - more comprehensive patterns
    final failurePatterns = [
      'payment-failed',
      'failed',
      'error',
      'cancelled',
      'canceled',
      'status=failed',
      'status=error',
      'payment_status=failed',
      'tx_status=failed',
      'flw_status=failed',
    ];

    for (String pattern in failurePatterns) {
      if (url.toLowerCase().contains(pattern.toLowerCase())) {
        debugPrint('Payment failure detected with pattern: $pattern');
        _showFailureDialog();
        return true;
      }
    }

    return false;
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success),
                SizedBox(width: 8),
                Text('Payment Successful'),
              ],
            ),
            content: Text('Your payment has been processed successfully!'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(
                    context,
                  ).pop(true); // Return to previous screen with success
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: Text('Continue'),
              ),
            ],
          ),
    );
  }

  void _showFailureDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: AppColors.error),
                SizedBox(width: 8),
                Text('Payment Failed'),
              ],
            ),
            content: Text(
              'Your payment could not be processed. Please try again.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(
                    context,
                  ).pop(false); // Return to previous screen with failure
                },
                child: Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _refreshWebView(); // Retry payment
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Retry'),
              ),
            ],
          ),
    );
  }
}
