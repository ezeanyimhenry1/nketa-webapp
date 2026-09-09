import 'package:flutter/material.dart';
import 'package:nketa/services/igbo_nsibidi_names_service.dart';
import 'package:nketa/services/proverbs_service.dart';
import 'package:nketa/theme/app_spacing.dart';
import 'package:nketa/theme/app_theme.dart';
import 'package:nketa/widgets/pronunciation_button.dart';
import 'package:nketa/widgets/voice_input_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProverbPracticeScreen extends StatefulWidget {
  const ProverbPracticeScreen({super.key});

  @override
  State<ProverbPracticeScreen> createState() => _ProverbPracticeScreenState();
}

class _ProverbPracticeScreenState extends State<ProverbPracticeScreen> {
  List<Map<String, String>> _proverbs = [];
  int _index = 0;
  int _streak = 0;
  String _feedback = '';
  String _partial = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final proverbs = await ProverbsService().fetchProverbs();
    setState(() {
      _proverbs = proverbs;
      _streak = prefs.getInt('proverb_practice_streak') ?? 0;
      _index = DateTime.now().millisecondsSinceEpoch % (proverbs.length);
      _loading = false;
    });
  }

  Map<String, String> get _current =>
      _proverbs.isEmpty ? {'igbo': '', 'english': ''} : _proverbs[_index];

  double _similarity(String a, String b) {
    final na = IgboNsibidiNamesService.normalizeIgbo(a);
    final nb = IgboNsibidiNamesService.normalizeIgbo(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;

    final shorter = na.length < nb.length ? na : nb;
    final longer = na.length >= nb.length ? na : nb;
    var matches = 0;
    for (var i = 0; i < shorter.length; i++) {
      if (shorter[i] == longer[i]) matches++;
    }
    return matches / longer.length;
  }

  Future<void> _onTranscript(String transcript) async {
    final target = _current['igbo'] ?? '';
    final score = _similarity(transcript, target);
    final prefs = await SharedPreferences.getInstance();

    if (score >= 0.75) {
      final newStreak = _streak + 1;
      await prefs.setInt('proverb_practice_streak', newStreak);
      setState(() {
        _streak = newStreak;
        _feedback = 'Excellent! Score: ${(score * 100).toStringAsFixed(0)}%';
        _index = (_index + 1) % _proverbs.length;
        _partial = '';
      });
    } else if (score >= 0.5) {
      setState(() {
        _feedback =
            'Close! Score: ${(score * 100).toStringAsFixed(0)}%. Try again.';
        _partial = '';
      });
    } else {
      setState(() {
        _feedback = 'Try again. Heard: "$transcript"';
        _partial = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proverb Practice'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Streak: $_streak', style: theme.textTheme.titleMedium),
                      PronunciationButton(
                        text: _current['igbo'] ?? '',
                        compact: false,
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg),
                  Text(
                    _current['igbo'] ?? '',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    _current['english'] ?? '',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Center(
                    child: VoiceInputButton(
                      onTranscript: _onTranscript,
                      onPartialTranscript: (p) => setState(() => _partial = p),
                      onError: (e) => setState(() => _feedback = e),
                      iconSize: 36,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tap mic and recite the proverb in Igbo',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_partial.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.md),
                    Chip(label: Text(_partial)),
                  ],
                  if (_feedback.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.md),
                    Text(
                      _feedback,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _feedback.startsWith('Excellent')
                            ? Colors.green[700]
                            : Colors.orange[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _index = (_index + 1) % _proverbs.length;
                        _feedback = '';
                        _partial = '';
                      });
                    },
                    child: const Text('Skip proverb'),
                  ),
                ],
              ),
            ),
    );
  }
}
