import 'package:flutter_test/flutter_test.dart';
import 'package:the_igbo_bible/services/usage_service.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  group('UsageService Tests', () {
    late UsageService usageService;

    setUpAll(() async {
      // Initialize Firebase for testing
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
    });

    setUp(() {
      usageService = UsageService();
    });

    tearDown(() async {
      // Clean up test data
      await usageService.resetUsage();
    });

    test('should initialize with correct limits', () {
      expect(UsageService.translationLimit, equals(3));
      expect(UsageService.imageLimit, equals(5));
    });

    test('should check subscription status', () async {
      final isSubscribed = await usageService.isSubscribed();
      expect(isSubscribed, isA<bool>());
    });

    test('should get usage stats', () async {
      final stats = await usageService.getUsageStats();
      expect(stats, isA<Map<String, int>>());
      expect(stats['translations'], isA<int>());
      expect(stats['images'], isA<int>());
    });

    test('should check if translation can be used', () async {
      final canUse = await usageService.canUseTranslation();
      expect(canUse, isA<bool>());
    });

    test('should check if image can be used', () async {
      final canUse = await usageService.canUseImage();
      expect(canUse, isA<bool>());
    });

    test('should increment translation usage', () async {
      final initialStats = await usageService.getUsageStats();
      final initialCount = initialStats['translations'] ?? 0;

      await usageService.incrementTranslation();

      final newStats = await usageService.getUsageStats();
      final newCount = newStats['translations'] ?? 0;

      expect(newCount, equals(initialCount + 1));
    });

    test('should increment image usage', () async {
      final initialStats = await usageService.getUsageStats();
      final initialCount = initialStats['images'] ?? 0;

      await usageService.incrementImage();

      final newStats = await usageService.getUsageStats();
      final newCount = newStats['images'] ?? 0;

      expect(newCount, equals(initialCount + 1));
    });

    test('should reset usage', () async {
      // First increment some usage
      await usageService.incrementTranslation();
      await usageService.incrementImage();

      // Verify usage was incremented
      final statsAfterIncrement = await usageService.getUsageStats();
      expect(statsAfterIncrement['translations'], greaterThan(0));
      expect(statsAfterIncrement['images'], greaterThan(0));

      // Reset usage
      await usageService.resetUsage();

      // Verify usage was reset
      final statsAfterReset = await usageService.getUsageStats();
      expect(statsAfterReset['translations'], equals(0));
      expect(statsAfterReset['images'], equals(0));
    });

    test('should test lifetime usage tracking', () async {
      final testResult = await usageService.testLifetimeUsage();

      expect(testResult, isA<Map<String, dynamic>>());
      expect(testResult['authenticated'], isA<bool>());
      expect(testResult['usage_stats'], isA<Map<String, int>>());
      expect(testResult['can_translate'], isA<bool>());
      expect(testResult['can_image'], isA<bool>());
      expect(testResult['subscribed'], isA<bool>());
      expect(testResult['translation_limit'], equals(3));
      expect(testResult['image_limit'], equals(5));
    });

    test('should handle lifetime translation limits correctly', () async {
      // Reset to start fresh
      await usageService.resetUsage();

      // Use up all translation limits
      for (int i = 0; i < UsageService.translationLimit; i++) {
        final canUse = await usageService.canUseTranslation();
        expect(canUse, isTrue, reason: 'Should be able to use translation $i');
        await usageService.incrementTranslation();
      }

      // Try to use one more translation
      final canUseAfterLimit = await usageService.canUseTranslation();
      expect(
        canUseAfterLimit,
        isFalse,
        reason: 'Should not be able to use translation after limit',
      );

      // Reset and verify it works again
      await usageService.resetUsage();
      final canUseAfterReset = await usageService.canUseTranslation();
      expect(
        canUseAfterReset,
        isTrue,
        reason: 'Should be able to use translation after reset',
      );
    });

    test('should handle lifetime image limits correctly', () async {
      // Reset to start fresh
      await usageService.resetUsage();

      // Use up all image limits
      for (int i = 0; i < UsageService.imageLimit; i++) {
        final canUse = await usageService.canUseImage();
        expect(canUse, isTrue, reason: 'Should be able to use image $i');
        await usageService.incrementImage();
      }

      // Try to use one more image
      final canUseAfterLimit = await usageService.canUseImage();
      expect(
        canUseAfterLimit,
        isFalse,
        reason: 'Should not be able to use image after limit',
      );

      // Reset and verify it works again
      await usageService.resetUsage();
      final canUseAfterReset = await usageService.canUseImage();
      expect(
        canUseAfterReset,
        isTrue,
        reason: 'Should be able to use image after reset',
      );
    });

    test('should persist usage across app restarts', () async {
      // Reset to start fresh
      await usageService.resetUsage();

      // Use some translations
      await usageService.incrementTranslation();
      await usageService.incrementTranslation();

      // Verify usage is tracked
      final stats = await usageService.getUsageStats();
      expect(stats['translations'], equals(2));

      // Create a new instance (simulating app restart)
      final newUsageService = UsageService();
      final newStats = await newUsageService.getUsageStats();

      // Usage should persist
      expect(newStats['translations'], equals(2));
    });
  });
}
