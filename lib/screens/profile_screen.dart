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
  static String get _kSubscriptionId {
    // Fallback subscription IDs if environment variables are not available
    if (Platform.isIOS) {
      return dotenv.env['APPLE_SUBSCRIPTION_ID'] ?? 'theigbobible';
    } else {
      return dotenv.env['SUBSCRIPTION_ID'] ?? 'the_igbo_bible';
    }
  }

  late Stream<List<PurchaseDetails>> _purchaseStream;
  List<ProductDetails> _products = [];
  bool _iapAvailable = false;
  bool _checkingPurchases = false;
  bool _iapInitialized = false;

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
    try {
      _iapAvailable = await InAppPurchase.instance.isAvailable();

      if (!_iapAvailable) {
        setState(() {
          _iapInitialized = true;
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
      });
    } catch (e) {
      setState(() {
        _iapInitialized = true;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize purchases: $e')),
      );
    }
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
      // Handle all purchase statuses
      switch (purchase.status) {
        case PurchaseStatus.pending:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase is pending...')),
          );
          break;

        case PurchaseStatus.purchased:
          await _updateSubscriptionStatus();
          await _checkSubscription(); // Refresh subscription status from Firestore
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription successful!')),
          );
          break;

        case PurchaseStatus.restored:
          await _updateSubscriptionStatus();
          await _checkSubscription();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          break;

        case PurchaseStatus.error:
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Purchase failed:  ${purchase.error?.message ?? "Unknown error"}',
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

      // Always complete pending purchases
      if (purchase.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(purchase);
        } catch (e) {
          //
        }
      }
    }
  }

  Future<void> _buySubscription() async {
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
      return;
    }
    final expiry = DateTime.now().add(const Duration(days: 30));

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'subscriptionActive': active,
      'subscriptionExpiry': expiry.toIso8601String(),
    }, SetOptions(merge: true));
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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        email,
      );
      if (_isLogin) {
        if (methods.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No account found for this email. If you registered with Google or Apple, please use that method.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else if (methods.contains('google.com')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is registered with Google. Please sign in with Google.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else if (methods.contains('apple.com')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is registered with Apple. Please sign in with Apple.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else if (methods.contains('password')) {
          // Proceed with email/password login
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
          } on FirebaseAuthException catch (e) {
            if (e.code == 'wrong-password') {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incorrect password.')),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auth error: ${e.message ?? e.code}')),
              );
            }
            setState(() => _loading = false);
            return;
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This email is registered with: ${methods.join(", ")}. Please use the correct sign-in method.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        }
      } else {
        // Registration
        if (methods.isEmpty) {
          // No account exists, allow registration
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email,
              password: password,
            );
          } on FirebaseAuthException catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auth error: ${e.message ?? e.code}')),
            );
            setState(() => _loading = false);
            return;
          }
        } else if (methods.contains('google.com')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is registered with Google. Please sign in with Google, then set a password in your profile.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else if (methods.contains('apple.com')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This email is registered with Apple. Please sign in with Apple, then set a password in your profile.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else if (methods.contains('password')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'An account with this email already exists. Please log in.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'This email is registered with: ${methods.join(", ")}. Please use the correct sign-in method.',
              ),
            ),
          );
          setState(() => _loading = false);
          return;
        }
      }
      await _checkSubscription();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Auth error: $e')));
      setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailController.text);
    final result = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Enter your email'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Send Reset Email'),
              ),
            ],
          ),
    );
    if (result != null && result.isNotEmpty) {
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password reset email sent!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send reset email: $e')),
          );
        }
      }
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
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: ShimmerLoader(height: 32, width: 32)),
      );
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
                if (_isLogin)
                  TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('Forgot Password?'),
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
            if (!_iapInitialized)
              const Text(
                'Initializing purchases...',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _isSubscribed ||
                          !_iapAvailable ||
                          !_iapInitialized ||
                          _products.isEmpty
                      ? null
                      : _buySubscription,
              child: Text(
                _products.isNotEmpty
                    ? 'Subscribe for ${_products.first.price}/month'
                    : _iapInitialized
                    ? 'No Products Available'
                    : 'Loading...',
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
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Delete Account'),
                        content: const Text(
                          'Are you sure you want to delete your account? This action cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );
                if (confirmed != true) return;
                setState(() => _loading = true);
                final user = FirebaseAuth.instance.currentUser;
                try {
                  if (user != null) {
                    // Delete Firestore user document and subcollections
                    final userDoc = FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid);
                    // Delete 'usage' subcollection if exists
                    final usageDocs = await userDoc.collection('usage').get();
                    for (final doc in usageDocs.docs) {
                      await doc.reference.delete();
                    }
                    await userDoc.delete();
                    // Delete Firebase Auth user
                    await user.delete();
                    // Sign out from Google if needed
                    await _googleSignIn.disconnect();
                    if (context.mounted) {
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Account deleted successfully.'),
                        ),
                      );
                    }
                  }
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'requires-recent-login') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please log in again before deleting your account.',
                          ),
                        ),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to delete account: ${e.message}',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to delete account: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );
  }
}
