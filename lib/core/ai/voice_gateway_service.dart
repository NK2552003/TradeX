import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tradex/core/config/env_config.dart';
import 'package:tradex/core/config/supabase_config.dart';

import 'audio_capture_stub.dart' if (dart.library.io) 'audio_capture_io.dart'
    as audio_capture;

/// Authenticated client proxy to the `ai-voice` Supabase Edge Function for
/// OpenAI text-to-speech (`speech`) and audio transcription (`transcribe`).
/// Never embeds provider API keys in production client builds.
class VoiceGatewayService {
  VoiceGatewayService({
    http.Client Function()? clientFactory,
    Uri? Function()? proxyUri,
    Map<String, String> Function()? authHeaders,
    String Function()? devOpenAiKey,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _proxyUri = proxyUri ?? _defaultProxyUri,
       _authHeaders = authHeaders ?? _defaultAuthHeaders,
       _devOpenAiKey = devOpenAiKey ?? (() => EnvConfig.openaiApiKey.trim());

  static final VoiceGatewayService instance = VoiceGatewayService();

  final http.Client Function() _clientFactory;
  final Uri? Function() _proxyUri;
  final Map<String, String> Function() _authHeaders;
  final String Function() _devOpenAiKey;

  static Uri? _defaultProxyUri() {
    if (!SupabaseConfig.isConfigured) return null;
    final base = SupabaseConfig.supabaseUrl.trim();
    if (base.isEmpty) return null;
    return Uri.parse('$base/functions/v1/ai-voice');
  }

  static Map<String, String> _defaultAuthHeaders() {
    final token = SupabaseConfig.client?.auth.currentSession?.accessToken.trim();
    if (token == null || token.isEmpty) {
      throw StateError('Sign in to use AI voice.');
    }
    return <String, String>{
      'Authorization': 'Bearer $token',
      'apikey': SupabaseConfig.supabaseAnonKey,
      'Content-Type': 'application/json',
    };
  }

  /// Whether voice TTS/STT proxying is configured in this environment.
  bool get hasProxy =>
      _proxyUri() != null ||
      (!SupabaseConfig.isConfigured && _devOpenAiKey().isNotEmpty);

  /// Creates a temporary file path on native targets or empty string on web.
  static Future<String> createTempRecordingPath() =>
      audio_capture.createTempAudioPath();

  /// Reads recorded audio bytes from a web blob URL or native file path.
  static Future<Uint8List?> readRecordedBytes(
    String path, {
    http.Client? client,
  }) async {
    if (path.trim().isEmpty) return null;
    if (kIsWeb || path.startsWith('blob:') || path.startsWith('http')) {
      final httpClient = client ?? http.Client();
      final ownsClient = client == null;
      try {
        final response = await httpClient
            .get(Uri.parse(path))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        return null;
      } finally {
        if (ownsClient) httpClient.close();
      }
    }
    return audio_capture.readAndDeleteTempAudio(path);
  }

  /// Synthesizes MP3 speech audio for [text] using [voice] (`nova`, `alloy`,
  /// `echo`, `onyx`, or `shimmer`).
  Future<Uint8List> synthesizeSpeech({
    required String text,
    String voice = 'nova',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) {
      throw StateError('No text to speak.');
    }
    final input = clean.length > 4000 ? clean.substring(0, 4000) : clean;
    final proxy = _proxyUri();
    final client = _clientFactory();
    try {
      if (proxy != null) {
        final response = await client
            .post(
              proxy,
              headers: _authHeaders(),
              body: jsonEncode(<String, dynamic>{
                'action': 'speech',
                'text': input,
                'voice': voice,
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode >= 400) {
          throw StateError(_extractError(response.body, 'Voice playback failed.'));
        }
        if (response.bodyBytes.isEmpty) {
          throw StateError('Voice service returned empty audio.');
        }
        return response.bodyBytes;
      }

      final devKey = _devOpenAiKey();
      if (!SupabaseConfig.isConfigured && devKey.isNotEmpty) {
        final response = await client
            .post(
              Uri.parse('https://api.openai.com/v1/audio/speech'),
              headers: <String, String>{
                'Authorization': 'Bearer $devKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(<String, dynamic>{
                'model': 'tts-1',
                'input': input,
                'voice': voice,
                'response_format': 'mp3',
              }),
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }
        throw StateError(_extractError(response.body, 'Voice playback failed.'));
      }

      throw StateError('Voice service is not configured.');
    } finally {
      client.close();
    }
  }

  /// Transcribes recorded audio bytes via the authenticated `ai-voice` proxy.
  Future<String> transcribeAudio({
    required Uint8List bytes,
    required String mimeType,
    required String filename,
    String? prompt,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('No audio captured. Hold or tap to speak again.');
    }
    final proxy = _proxyUri();
    final client = _clientFactory();
    try {
      if (proxy != null) {
        final response = await client
            .post(
              proxy,
              headers: _authHeaders(),
              body: jsonEncode(<String, dynamic>{
                'action': 'transcribe',
                'audio_base64': base64Encode(bytes),
                'mime_type': mimeType,
                'filename': filename,
                if (prompt != null && prompt.trim().isNotEmpty)
                  'prompt': prompt.trim(),
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode >= 400) {
          throw StateError(
            _extractError(response.body, 'Could not transcribe audio.'),
          );
        }
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['text'] as String? ?? '').trim();
      }

      final devKey = _devOpenAiKey();
      if (!SupabaseConfig.isConfigured && devKey.isNotEmpty) {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
        )
          ..headers['Authorization'] = 'Bearer $devKey'
          ..fields['model'] = 'whisper-1'
          ..fields['response_format'] = 'json'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
        final streamed = await client
            .send(req)
            .timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode >= 400) {
          throw StateError(
            _extractError(response.body, 'Could not transcribe audio.'),
          );
        }
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return (decoded['text'] as String? ?? '').trim();
      }

      throw StateError('Voice transcription requires an active backend connection.');
    } finally {
      client.close();
    }
  }

  static String _extractError(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) return error.trim();
        if (error is Map && error['message'] is String) {
          final msg = (error['message'] as String).trim();
          if (msg.isNotEmpty) return msg;
        }
      }
    } catch (_) {}
    return fallback;
  }
}
