import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nketa/services/intron_voice_service.dart';
import 'package:nketa/services/microphone_permission_service.dart';
import 'package:nketa/services/wav_bytes.dart';
import 'package:nketa/theme/app_theme.dart' show AppColors;
import 'package:record/record.dart';

/// Mic button with Intron streaming STT (sync upload fallback).
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.onTranscript,
    this.onPartialTranscript,
    this.onError,
    this.iconSize,
    this.color,
    this.enabled = true,
  });

  final ValueChanged<String> onTranscript;
  final ValueChanged<String>? onPartialTranscript;
  final ValueChanged<String>? onError;
  final double? iconSize;
  final Color? color;
  final bool enabled;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  final IntronVoiceService _voiceService = IntronVoiceService();

  bool _recording = false;
  String _partial = '';
  IntronStreamingSession? _session;
  StreamSubscription<List<int>>? _audioSub;
  final BytesBuilder _pcmChunks = BytesBuilder();
  bool _usingPcmFallback = false;
  bool _receivedFinalTranscript = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _stopInternal(notify: false);
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (!widget.enabled) return;

    if (_recording) {
      await _stopRecording();
      return;
    }

    if (!_voiceService.isConfigured) {
      widget.onError?.call('Voice AI is not configured.');
      return;
    }

    final permission = await MicrophonePermissionService.ensureGranted();
    if (!permission.granted) {
      if (permission.openSettings) {
        await MicrophonePermissionService.openSettings();
      }
      widget.onError?.call(
        permission.message ?? 'Microphone permission is required.',
      );
      return;
    }

    setState(() {
      _recording = true;
      _partial = '';
      _receivedFinalTranscript = false;
    });
    _pulseController.repeat(reverse: true);
    widget.onPartialTranscript?.call('');

    try {
      if (kIsWeb) {
        await _startPcmCapture();
      } else {
        try {
          await _startStreaming();
        } catch (e) {
          await _startPcmCapture();
        }
      }
    } catch (e) {
      _stopInternal(notify: true);
      widget.onError?.call('Could not start the microphone: $e');
    }
  }

  Future<void> _startStreaming() async {
    _session = await _voiceService.openStreamingSession(
      onPartialTranscript: (text) {
        if (!mounted) return;
        setState(() => _partial = text);
        widget.onPartialTranscript?.call(text);
      },
      onCommittedTranscript: (text) {
        if (text.trim().isNotEmpty) {
          _receivedFinalTranscript = true;
          _partial = text.trim();
        }
      },
      onError: (err) => widget.onError?.call(err),
    );

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen((chunk) {
      _session?.sendChunk(chunk);
    });
  }

  Future<void> _startPcmCapture() async {
    _usingPcmFallback = true;
    _pcmChunks.clear();
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audioSub = stream.listen(_pcmChunks.add);
  }

  Future<void> _stopRecording() async {
    String? transcript;

    if (_session != null) {
      await _audioSub?.cancel();
      _audioSub = null;
      await _recorder.stop();
      await _session!.commit();
      await _session!.close();
      _session = null;
      transcript = _partial.trim().isNotEmpty ? _partial.trim() : null;
    } else if (_usingPcmFallback) {
      await _audioSub?.cancel();
      _audioSub = null;
      await _recorder.stop();
      try {
        final wav = pcm16ToWav(_pcmChunks.toBytes());
        transcript = await _voiceService.transcribeBytes(wav);
      } catch (e) {
        widget.onError?.call('Transcription failed: $e');
      }
      _pcmChunks.clear();
      _usingPcmFallback = false;
    } else {
      await _recorder.stop();
    }

    _stopInternal(notify: true);

    final finalText = _receivedFinalTranscript
        ? _partial
        : (transcript ?? _partial).trim();
    if (finalText.isNotEmpty) {
      widget.onTranscript(finalText);
    } else {
      widget.onError?.call('No speech detected. Try again.');
    }
  }

  void _stopInternal({required bool notify}) {
    _pulseController.stop();
    _pulseController.reset();
    if (mounted) {
      setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.iconSize ?? 24;
    final color = widget.color ?? AppColors.primary;

    return ScaleTransition(
      scale: Tween<double>(begin: 1, end: 1.15).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: IconButton(
        icon: Icon(
          _recording ? Icons.stop_circle : Icons.mic,
          size: size,
          color: _recording ? Colors.red : color,
        ),
        tooltip: _recording ? 'Stop recording' : 'Speak',
        onPressed: widget.enabled ? _toggleRecording : null,
      ),
    );
  }
}
