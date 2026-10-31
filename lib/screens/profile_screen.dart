import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:nketa/platform/app_platform.dart';
import 'package:nketa/widgets/shimmer_loader.dart';
import 'package:nketa/screens/subscription_screen.dart';

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
    if (AppPlatform.isIOS) {
      return dotenv.env['APPLE_SUBSCRIPTION_ID'] ?? 'theigbobible';
    } else {
      return dotenv.env['SUBSCRIPTION_ID'] ?? 'nketa';
    }
  }

  late Stream<List<PurchaseDetails>> _purchaseStream;
  // ignore: unused_field
  List<ProductDetails> _products = [];
  bool _iapAvailable = false;
  bool _checkingPurchases = false;
  // ignore: unused_field
  bool _iapInitialized = false;

  static String? _googleClientId(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) return null;
    if (!value.endsWith('.apps.googleusercontent.com')) return null;
    if (value.startsWith('your-') || value.startsWith('YOUR_')) return null;
    return value;
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: AppPlatform.isWeb
        ? (_googleClientId('GOOGLE_WEB_CLIENT_ID') ??
            _googleClientId('GOOGLE_SERVER_CLIENT_ID'))
        : null,
    serverClientId: _googleClientId('GOOGLE_SERVER_CLIENT_ID'),
  );

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    if (!AppPlatform.isWeb && FirebaseAuth.instance.currentUser != null) {
      _initIAP();
    }

    _googleSignIn.onCurrentUserChanged.listen((account) {
      if (mounted) {
        setState(() {});
      }
    });

    if (!AppPlatform.isWeb) {
      _periodicPurchaseCheck();
    }
  }

  Future<void> _initIAP() async {
    if (AppPlatform.isWeb) {
      setState(() => _iapInitialized = true);
      return;
    }
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

  Future<void> _restorePurchases() async {
    if (AppPlatform.isWeb) return;
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
      if (_isLogin) {
        // Attempt login directly
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          String message = 'Login failed. Please check your credentials.';
          if (e.code == 'user-not-found' || e.code == 'wrong-password') {
            message =
                'Invalid email or password. If you registered with Google or Apple, please use those sign-in options.';
          } else if (e.code == 'user-disabled') {
            message = 'This account has been disabled.';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          setState(() => _loading = false);
          return;
        }
      } else {
        // Attempt registration directly
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          String message = 'Registration failed. Please try again.';
          if (e.code == 'email-already-in-use') {
            message = 'An account with this email already exists.';
          } else if (e.code == 'invalid-email') {
            message = 'Invalid email address.';
          } else if (e.code == 'weak-password') {
            message = 'Password is too weak.';
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
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
      String errorMessage = 'Apple sign-in failed. Please try again.';
      if (e.toString().contains('canceled')) {
        errorMessage = 'Sign-in was canceled.';
      } else if (e.toString().contains('not available')) {
        errorMessage = 'Sign in with Apple is not available on this device.';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
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
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/icons/google_logo.png', height: 20),
                        const SizedBox(width: 12),
                        const Text(
                          'Sign in with Google',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (AppPlatform.isIOS) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: SignInWithAppleButton(
                      onPressed: _signInWithApple,
                      style: SignInWithAppleButtonStyle.black,
                    ),
                  ),
                ],
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
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              child: const Text('Manage Subscription'),
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
