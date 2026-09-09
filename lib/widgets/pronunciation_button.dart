import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nketa/services/intron_voice_service.dart';
import 'package:nketa/theme/app_strings.dart';

/// Speaker button that plays TTS via Intron (with local cache).
class PronunciationButton extends StatefulWidget {
  const PronunciationButton({
    super.key,
    required this.text,
    this.existingAudioUrl,
    this.iconSize,
    this.color,
    this.compact = true,
  });

  final String text;
  final String? existingAudioUrl;
  final double? iconSize;
  final Color? color;
  final bool compact;

  @override
  State<PronunciationButton> createState() => _PronunciationButtonState();
}

class _PronunciationButtonState extends State<PronunciationButton> {
  final AudioPlayer _player = AudioPlayer();
  final IntronVoiceService _voiceService = IntronVoiceService();
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (widget.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      await _player.stop();

      final existing = widget.existingAudioUrl;
      if (existing != null && existing.isNotEmpty) {
        if (existing.startsWith('asset://')) {
          final assetPath = existing.replaceFirst('asset://', '');
          await _player.play(AssetSource(assetPath));
        } else {
          await _player.play(UrlSource(existing));
        }
        return;
      }

      if (!_voiceService.isConfigured) return;

      final path = await _voiceService.synthesizeSpeech(widget.text);
      if (path == null) return;

      if (path.startsWith('http')) {
        await _player.play(UrlSource(path));
      } else {
        await _player.play(DeviceFileSource(path));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAudioPlay)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.iconSize ?? 18;
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    if (widget.text.trim().isEmpty &&
        (widget.existingAudioUrl == null || widget.existingAudioUrl!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: _loading
          ? SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : Icon(Icons.volume_up, size: size, color: color),
      tooltip: AppStrings.playPronunciation,
      onPressed: _loading ? null : _play,
      visualDensity: widget.compact ? VisualDensity.compact : VisualDensity.standard,
      padding: widget.compact ? EdgeInsets.zero : null,
      constraints: widget.compact
          ? const BoxConstraints(minWidth: 32, minHeight: 32)
          : null,
    );
  }
}
