import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/data/ai_chat_transport.dart';

class ControlledTransport implements AiChatTransport {
  final runs = <StreamController<String>>[];
  int cancellations = 0;
  @override
  bool get available => true;
  @override
  void cancel() {
    cancellations++;
  }

  @override
  Stream<String> stream({
    required String threadId,
    required String persona,
    required List<AppAiMessage> messages,
  }) {
    final controller = StreamController<String>();
    runs.add(controller);
    return controller.stream;
  }
}

void main() {
  setUp(() {
    CustomerDataPolicy.allowDemo = false;
  });
  tearDown(() {
    CustomerDataPolicy.allowDemo = true;
  });
  const prompt = AppAiMessage(
    id: 'prompt',
    role: AppAiRole.user,
    body: 'Review risk',
  );
  HttpAiChatTransport service(http.Client client) => HttpAiChatTransport(
    endpoint: Uri.parse('https://example.com/functions/v1/ai-copilot'),
    accessToken: () => 'session-jwt',
    clientFactory: () => client,
  );

  test('authenticated SSE produces deltas and explicit completion', () async {
    http.Request? sent;
    final transport = service(
      MockClient((request) async {
        sent = request;
        return http.Response(
          'data: {"delta":"Review "}\n\ndata: {"choices":[{"delta":{"content":"risk"}}]}\n\ndata: [DONE]\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );
    expect(
      await transport
          .stream(threadId: 'thread', persona: 'swing', messages: [prompt])
          .toList(),
      ['Review ', 'risk'],
    );
    expect(sent!.headers['Authorization'], 'Bearer session-jwt');
    expect((jsonDecode(sent!.body) as Map)['messages'], [
      {'role': 'user', 'content': 'Review risk'},
    ]);
    expect(sent!.followRedirects, isFalse);
  });
  for (final code in [401, 429, 503]) {
    test('service status $code fails without a fabricated reply', () async {
      final transport = service(
        MockClient((_) async => http.Response('unavailable', code)),
      );
      await expectLater(
        transport
            .stream(threadId: 'thread', persona: 'swing', messages: [prompt])
            .toList(),
        throwsStateError,
      );
    });
  }
  test('a truncated response is not accepted as complete', () async {
    final transport = service(
      MockClient(
        (_) async => http.Response(
          'data: {"delta":"partial"}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    final pieces = <String>[];
    await expectLater(
      transport
          .stream(threadId: 'thread', persona: 'swing', messages: [prompt])
          .forEach(pieces.add),
      throwsStateError,
    );
    expect(pieces, ['partial']);
  });
  test('idle provider times out', () async {
    final controller = StreamController<List<int>>();
    final transport = HttpAiChatTransport(
      endpoint: Uri.parse('https://example.com/ai'),
      accessToken: () => 'jwt',
      idleTimeout: const Duration(milliseconds: 15),
      clientFactory: () => MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        ),
      ),
    );
    await expectLater(
      transport
          .stream(threadId: 'thread', persona: 'swing', messages: [prompt])
          .toList(),
      throwsStateError,
    );
    await controller.close();
  });
  test(
    'account changes clear conversation content and cancel the previous request',
    () async {
      var actor = 'first-user';
      final transport = ControlledTransport();
      final repo = AiAssistantRepository(
        transport: transport,
        actorId: () => actor,
      );
      addTearDown(repo.dispose);
      repo.sendPrompt('Private first-user prompt');
      transport.runs.single.add('Private answer');
      await Future<void>.delayed(Duration.zero);
      actor = 'second-user';
      expect(repo.messages, isEmpty);
      expect(repo.generating, isFalse);
      transport.runs.single.add('Late data');
      await Future<void>.delayed(Duration.zero);
      expect(repo.messages, isEmpty);
      await transport.runs.single.close();
    },
  );

  test('unconfigured customer service keeps the conversation empty', () {
    final repo = AiAssistantRepository();
    addTearDown(repo.dispose);
    repo.sendPrompt('Do not discard into a fake reply');
    expect(repo.messages, isEmpty);
    expect(repo.generating, isFalse);
  });
  test(
    'real deltas are visible, duplicate sends are rejected, and completion settles',
    () async {
      final transport = ControlledTransport();
      final repo = AiAssistantRepository(transport: transport);
      addTearDown(repo.dispose);
      repo.sendPrompt('Review this setup');
      repo.sendPrompt('Duplicate while generating');
      expect(
        repo.messages.where((m) => m.role == AppAiRole.user),
        hasLength(1),
      );
      transport.runs.single.add('Real streamed content');
      await Future<void>.delayed(Duration.zero);
      expect(repo.messages.last.body, 'Real streamed content');
      expect(repo.messages.last.pending, isTrue);
      await transport.runs.single.close();
      await Future<void>.delayed(Duration.zero);
      expect(repo.generating, isFalse);
      expect(repo.messages.last.pending, isFalse);
      expect(repo.latestActions, isEmpty);
    },
  );
  test(
    'cancel preserves partial text and rejects late events after changing threads',
    () async {
      final transport = ControlledTransport();
      final repo = AiAssistantRepository(transport: transport);
      addTearDown(repo.dispose);
      repo.sendPrompt('Old conversation');
      final oldId = repo.activeThreadId;
      transport.runs.single.add('Partial');
      await Future<void>.delayed(Duration.zero);
      repo.newThread();
      transport.runs.single.add('Late unwanted text');
      await Future<void>.delayed(Duration.zero);
      expect(repo.messages, isEmpty);
      repo.selectThread(oldId);
      expect(repo.messages.last.body, 'Partial');
      expect(repo.messages.last.pending, isFalse);
      expect(repo.messages.last.error, contains('stopped'));
      expect(transport.cancellations, greaterThan(0));
      await transport.runs.single.close();
    },
  );
  test(
    'failed stream preserves prompt and partial text and supports regeneration',
    () async {
      final transport = ControlledTransport();
      final repo = AiAssistantRepository(transport: transport);
      addTearDown(repo.dispose);
      repo.sendPrompt('Retain this prompt');
      transport.runs.single.add('Partial answer');
      transport.runs.single.addError(StateError('Provider failed'));
      await Future<void>.delayed(Duration.zero);
      expect(repo.generationError, contains('Provider failed'));
      expect(repo.messages.last.body, 'Partial answer');
      expect(repo.messages.first.body, 'Retain this prompt');
      repo.regenerate(repo.messages.last);
      expect(transport.runs, hasLength(2));
      transport.runs.last.add('Retried answer');
      await transport.runs.last.close();
      await Future<void>.delayed(Duration.zero);
      expect(repo.messages.last.body, 'Retried answer');
      expect(repo.messages.last.error, isNull);
      await transport.runs.first.close();
    },
  );
}
