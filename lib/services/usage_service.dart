import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UsageService {
  static final UsageService _instance = UsageService._internal();
  factory UsageService() => _instance;
  UsageService._internal();

  static const int translationLimit = 53;
  static const int imageLimit = 5;

  Future<bool> isSubscribed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_subscribed') ?? false;
    }

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
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('is_subscribed') ?? false;
    }
  }

  Future<Map<String, int>> getUsageStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, use local storage with device ID
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();

      return {
        'translations': prefs.getInt('translations_used_$deviceId') ?? 0,
        'images': prefs.getInt('images_used_$deviceId') ?? 0,
      };
    }

    try {
      // For authenticated users, use Firebase
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('usage')
              .doc('lifetime')
              .get();

      if (!doc.exists) {
        return {'translations': 0, 'images': 0};
      }

      final data = doc.data()!;
      return {
        'translations': data['translations'] ?? 0,
        'images': data['images'] ?? 0,
      };
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      return {
        'translations': prefs.getInt('translations_used_$deviceId') ?? 0,
        'images': prefs.getInt('images_used_$deviceId') ?? 0,
      };
    }
  }

  Future<bool> canUseTranslation() async {
    if (await isSubscribed()) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, check local storage with device ID
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      return (prefs.getInt('translations_used_$deviceId') ?? 0) <
          translationLimit;
    }

    try {
      // For authenticated users, check Firebase
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('usage')
              .doc('lifetime')
              .get();

      if (!doc.exists) return true;

      final data = doc.data()!;
      return (data['translations'] ?? 0) < translationLimit;
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      return (prefs.getInt('translations_used_$deviceId') ?? 0) <
          translationLimit;
    }
  }

  Future<bool> canUseImage() async {
    if (await isSubscribed()) return true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, check local storage with device ID
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      return (prefs.getInt('images_used_$deviceId') ?? 0) < imageLimit;
    }

    try {
      // For authenticated users, check Firebase
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('usage')
              .doc('lifetime')
              .get();

      if (!doc.exists) return true;

      final data = doc.data()!;
      return (data['images'] ?? 0) < imageLimit;
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      return (prefs.getInt('images_used_$deviceId') ?? 0) < imageLimit;
    }
  }

  Future<void> incrementTranslation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, increment in local storage with device ID
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      int used = prefs.getInt('translations_used_$deviceId') ?? 0;
      await prefs.setInt('translations_used_$deviceId', used + 1);
      return;
    }

    try {
      // For authenticated users, increment in Firebase
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc('lifetime');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          transaction.set(docRef, {
            'translations': 1,
            'images': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          final currentTranslations = doc.data()!['translations'] ?? 0;
          transaction.update(docRef, {
            'translations': currentTranslations + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      int used = prefs.getInt('translations_used_$deviceId') ?? 0;
      await prefs.setInt('translations_used_$deviceId', used + 1);
    }
  }

  Future<void> incrementImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, increment in local storage with device ID
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      int used = prefs.getInt('images_used_$deviceId') ?? 0;
      await prefs.setInt('images_used_$deviceId', used + 1);
      return;
    }

    try {
      // For authenticated users, increment in Firebase
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc('lifetime');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          transaction.set(docRef, {
            'translations': 0,
            'images': 1,
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          final currentImages = doc.data()!['images'] ?? 0;
          transaction.update(docRef, {
            'images': currentImages + 1,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (e) {
      // Fallback to local storage if Firebase fails
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _getDeviceId();
      int used = prefs.getInt('images_used_$deviceId') ?? 0;
      await prefs.setInt('images_used_$deviceId', used + 1);
    }
  }

  // Admin function to reset usage (for testing or special cases)
  Future<void> resetUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // For anonymous users, reset local storage
      await _resetLocalUsage();
      return;
    }

    try {
      // For authenticated users, delete lifetime usage document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc('lifetime')
          .delete();
    } catch (e) {
      // Fallback to local storage if Firebase fails
      await _resetLocalUsage();
    }
  }

  // Helper method to get a persistent device ID
  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Generate a new device ID if none exists
      deviceId =
          DateTime.now().millisecondsSinceEpoch.toString() +
          (1000 + (DateTime.now().microsecond % 9000)).toString();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }

  // Helper method to reset local usage for anonymous users
  Future<void> _resetLocalUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();

    // Clear device-specific usage keys
    await prefs.remove('translations_used_$deviceId');
    await prefs.remove('images_used_$deviceId');
  }

  // Test method to verify lifetime usage tracking
  Future<Map<String, dynamic>> testLifetimeUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    final isAuth = user != null;

    final stats = await getUsageStats();
    final canTranslate = await canUseTranslation();
    final canImage = await canUseImage();
    final subscribed = await isSubscribed();

    return {
      'authenticated': isAuth,
      'usage_stats': stats,
      'can_translate': canTranslate,
      'can_image': canImage,
      'subscribed': subscribed,
      'translation_limit': translationLimit,
      'image_limit': imageLimit,
      'device_id': isAuth ? null : await _getDeviceId(),
    };
  }
}
