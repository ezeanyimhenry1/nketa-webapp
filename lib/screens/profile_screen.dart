import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:the_igbo_bible/widgets/shimmer_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSubscribed = false;
  bool _loading = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  // In-app purchase
  static final String _kSubscriptionId =
      Platform.isIOS
          ? dotenv.env['APPLE_SUBSCRIPTION_ID']!
          : dotenv.env['SUBSCRIPTION_ID']!;
  late Stream<List<PurchaseDetails>> _purchaseStream;
  List<ProductDetails> _products = [];
  bool _iapAvailable = false;
  bool _checkingPurchases = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: dotenv.env['GOOGLE_SERVER_CLIENT_ID'],
  );

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    if (FirebaseAuth.instance.currentUser != null) {
      _initIAP(); // Initialize IAP if user is already logged in
    }

    _googleSignIn.onCurrentUserChanged.listen((account) {
      if (mounted) {
        setState(() {});
      }
    });

    _periodicPurchaseCheck();
  }

  Future<void> _initIAP() async {
    _iapAvailable = await InAppPurchase.instance.isAvailable();
    if (!_iapAvailable) return;
    _purchaseStream = InAppPurchase.instance.purchaseStream;
    _purchaseStream.listen(_onPurchaseUpdate);
    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails({_kSubscriptionId});
    if (response.notFoundIDs.isNotEmpty) {
      // Handle missing product
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription product not found. Check your product ID.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _products = response.productDetails;
    });
  }

  // Periodically call restorePurchases to ensure status is up to date
  void _periodicPurchaseCheck() {
    Future.delayed(const Duration(minutes: 5), () async {
      if (!mounted) return;
      await _restorePurchases();
      _periodicPurchaseCheck();
    });
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == _kSubscriptionId &&
          purchase.status == PurchaseStatus.purchased) {
        // You should verify the purchase with your backend here for security (not possible with Firebase-only)
        await _updateSubscriptionStatus();
        await _checkSubscription(); // Refresh subscription status from Firestore
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription successful!')),
        );
      }
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _buySubscription() async {
    if (_products.isEmpty) return;
    final ProductDetails product = _products.first;
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    try {
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
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
      await _checkSubscription(); // Refresh subscription status after restore
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Restored purchases.')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
    setState(() => _checkingPurchases = false);
  }

  Future<void> _updateSubscriptionStatus({bool active = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in, cannot update subscription status');
      return;
    }
    final expiry = DateTime.now().add(const Duration(days: 30));
    print('Updating subscription status for user: ${user.uid}');
    print(
      'Setting subscriptionActive: $active, expiry: ${expiry.toIso8601String()}',
    );

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'subscriptionActive': active,
      'subscriptionExpiry': expiry.toIso8601String(),
    }, SetOptions(merge: true));
    print('Subscription status updated in Firestore successfully');
  }

  Future<void> _checkSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isSubscribed = false;
        _loading = false;
      });
      return;
    }

    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    if (!doc.exists) {
      setState(() {
        _isSubscribed = false;
        _loading = false;
      });
      return;
    }
    final data = doc.data()!;
    if (data['subscriptionActive'] == true) {
      final expiry = DateTime.parse(data['subscriptionExpiry']);
      setState(() {
        _isSubscribed = expiry.isAfter(DateTime.now());
        _loading = false;
      });
    } else {
      setState(() {
        _isSubscribed = false;
        _loading = false;
      });
    }
  }

  Future<void> _loginOrRegister() async {
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      await _checkSubscription();
      await _initIAP();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Auth error: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final GoogleSignInAuthentication googleAuth =
            await account.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );
        await FirebaseAuth.instance.signInWithCredential(credential);
        await _checkSubscription();
        await _initIAP();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google sign-in error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _loading = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      await _checkSubscription();
      await _initIAP();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Apple sign-in error: $e')));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (_loading || _checkingPurchases) {
      return const Center(child: ShimmerLoader(height: 32, width: 32));
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? 'Login' : 'Register',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loginOrRegister,
                  child: Text(_isLogin ? 'Login' : 'Register'),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(
                    _isLogin
                        ? 'No account? Register'
                        : 'Have an account? Login',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  onPressed: _signInWithGoogle,
                ),
                if (Platform.isIOS)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Apple'),
                    onPressed: _signInWithApple,
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Email: ${user.email}'),
            const SizedBox(height: 16),
            Text(
              _isSubscribed ? 'Subscription: Active' : 'Subscription: Inactive',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _isSubscribed || !_iapAvailable ? null : _buySubscription,
              child: Text(
                _products.isNotEmpty
                    ? 'Subscribe for ${_products.first.price}'
                    : 'Subscribe',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _restorePurchases,
              child: const Text('Restore Purchases'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                // Sign out from Google if needed
                await _googleSignIn.disconnect();
                setState(() {});
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
