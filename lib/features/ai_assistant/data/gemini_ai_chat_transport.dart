import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/supabase_config.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'ai_chat_transport.dart';

/// Real AI Chat Transport with multi-tier fallback:
/// OpenRouter (free models: openrouter/free, nemotron, etc.) -> Gemini -> OpenAI -> Claude -> Dynamic Engine.
class GeminiAiChatTransport implements AiChatTransport {
  GeminiAiChatTransport({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  final http.Client Function() _clientFactory;
  StreamSubscription<String>? _streamSub;
  StreamController<String>? _controller;
  bool regenerateNext = false;

  @override
  bool get available =>
      SupabaseConfig.isConfigured || CustomerDataPolicy.allowDemo;

  @override
  void cancel() {
    _streamSub?.cancel();
    _streamSub = null;
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

    return controller.stream;
  }
}
