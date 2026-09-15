import 'package:flutter_test/flutter_test.dart';
import 'package:nketa/services/proverb_practice_service.dart';

void main() {
  const reference = 'Onye kwe, chi ya ekwe.';

  group('ProverbPracticeService', () {
    test('passes pure Igbo proverb', () {
      final result = ProverbPracticeService.score(reference, reference);
      expect(result.passed, isTrue);
      expect(result.score, 1.0);
      expect(result.method, ProverbScoreMethod.exact);
    });

    test('passes English intro with Igbo proverb', () {
      final result = ProverbPracticeService.score(
        'The proverb is Onye kwe chi ya ekwe',
        reference,
      );
      expect(result.passed, isTrue);
      expect(result.method, isIn([
        ProverbScoreMethod.contains,
        ProverbScoreMethod.window,
      ]));
      expect(result.matchedSegment, isNotNull);
    });

    test('fails English-only input', () {
      final result = ProverbPracticeService.score(
        'The proverb is about agreement',
        reference,
      );
      expect(result.passed, isFalse);
    });

    test('scores Igbo with trailing English explanation', () {
      final result = ProverbPracticeService.score(
        'Onye kwe chi ya ekwe means when someone agrees',
        reference,
      );
      expect(result.score, greaterThan(0.5));
      expect(result.matchedSegment, isNotNull);
    });

    test('detects code-switch when English framing is used', () {
      final transcript = 'The proverb is Onye kwe chi ya ekwe';
      final result = ProverbPracticeService.score(transcript, reference);
      expect(result.codeSwitchDetected(transcript), isTrue);
    });
  });
}
