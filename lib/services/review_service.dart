import 'package:flutter/material.dart';
import 'package:nketa/platform/app_platform.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  static const String _lastReviewPromptKey = 'last_review_prompt_date';
  static const String _reviewPromptCountKey = 'review_prompt_count';
  static const String _hasReviewedKey = 'has_reviewed_app';
  static const String _appUsageCountKey = 'app_usage_count';
  static const String _firstInstallDateKey = 'first_install_date';

  // Minimum days between review prompts
  static const int _minDaysBetweenPrompts = 7;

  // Minimum app usage sessions before showing review prompt
  static const int _minUsageSessions = 5;

  // Maximum number of times to prompt for review
  static const int _maxPromptAttempts = 3;

  /// Check if it's appropriate to show the review prompt
  Future<bool> shouldShowReviewPrompt() async {
    // Only show on iOS devices
    if (!AppPlatform.isIOS) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // Check if user has already reviewed
    final hasReviewed = prefs.getBool(_hasReviewedKey) ?? false;
    if (hasReviewed) {
      return false;
    }

    // Check prompt count limit
    final promptCount = prefs.getInt(_reviewPromptCountKey) ?? 0;
    if (promptCount >= _maxPromptAttempts) {
      return false;
    }

    // Check if enough time has passed since last prompt
    final lastPromptDate = prefs.getString(_lastReviewPromptKey);
    if (lastPromptDate != null) {
      final lastPrompt = DateTime.parse(lastPromptDate);
      final daysSinceLastPrompt = DateTime.now().difference(lastPrompt).inDays;
      if (daysSinceLastPrompt < _minDaysBetweenPrompts) {
        return false;
      }
    }

    // Check if user has used the app enough
    final usageCount = await _getAppUsageCount();
    if (usageCount < _minUsageSessions) {
      return false;
    }

    // Check if enough time has passed since first install
    final firstInstallDate = prefs.getString(_firstInstallDateKey);
    if (firstInstallDate != null) {
      final installDate = DateTime.parse(firstInstallDate);
      final daysSinceInstall = DateTime.now().difference(installDate).inDays;
      if (daysSinceInstall < 3) {
        // Wait at least 3 days after install
        return false;
      }
    }

    return true;
  }

  /// Show the native in-app review dialog
  Future<void> requestReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;

      // Check if the in-app review is available
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        await _markReviewPromptShown();
      } else {
        // Fallback to App Store review page
        await _openStoreReview();
      }
    } catch (e) {
      debugPrint('Error requesting review: $e');
    }
  }

  /// Open the App Store review page as fallback
  Future<void> _openStoreReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      await inAppReview.openStoreListing(
        appStoreId: dotenv.env['APP_STORE_ID'], // Your App Store ID
      );
      await _markReviewPromptShown();
    } catch (e) {
      debugPrint('Error opening store review: $e');
    }
  }

  /// Show a custom review prompt dialog
  Future<void> showCustomReviewDialog(BuildContext context) async {
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
              Icon(Icons.star, color: Colors.amber, size: 28),
              SizedBox(width: 8),
              Text(
                'Enjoying the App?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your feedback helps us improve the Nketa app and reach more people who want to understand Igbo culture and cosmology.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Would you mind taking a moment to rate us on the App Store?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _markReviewPromptShown();
              },
              child: Text(
                'Not Now',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                requestReview();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Rate App', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  /// Mark that a review prompt was shown
  Future<void> _markReviewPromptShown() async {
    final prefs = await SharedPreferences.getInstance();

    // Update last prompt date
    await prefs.setString(
      _lastReviewPromptKey,
      DateTime.now().toIso8601String(),
    );

    // Increment prompt count
    final currentCount = prefs.getInt(_reviewPromptCountKey) ?? 0;
    await prefs.setInt(_reviewPromptCountKey, currentCount + 1);

    // Also update in Firebase for authenticated users
    await _updateReviewPromptInFirebase();
  }

  /// Mark that user has reviewed the app
  Future<void> markAsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasReviewedKey, true);

    // Also update in Firebase for authenticated users
    await _updateReviewStatusInFirebase(true);
  }

  /// Increment app usage count
  Future<void> incrementAppUsage() async {
    final prefs = await SharedPreferences.getInstance();

    // Set first install date if not set
    if (!prefs.containsKey(_firstInstallDateKey)) {
      await prefs.setString(
        _firstInstallDateKey,
        DateTime.now().toIso8601String(),
      );
    }

    // Increment usage count
    final currentCount = prefs.getInt(_appUsageCountKey) ?? 0;
    await prefs.setInt(_appUsageCountKey, currentCount + 1);

    // Also update in Firebase for authenticated users
    await _updateUsageInFirebase(currentCount + 1);
  }

  /// Get current app usage count
  Future<int> _getAppUsageCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, use local storage
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_appUsageCountKey) ?? 0;
    }

    try {
      // For authenticated users, check Firebase first
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('app_usage')
              .doc('stats')
              .get();

      if (doc.exists) {
        return doc.data()?['usage_count'] ?? 0;
      }
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_appUsageCountKey) ?? 0;
    }

    return 0;
  }

  /// Update review prompt data in Firebase
  Future<void> _updateReviewPromptInFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('app_usage')
          .doc('review_prompts')
          .set({
            'last_prompt_date': FieldValue.serverTimestamp(),
            'prompt_count': FieldValue.increment(1),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating review prompt in Firebase: $e');
    }
  }

  /// Update review status in Firebase
  Future<void> _updateReviewStatusInFirebase(bool hasReviewed) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('app_usage')
          .doc('review_status')
          .set({
            'has_reviewed': hasReviewed,
            'reviewed_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Error updating review status in Firebase: $e');
    }
  }

  /// Update usage count in Firebase
  Future<void> _updateUsageInFirebase(int usageCount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('app_usage')
          .doc('stats')
          .set({
            'usage_count': usageCount,
            'first_install_date': FieldValue.serverTimestamp(),
            'last_updated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating usage in Firebase: $e');
    }
  }

  /// Reset review prompt data (for testing)
  Future<void> resetReviewData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReviewPromptKey);
    await prefs.remove(_reviewPromptCountKey);
    await prefs.remove(_hasReviewedKey);
    await prefs.remove(_appUsageCountKey);
    await prefs.remove(_firstInstallDateKey);

    // Also reset in Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('app_usage')
            .doc('review_prompts')
            .delete();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('app_usage')
            .doc('review_status')
            .delete();
      } catch (e) {
        debugPrint('Error resetting review data in Firebase: $e');
      }
    }
  }

  /// Get review prompt statistics
  Future<Map<String, dynamic>> getReviewStats() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'has_reviewed': prefs.getBool(_hasReviewedKey) ?? false,
      'prompt_count': prefs.getInt(_reviewPromptCountKey) ?? 0,
      'usage_count': prefs.getInt(_appUsageCountKey) ?? 0,
      'last_prompt_date': prefs.getString(_lastReviewPromptKey),
      'first_install_date': prefs.getString(_firstInstallDateKey),
      'should_show_prompt': await shouldShowReviewPrompt(),
    };
  }
}
