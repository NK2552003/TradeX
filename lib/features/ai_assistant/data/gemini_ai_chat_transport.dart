import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'ai_chat_transport.dart';

/// Production-grade AI Chat Transport:
/// - When authenticated with Supabase: Streams via server-side 'ai-chat' Edge Function (using server-side OPEN_AI_KEY, gpt-4.1-mini, quota enforcement, and portfolio context authorization).
/// - Fallback: Multi-tier UnifiedAiService (OpenAI gpt-4.1-mini / gpt-4o-mini -> OpenRouter -> Gemini -> Claude -> Dynamic Engine).
class GeminiAiChatTransport implements AiChatTransport {
  GeminiAiChatTransport({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  StreamSubscription<dynamic>? _streamSub;
  StreamController<String>? _controller;
  http.Client? _activeHttpClient;

  @override
  bool get available => true;

  @override
  void cancel() {
    _streamSub?.cancel();
    _streamSub = null;
    _activeHttpClient?.close();
    _activeHttpClient = null;
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
    _controller = null;
  }

  @override
  Stream<String> stream({
    required String threadId,
    required String persona,
    required List<AppAiMessage> messages,
  }) {
    cancel();
    final controller = StreamController<String>();
    _controller = controller;

    unawaited(_executeStream(controller, threadId, persona, messages));
    return controller.stream;
  }

  Future<void> _executeStream(
    StreamController<String> controller,
    String threadId,
    String persona,
    List<AppAiMessage> messages,
  ) async {
    final session = SupabaseConfig.client?.auth.currentSession;
    final user = SupabaseConfig.client?.auth.currentUser;

    if (SupabaseConfig.isConfigured && session != null && session.accessToken.isNotEmpty && user != null) {
      final client = _clientFactory();
      _activeHttpClient = client;
      try {
        final lastMsg = messages.where((m) => m.role == AppAiRole.user).lastOrNull?.body ?? '';
        final edgeUrl = Uri.parse('${SupabaseConfig.supabaseUrl.replaceAll(RegExp(r"/+\$"), "")}/functions/v1/ai-chat');
        final request = http.Request('POST', edgeUrl)
          ..headers.addAll({
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
            'Accept': 'text/event-stream',
          })
          ..body = jsonEncode({
            'threadId': threadId,
            'persona': persona,
            'message': lastMsg,
          });

        final response = await client.send(request);
        if (response.statusCode == 200) {
          bool streamedAny = false;
          final lineStream = response.stream.transform(utf8.decoder).transform(const LineSplitter());
          await for (final line in lineStream) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) continue;
            final jsonStr = trimmed.substring(5).trim();
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final text = data['text']?.toString();
              if (text != null && text.isNotEmpty) {
                streamedAny = true;
                if (!controller.isClosed) {
                  controller.add(text);
                }
              }
            } catch (_) {}
          }
          if (streamedAny && !controller.isClosed) {
            controller.close();
            return;
          }
        }
      } catch (e) {
        debugPrint('[GeminiAiChatTransport] Edge ai-chat streaming fallback: $e');
      } finally {
        _activeHttpClient = null;
      }
    }

    // Fallback to UnifiedAiService (OpenAI gpt-4.1-mini -> OpenRouter -> Gemini -> Dynamic Engine)
    final aiService = UnifiedAiService(clientFactory: _clientFactory);
    final sourceStream = aiService.stream(messages: messages, persona: persona);

    _streamSub = sourceStream.listen(
      (chunk) {
        if (!controller.isClosed) {
          controller.add(chunk);
        }
      },
      onError: (e) {
        if (!controller.isClosed) {
          controller.add(
            '\n\n${UnifiedAiService.generateLocalTradingAnalysis(prompt: messages.isNotEmpty ? messages.last.body : 'Market Analysis', persona: persona)}',
          );
          controller.close();
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: false,
    );
  }
}
