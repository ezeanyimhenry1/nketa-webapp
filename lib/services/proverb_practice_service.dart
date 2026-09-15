import 'package:nketa/services/igbo_nsibidi_names_service.dart';

enum ProverbScoreMethod { exact, contains, window, prefix }

class ProverbPracticeResult {
  final double score;
  final String? matchedSegment;
  final ProverbScoreMethod method;

  const ProverbPracticeResult({
    required this.score,
    this.matchedSegment,
    required this.method,
  });

  bool get passed => score >= 0.75;
  bool get close => score >= 0.5 && score < 0.75;

  bool codeSwitchDetected(String transcript) {
    if (matchedSegment == null) return false;
    return IgboNsibidiNamesService.normalizeIgbo(transcript.trim()) !=
        IgboNsibidiNamesService.normalizeIgbo(matchedSegment!.trim());
  }
}

class ProverbPracticeService {
  static ProverbPracticeResult score(String transcript, String referenceIgbo) {
    final spoken = transcript.trim();
    final reference = referenceIgbo.trim();
    if (spoken.isEmpty || reference.isEmpty) {
      return const ProverbPracticeResult(score: 0, method: ProverbScoreMethod.prefix);
    }

    final spokenNorm = IgboNsibidiNamesService.normalizeIgbo(spoken);
    final refNorm = IgboNsibidiNamesService.normalizeIgbo(reference);

    if (spokenNorm == refNorm) {
      return ProverbPracticeResult(
        score: 1,
        matchedSegment: reference,
        method: ProverbScoreMethod.exact,
      );
    }

    if (spokenNorm.contains(refNorm)) {
      return ProverbPracticeResult(
        score: 1,
        matchedSegment: _extractWordSpan(spoken, refNorm) ?? reference,
        method: ProverbScoreMethod.contains,
      );
    }

    final window = _bestWordSpan(spoken, refNorm);
    if (window.score >= _prefixSimilarity(spokenNorm, refNorm)) {
      return ProverbPracticeResult(
        score: window.score,
        matchedSegment: window.segment,
        method: ProverbScoreMethod.window,
      );
    }

    return ProverbPracticeResult(
      score: _prefixSimilarity(spokenNorm, refNorm),
      matchedSegment: spoken,
      method: ProverbScoreMethod.prefix,
    );
  }

  static double _prefixSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    if (a == b) return 1;

    final shorter = a.length < b.length ? a : b;
    final longer = a.length >= b.length ? a : b;
    var matches = 0;
    for (var i = 0; i < shorter.length; i++) {
      if (shorter[i] == longer[i]) matches++;
    }
    return matches / longer.length;
  }

  static String? _extractWordSpan(String transcript, String refNorm) {
    final words = transcript.split(RegExp(r'\s+'));
    String? best;
    var bestNormLen = 1 << 30;
    for (var start = 0; start < words.length; start++) {
      var span = '';
      for (var end = start; end < words.length; end++) {
        span = span.isEmpty ? words[end] : '$span ${words[end]}';
        final spanNorm = IgboNsibidiNamesService.normalizeIgbo(span);
        if (spanNorm.contains(refNorm) && spanNorm.length < bestNormLen) {
          best = span;
          bestNormLen = spanNorm.length;
        }
      }
    }
    return best;
  }

  static ({double score, String? segment}) _bestWordSpan(
    String transcript,
    String refNorm,
  ) {
    final words = transcript.split(RegExp(r'\s+'));
    var bestScore = 0.0;
    String? bestSegment;

    for (var start = 0; start < words.length; start++) {
      var span = '';
      for (var end = start; end < words.length; end++) {
        span = span.isEmpty ? words[end] : '$span ${words[end]}';
        final spanNorm = IgboNsibidiNamesService.normalizeIgbo(span);
        if (refNorm.contains(spanNorm) || spanNorm.contains(refNorm)) {
          final score = spanNorm.contains(refNorm)
              ? 1.0
              : spanNorm.length / refNorm.length;
          if (score > bestScore) {
            bestScore = score;
            bestSegment = span;
          }
        }
        final prefixScore = _prefixSimilarity(spanNorm, refNorm);
        if (prefixScore > bestScore) {
          bestScore = prefixScore;
          bestSegment = span;
        }
      }
    }

    return (score: bestScore, segment: bestSegment);
  }
}
