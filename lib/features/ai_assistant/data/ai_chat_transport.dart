import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';

abstract interface class AiChatTransport {
  bool get available;
  Stream<String> stream({
    required String threadId,
    required String persona,
    required List<AppAiMessage> messages,
  });
  void cancel();
}

/// Streams authenticated replies from the project's ai-copilot Edge Function.
/// Provider credentials remain on the server. Each run owns its HTTP client.
class HttpAiChatTransport implements AiChatTransport {
  HttpAiChatTransport({
    this._endpoint,
    String? Function()? accessToken,
    http.Client Function()? clientFactory,
    this.idleTimeout = const Duration(seconds: 30),
    this.requestTimeout = const Duration(minutes: 2),
  }) : _accessToken =
           accessToken ??
           (() => SupabaseConfig.client?.auth.currentSession?.accessToken),
       _clientFactory = clientFactory ?? http.Client.new;

  final Uri? _endpoint;
  final String? Function() _accessToken;
  final http.Client Function() _clientFactory;
  final Duration idleTimeout;
  final Duration requestTimeout;
  http.Client? _client;

  Uri? get endpoint =>
      _endpoint ??
      (SupabaseConfig.isConfigured
          ? Uri.parse('${SupabaseConfig.supabaseUrl}/functions/v1/ai-copilot')
          : null);
  @override
  bool get available =>
      endpoint != null && (_accessToken()?.isNotEmpty ?? false);

  @override
  void cancel() {
    _client?.close();
    _client = null;
  }

  @override
  Stream<String> stream({
    required String threadId,
    required String persona,
    required List<AppAiMessage> messages,
  }) async* {
    final target = endpoint;
    final token = _accessToken();
    if (target == null || token == null || token.isEmpty) {
      throw StateError('Sign in to use the configured assistant service.');
    }
    if (target.scheme != 'https') {
      throw StateError('The assistant endpoint must use HTTPS.');
    }
    cancel();
    final client = _clientFactory();
    _client = client;
    var exceededDeadline = false;
    final deadline = Timer(requestTimeout, () {
      exceededDeadline = true;
      client.close();
    });
    try {
      final request = http.Request('POST', target)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          if (SupabaseConfig.isConfigured)
            'apikey': SupabaseConfig.supabaseAnonKey,
        })
        ..body = jsonEncode({
          'thread_id': threadId,
          'persona': persona,
          'system_prompt': UnifiedAiService.buildPersonaSystemPrompt(persona),
          'stream': true,
          'messages': [
            for (final message
                in messages
                    .where(
                      (m) => !m.pending && m.error == null && m.body.isNotEmpty,
                    )
                    .toList()
                    .reversed
                    .take(40)
                    .toList()
                    .reversed)
              {'role': message.role.name, 'content': message.body},
          ],
        });
      final response = await client.send(request).timeout(idleTimeout);
      if (response.statusCode != 200) {
        throw StateError(switch (response.statusCode) {
          401 || 403 => 'Your assistant session was rejected. Sign in again.',
          429 => 'Assistant limit reached. Please try again later.',
          404 || 503 => 'The assistant service is not available yet.',
          _ =>
            'Assistant request failed (${response.statusCode}). Your prompt has been kept.',
        });
      }
      if (!(response.headers['content-type'] ?? '').contains(
        'text/event-stream',
      )) {
        throw const FormatException(
          'The assistant returned an unsupported response.',
        );
      }
      var event = '';
      final data = <String>[];
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(idleTimeout)) {
        if (line.startsWith('event:')) event = line.substring(6).trim();
        if (line.startsWith('data:')) data.add(line.substring(5).trimLeft());
        if (line.isNotEmpty || data.isEmpty) continue;
        final payload = data.join('\n');
        data.clear();
        if (event == 'error') {
          throw StateError(
            'The assistant could not finish its response. Retry when ready.',
          );
        }
        if (payload == '[DONE]' || event == 'done') return;
        final decoded = jsonDecode(payload);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid assistant stream event.');
        }
        if (decoded['type'] == 'error' || decoded['error'] != null) {
          throw StateError(
            'The assistant could not finish its response. Retry when ready.',
          );
        }
        if (decoded['type'] == 'done') return;
        final choices = decoded['choices'];
        String? delta = decoded['delta'] is String
            ? decoded['delta'] as String
            : null;
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final choice = choices.first as Map;
          final part = choice['delta'];
          if (part is Map && part['content'] is String) {
            delta = part['content'] as String;
          }
          if (delta != null && delta.isNotEmpty) yield delta;
          if (choice['finish_reason'] != null) return;
        } else if (delta != null && delta.isNotEmpty) {
          yield delta;
        }
        event = '';
      }
      throw StateError(
        'The assistant connection ended before completion. Retry to continue.',
      );
    } on TimeoutException {
      throw StateError(
        'The assistant timed out. Your prompt and partial response have been kept.',
      );
    } on http.ClientException {
      throw StateError(
        exceededDeadline
            ? 'The assistant timed out. Your prompt and partial response have been kept.'
            : 'The assistant connection failed. Your prompt and partial response have been kept.',
      );
    } finally {
      deadline.cancel();
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }
}
