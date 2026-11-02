import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nketa/platform/app_platform.dart';
import 'package:nketa/services/app_env.dart';
import 'package:nketa/widgets/shimmer_loader.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/services/alternative_payment_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  static String get _kSubscriptionId {
    if (AppPlatform.isIOS) {
      return AppEnv.get('APPLE_SUBSCRIPTION_ID') ?? 'theigbobible';
    } else {
      return AppEnv.get('SUBSCRIPTION_ID') ?? 'nketa';
    }
  }

  late Stream<List<PurchaseDetails>> _purchaseStream;
  List<ProductDetails> _products = [];
  bool _iapAvailable = false;
  // ignore: unused_field
  bool _checkingPurchases = false;
  bool _iapInitialized = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initIAP();
  }

  Future<void> _initIAP() async {
    if (AppPlatform.isWeb) {
      setState(() {
        _iapInitialized = true;
        _loading = false;
      });
      return;
    }
    try {
      _iapAvailable = await InAppPurchase.instance.isAvailable();

      if (!_iapAvailable) {
        setState(() {
          _iapInitialized = true;
          _loading = false;
        });
        return;
      }

      _purchaseStream = InAppPurchase.instance.purchaseStream;
      _purchaseStream.listen(_onPurchaseUpdate);

      final ProductDetailsResponse response = await InAppPurchase.instance
          .queryProductDetails({_kSubscriptionId});

      if (response.notFoundIDs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscription product not found. Product ID: $_kSubscriptionId',
            ),
          ),
        );
      }

      setState(() {
        _products = response.productDetails;
        _iapInitialized = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _iapInitialized = true;
        _loading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize purchases: $e')),
      );
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase is pending...')),
          );
          break;

        case PurchaseStatus.purchased:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription successful!')),
          );
          Navigator.of(context).pop(true);
          break;

        case PurchaseStatus.restored:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
          break;

        case PurchaseStatus.error:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchase failed: ${purchase.error?.message ?? "Unknown error"}',
              ),
            ),
          );
          break;

        case PurchaseStatus.canceled:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase was canceled')),
          );
          break;
      }

      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          // Handle completion error
        }
      }
    }
  }

  Future<void> _buySubscription() async {
    // For Android users, show alternative payment options
    if (AppPlatform.isAndroid || AppPlatform.isWeb) {
      await AlternativePaymentService.showAndroidSubscriptionOptions(context);
      return;
    }

    // For iOS users, use the existing in-app purchase system
    if (!_iapAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('In-app purchases are not available on this device'),
        ),
      );
      return;
    }

    if (!_iapInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while we initialize purchases...'),
        ),
      );
      return;
    }

    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No subscription products available. Please try again later.',
          ),
        ),
      );
      return;
    }

    final ProductDetails product = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);

    try {
      final bool success = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate purchase. Please try again.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Purchase failed: $e')));
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _checkingPurchases = true);
    try {
      await InAppPurchase.instance.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restored purchases.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
    setState(() => _checkingPurchases = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subscribe'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: ShimmerLoader(height: 32, width: 32)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscribe'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock Unlimited Access',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get unlimited access to all features:',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            _buildFeatureItem('Unlimited translations'),
            _buildFeatureItem('Unlimited image generation'),
            _buildFeatureItem('Access to all Igbo content'),
            _buildFeatureItem('Cross-device sync (optional)'),
            const SizedBox(height: 32),
            if (AppPlatform.isWeb || AppPlatform.isAndroid) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _buySubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Subscribe with Flutterwave',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ] else if (_products.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Column(
                  children: [
                    Text(
                      'Monthly Subscription',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _products.first.price,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('per month', style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _buySubscription,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Subscribe Now',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24.0),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscription Unavailable',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later or contact support.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            if (!AppPlatform.isWeb) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _restorePurchases,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Restore Purchases',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Want to sync across devices?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create an account to access your subscription on all your devices. You can do this anytime from the Profile section.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Terms & Privacy',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
