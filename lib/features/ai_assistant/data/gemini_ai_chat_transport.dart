import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'ai_chat_transport.dart';

/// Production-grade AI Chat Transport:
/// - When authenticated with Supabase: Routes via UnifiedAiService ('ai-gateway' Edge Function) with atomic quota reservation, admin access enforcement, and server-side turn persistence.
/// - Fallback: Multi-tier UnifiedAiService (OpenAI gpt-4.1-mini / gpt-4o-mini -> OpenRouter -> Gemini -> Claude -> Dynamic Engine).
class GeminiAiChatTransport implements AiChatTransport {
  GeminiAiChatTransport({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  StreamSubscription<dynamic>? _streamSub;
  StreamController<String>? _controller;
  http.Client? _activeHttpClient;
  bool regenerateNext = false;

  @override
  bool get available =>
      SupabaseConfig.isConfigured || CustomerDataPolicy.allowDemo;

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
    final aiService = UnifiedAiService(clientFactory: _clientFactory);
    final sourceStream = aiService.stream(
      messages: messages,
      persona: persona,
      threadId: threadId,
      requestKind: regenerateNext ? 'regenerate' : 'chat',
    );
    regenerateNext = false;

    _streamSub = sourceStream.listen(
      (chunk) {
        if (!controller.isClosed) {
          controller.add(chunk);
        }
      },
      onError: (e) {
        if (!controller.isClosed) {
          if (SupabaseConfig.isConfigured) {
            controller.addError(e);
            controller.close();
            return;
          }
          // Provide dynamic fallback text on unhandled error
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
