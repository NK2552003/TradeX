import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/copilot/data/copilot_api.dart';
import 'package:tradex/features/copilot/data/voice_controller.dart';

class _QuotaErrorApi extends CopilotApi {
  int runs = 0;
  @override
  Future<Json> getWorkspace() async => {
    ...initialWorkspace(),
    'threads': [
      {'id': 't-quota', 'specialistId': 'analyst', 'messages': []},
    ],
  };

  @override
  Future<Json> action(Json body) async => {'id': 't-quota'};

  @override
  Stream<Json> run(String threadId, Json body, {bool approval = false}) async* {
    runs++;
    yield {'type': 'started', 'messageId': 'msg-quota'};
    yield {
      'type': 'error',
      'message': 'Monthly ai_queries_per_month limit reached.',
    };
  }
}

class DeferredApi extends CopilotApi {
  final reads = <Completer<Json>>[];
  final created = Completer<Json>();
  int creates = 0;
  bool delayReads = false;
  Json state = initialWorkspace();
  @override
  Future<Json> getWorkspace() {
    if (!delayReads) return Future.value(state);
    final pending = Completer<Json>();
    reads.add(pending);
    return pending.future;
  }

  @override
  Future<Json> action(Json body) {
    creates++;
    return created.future;
  }

  @override
  Stream<Json> run(String threadId, Json body, {bool approval = false}) async* {
    yield {'type': 'started', 'messageId': 'message'};
    yield {'type': 'delta', 'text': 'Answer'};
    yield {'type': 'done'};
  }
}

void main() {
  test('closing an inactive overlay keeps another surface’s call locked', () {
    final controller = CopilotController(api: DeferredApi(), autoLoad: false);
    final inactiveVoice = CopilotVoiceController(controller);
    controller.voiceBusy = true;
    inactiveVoice.dispose();
    expect(controller.voiceBusy, isTrue);
    controller.dispose();
  });
  test('rapid sends share one creation and accept only one turn', () async {
    final api = DeferredApi();
    final controller = CopilotController(api: api, autoLoad: false);
    addTearDown(controller.dispose);
    final first = controller.sendPrompt('First');
    expect(await controller.sendPrompt('Second'), isFalse);
    expect(api.creates, 1);
    api.state['threads'] = [
      {'id': 'thread', 'specialistId': 'analyst', 'messages': []},
    ];
    api.created.complete({'id': 'thread'});
    expect(await first, isTrue);
    expect(controller.activeThreadId, 'thread');
    expect(controller.generating, isFalse);
  });

  test('an older reload cannot replace newer workspace data', () async {
    final api = DeferredApi()..delayReads = true;
    final controller = CopilotController(api: api, autoLoad: false);
    addTearDown(controller.dispose);
    final old = controller.reload();
    final current = controller.reload();
    api.reads[1].complete({...initialWorkspace(), 'version': 3});
    await current;
    api.reads[0].complete({...initialWorkspace(), 'version': 2});
    await old;
    expect(controller.workspace.json['version'], 3);
  });

  test('an active voice session keeps its conversation selected', () {
    final controller = CopilotController(autoLoad: false)
      ..activeThreadId = 'call'
      ..voiceBusy = true;
    addTearDown(controller.dispose);
    controller.selectThread('another');
    controller.newConversation();
    expect(controller.activeThreadId, 'call');
  });

  test('sendPrompt blocks local fallback on quota exhaustion and locks subsequent sends', () async {
    AppSession.instance.aiQueriesUsed.value = 0;
    addTearDown(() => AppSession.instance.aiQueriesUsed.value = 0);

    final api = _QuotaErrorApi();
    final controller = CopilotController(api: api, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.reload();
    controller.selectThread('t-quota');

    final accepted = await controller.sendPrompt('Analyze NIFTY support levels');
    expect(accepted, isFalse);
    expect(controller.quotaExceeded, isTrue);
    expect(controller.isAiQuotaBlocked, isTrue);
    expect(controller.error, isNotNull);
    expect(api.runs, 1);

    final secondAttempt = await controller.sendPrompt('Any follow-up');
    expect(secondAttempt, isFalse);
    expect(api.runs, 1);
  });
}
