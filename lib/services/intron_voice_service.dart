import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:nketa/services/voice_audio_cache_service.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Client for Intron Voice AI TTS and STT APIs.
class IntronVoiceService {
  static const String _baseUrl = 'https://infer.voice.intron.io';
  static const String _wsUrl = 'wss://infer.voice.intron.io/stt/v1/stream';

  static const int _sampleRate = 16000;
  static const int _bitRate = 16;
  static const int _numChannels = 1;

  String get _apiKey => dotenv.env['INTRON_API_KEY'] ?? '';
  String get voiceLanguage => dotenv.env['INTRON_VOICE_LANGUAGE'] ?? 'ig';
  String get voiceAccent => dotenv.env['INTRON_VOICE_ACCENT'] ?? 'igbo';
  String get voiceGender => dotenv.env['INTRON_VOICE_GENDER'] ?? 'female';
  String get asrLanguage => dotenv.env['INTRON_ASR_LANGUAGE'] ?? 'ig';

  bool get isConfigured => _apiKey.isNotEmpty;

  Map<String, String> get _authHeaders => {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      };

  /// Generate TTS audio; returns local file path (cached) or remote URL.
  Future<String?> synthesizeSpeech(String text, {bool useCache = true}) async {
    if (!isConfigured || text.trim().isEmpty) return null;

    final trimmed = text.trim();
    if (useCache) {
      final key = VoiceAudioCacheService.cacheKey(
        text: trimmed,
        language: voiceLanguage,
        accent: voiceAccent,
        gender: voiceGender,
      );
      final cached = await VoiceAudioCacheService.getCachedFile(key);
      if (cached != null) return cached.path;
    }

    String? remoteUrl;
    try {
      remoteUrl = await _ttsGenerate(trimmed);
    } catch (e) {
      debugPrint('IntronVoiceService TTS generate failed: $e');
    }

    if (remoteUrl == null) {
      try {
        remoteUrl = await _ttsEnqueueAndPoll(trimmed);
      } catch (e) {
        debugPrint('IntronVoiceService TTS enqueue failed: $e');
      }
    }

    if (remoteUrl == null) return null;

    if (useCache) {
      final localPath = await VoiceAudioCacheService.resolveAudioPath(
        text: trimmed,
        language: voiceLanguage,
        accent: voiceAccent,
        gender: voiceGender,
        remoteUrl: remoteUrl,
      );
      return localPath ?? remoteUrl;
    }
    return remoteUrl;
  }

  Future<String?> _ttsGenerate(String text) async {
    final uri = Uri.parse('$_baseUrl/tts/v1/generate');
    final response = await http
        .post(
          uri,
          headers: _authHeaders,
          body: jsonEncode({
            'text': text,
            'voice_language': voiceLanguage,
            'voice_accent': voiceAccent,
            'voice_gender': voiceGender,
            'output_audio_format': 'opus',
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 503) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final textId = body?['data']?['text_id'] as String?;
      if (textId != null) return _pollTtsStatus(textId);
      return null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data?['processing_status'] == 'TTS_TEXT_AUDIO_GENERATED') {
        return data?['audio_path'] as String?;
      }
    } else {
      throw Exception('TTS generate ${response.statusCode}: ${response.body}');
    }
    return null;
  }

  Future<String?> _ttsEnqueueAndPoll(String text) async {
    final uri = Uri.parse('$_baseUrl/tts/v1/enqueue');
    final response = await http.post(
      uri,
      headers: _authHeaders,
      body: jsonEncode({
        'text': text,
        'voice_language': voiceLanguage,
        'voice_accent': voiceAccent,
        'voice_gender': voiceGender,
        'output_audio_format': 'opus',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('TTS enqueue ${response.statusCode}: ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final textId = body['data']?['text_id'] as String?;
    if (textId == null) return null;
    return _pollTtsStatus(textId);
  }

  Future<String?> _pollTtsStatus(String textId, {int maxAttempts = 30}) async {
    final uri = Uri.parse('$_baseUrl/tts/v1/status/$textId');
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(Duration(seconds: i < 3 ? 1 : 2));
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_apiKey',
      });
      if (response.statusCode != 200) continue;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      final status = data?['processing_status'] as String?;

      if (status == 'TTS_TEXT_AUDIO_GENERATED') {
        return data?['audio_path'] as String?;
      }
      if (status == 'TTS_TEXT_AUDIO_PROCESSING_FAILED') {
        return null;
      }
    }
    return null;
  }

  /// Sync STT fallback for recorded audio file (≤120s).
  Future<String?> transcribeFileSync(File audioFile) async {
    if (!isConfigured) return null;

    final uri = Uri.parse('$_baseUrl/file/v1/upload/sync');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $_apiKey'
      ..fields['audio_file_name'] = 'nketa_recording'
      ..fields['use_language_asr_input'] = asrLanguage
      ..fields['use_disable_llm_corrections'] = 'TRUE'
      ..files.add(await http.MultipartFile.fromPath(
        'audio_file_blob',
        audioFile.path,
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 130));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 503) {
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      final fileId = body?['data']?['file_id'] as String?;
      if (fileId != null) return _pollFileStatus(fileId);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['data']?['audio_transcript'] as String?;
    }

    throw Exception('STT sync ${response.statusCode}: ${response.body}');
  }

  Future<String?> _pollFileStatus(String fileId, {int maxAttempts = 30}) async {
    final uri = Uri.parse('$_baseUrl/file/v1/status/$fileId');
    for (var i = 0; i < maxAttempts; i++) {
      await Future<void>.delayed(Duration(seconds: i < 3 ? 1 : 2));
      final response = await http.get(uri, headers: {
        'Authorization': 'Bearer $_apiKey',
      });
      if (response.statusCode != 200) continue;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data?['processing_status'] == 'FILE_TRANSCRIBED') {
        return data?['audio_transcript'] as String?;
      }
    }
    return null;
  }

  /// Opens a streaming STT session. Caller sends PCM16 chunks via [sendChunk]
  /// and calls [commit] when done.
  Future<IntronStreamingSession> openStreamingSession({
    void Function(String partial)? onPartialTranscript,
    void Function(String finalTranscript)? onCommittedTranscript,
    void Function(String error)? onError,
  }) async {
    if (!isConfigured) {
      throw StateError('Intron API key not configured');
    }

    final query = {
      'sample_rate': '$_sampleRate',
      'bit_rate': '$_bitRate',
      'num_channels': '$_numChannels',
      'use_language_asr_input': asrLanguage,
    };
    final uri = Uri.parse(_wsUrl).replace(queryParameters: query);

    final channel = IOWebSocketChannel.connect(
      uri,
      headers: {'Authorization': 'Bearer $_apiKey'},
    );

    return IntronStreamingSession._(
      channel: channel,
      onPartialTranscript: onPartialTranscript,
      onCommittedTranscript: onCommittedTranscript,
      onError: onError,
    );
  }
}

/// Manages a single Intron STT WebSocket streaming session.
class IntronStreamingSession {
  IntronStreamingSession._({
    required WebSocketChannel channel,
    void Function(String partial)? onPartialTranscript,
    void Function(String finalTranscript)? onCommittedTranscript,
    void Function(String error)? onError,
  })  : _channel = channel,
        _onPartial = onPartialTranscript,
        _onCommitted = onCommittedTranscript,
        _onError = onError {
    _subscription = _channel.stream.listen(
      _handleMessage,
      onError: (Object e) => _onError?.call(e.toString()),
      onDone: () {},
    );
  }

  final WebSocketChannel _channel;
  final void Function(String partial)? _onPartial;
  final void Function(String finalTranscript)? _onCommitted;
  final void Function(String error)? _onError;

  StreamSubscription<dynamic>? _subscription;
  int _chunkId = 0;
  bool _committed = false;
  final _committedCompleter = Completer<void>();

  void _handleMessage(dynamic raw) {
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = map['message_type'] as String?;

      switch (type) {
        case 'PARTIAL_TRANSCRIPT':
          final text = map['transcript'] as String?;
          if (text != null && text.isNotEmpty) _onPartial?.call(text);
          break;
        case 'COMMITTED_TRANSCRIPT':
          final text = map['transcript_text'] as String?;
          if (text != null) _onCommitted?.call(text);
          if (!_committedCompleter.isCompleted) {
            _committedCompleter.complete();
          }
          break;
        case 'AUTHENTICATION_ERROR':
        case 'ERROR':
        case 'INPUT_ERROR':
        case 'QUOTA_EXCEEDED':
        case 'RESOURCE_EXHAUSTED':
          _onError?.call(map['message']?.toString() ?? type ?? 'Unknown error');
          break;
      }
    } catch (e) {
      _onError?.call('Failed to parse STT message: $e');
    }
  }

  void sendChunk(List<int> pcm16Bytes) {
    if (_committed) return;
    _chunkId++;
    _channel.sink.add(jsonEncode({
      'message_type': 'INPUT_AUDIO_CHUNK',
      'audio_base_64': base64Encode(pcm16Bytes),
      'ack_id': _chunkId,
    }));
  }

  Future<void> commit() async {
    if (_committed) return;
    _committed = true;
    _channel.sink.add(jsonEncode({'message_type': 'COMMIT'}));
    await _committedCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  Future<void> close() async {
    await _subscription?.cancel();
    await _channel.sink.close();
  }
}
