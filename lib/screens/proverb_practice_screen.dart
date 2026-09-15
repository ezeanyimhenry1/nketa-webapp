import 'package:flutter/material.dart';
import 'package:nketa/data/constants.dart';
import 'package:nketa/services/proverb_practice_service.dart';
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
  static const _streakKey = 'proverb_practice_streak';
  static const _guidedModeKey = 'proverb_guided_code_switch';

  List<Map<String, String>> _proverbs = [];
  int _index = 0;
  int _streak = 0;
  String _feedback = '';
  String _partial = '';
  bool _loading = true;
  bool _guidedCodeSwitch = false;

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
      _streak = prefs.getInt(_streakKey) ?? 0;
      _guidedCodeSwitch = prefs.getBool(_guidedModeKey) ?? false;
      _index = DateTime.now().millisecondsSinceEpoch % (proverbs.length);
      _loading = false;
    });
  }

  Map<String, String> get _current =>
      _proverbs.isEmpty ? {'igbo': '', 'english': ''} : _proverbs[_index];

  String get _guidedPrompt {
    if (_proverbs.isEmpty) return proverbCodeSwitchPrompts.first;
    return proverbCodeSwitchPrompts[_index % proverbCodeSwitchPrompts.length];
  }

  Future<void> _setGuidedMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guidedModeKey, value);
    setState(() => _guidedCodeSwitch = value);
  }

  Future<void> _onTranscript(String transcript) async {
    final target = _current['igbo'] ?? '';
    final result = ProverbPracticeService.score(transcript, target);
    final prefs = await SharedPreferences.getInstance();
    final scorePct = (result.score * 100).toStringAsFixed(0);
    final matchedNote = result.matchedSegment != null &&
            result.codeSwitchDetected(transcript)
        ? ' Matched: "${result.matchedSegment}".'
        : '';

    if (result.passed) {
      final newStreak = _streak + 1;
      await prefs.setInt(_streakKey, newStreak);
      setState(() {
        _streak = newStreak;
        _feedback = 'Excellent! Score: $scorePct%.$matchedNote';
        _index = (_index + 1) % _proverbs.length;
        _partial = '';
      });
    } else if (result.close) {
      setState(() {
        _feedback =
            'Close! Score: $scorePct%. Try again.$matchedNote';
        _partial = '';
      });
    } else {
      final partialNote = result.matchedSegment != null &&
              result.score > 0
          ? ' Partial match: "${result.matchedSegment}".'
          : '';
      setState(() {
        _feedback = 'Try again. Heard: "$transcript".$partialNote';
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
                  SizedBox(height: AppSpacing.md),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Guided code-switch mode'),
                    subtitle: const Text(
                      'Shows an English intro prompt. You can mix English and Igbo.',
                    ),
                    value: _guidedCodeSwitch,
                    onChanged: _setGuidedMode,
                  ),
                  SizedBox(height: AppSpacing.sm),
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
                  if (_guidedCodeSwitch) ...[
                    SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(AppSpacing.sm),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: Text(
                        'Try saying: "$_guidedPrompt" then recite the Igbo proverb.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.blue[900],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
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
                    _guidedCodeSwitch
                        ? 'English intro is OK. We score the Igbo proverb in your speech.'
                        : 'Tap mic and recite the proverb. English framing also works.',
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
