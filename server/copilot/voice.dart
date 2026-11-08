import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:tradex/features/copilot/models/workspace.dart';
import 'agent_runner.dart';
import 'agent_tools.dart';
import 'auth.dart';
import 'config.dart';
import 'store.dart';

class CopilotVoice {
  static String _bearer(String value) =>
      '${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value';
  CopilotVoice(this.config, this.auth, this.store, this.runner);
  final CopilotConfig config;
  final CopilotAuth auth;
  final WorkspaceStore store;
  final AgentRunner runner;
  final Map<WebSocket, Completer<void>> _sessions = {};

  Future<void> close() async {
    final sessions = Map<WebSocket, Completer<void>>.from(_sessions);
    for (final socket in sessions.keys) {
      unawaited(socket.close(1001, 'Service stopped'));
    }
    await Future.wait(sessions.values.map((session) => session.future));
  }

  Future<void> connect(HttpRequest request) async {
    final address = request.connectionInfo?.remoteAddress;
    final socket = await WebSocketTransformer.upgrade(request);
    _sessions[socket] = Completer<void>();
    final incoming = StreamIterator<dynamic>(socket);
    WebSocket? upstream;
    Timer? timeout;
    String? owner;
    String? threadId;
    String? receiptId;
    final transcript = <Json>[];
    try {
      if (!await incoming.moveNext().timeout(const Duration(seconds: 10))) {
        return;
      }
      final hello = jsonDecode(incoming.current as String) as Json;
      owner = await auth.identify(hello['authorization'] as String?, address);
      threadId = textOf(hello, 'threadId');
      final state = await store.read(owner);
      final thread = recordById(state, 'threads', threadId);
      final specialist = recordById(
        state,
        'specialists',
        thread['specialistId'],
      );
      if (state['settings']['paused'] == true) {
        throw const CopilotFailure('Resume the workspace before calling.');
      }
      if (config.key.isEmpty) {
        throw const CopilotFailure('Voice needs OPEN_AI_KEY on the server.');
      }
      upstream = await WebSocket.connect(
        'wss://api.openai.com/v1/realtime?model=${Uri.encodeQueryComponent(config.voiceModel)}',
        headers: {'Authorization': _bearer(config.key)},
      ).timeout(const Duration(seconds: 25));
      final voice = upstream;
      voice.add(
        jsonEncode({
          'type': 'session.update',
          'session': {
            'type': 'realtime',
            'output_modalities': ['audio'],
            'instructions':
                '${instructionsFor(state, specialist, thread)}\nKeep speech concise. Use delegate_work for research or writing that takes time; continue speaking while it runs. Explain that your voice is AI-generated.',
            'audio': {
              'input': {
                'format': {'type': 'audio/pcm', 'rate': 24000},
                'transcription': {'model': 'gpt-4o-mini-transcribe'},
                'turn_detection': {
                  'type': 'server_vad',
                  'create_response': true,
                  'interrupt_response': true,
                },
              },
              'output': {
                'format': {'type': 'audio/pcm', 'rate': 24000},
                'voice': 'marin',
              },
            },
            'tools': [
              {
                'type': 'function',
                'name': 'delegate_work',
                'description':
                    'Delegate research, analysis, or document work to the specialist in this same conversation. Saving and external actions remain subject to owner review in chat.',
                'parameters': {
                  'type': 'object',
                  'properties': {
                    'prompt': {'type': 'string'},
                  },
                  'required': ['prompt'],
                },
              },
            ],
          },
        }),
      );
      final messages = records(
        thread['messages'],
      ).where((m) => textOf(m, 'body').isNotEmpty).toList();
      for (final message in messages.skip(
        (messages.length - 12).clamp(0, messages.length),
      )) {
        voice.add(
          jsonEncode({
            'type': 'conversation.item.create',
            'item': {
              'type': 'message',
              'role': message['role'] == 'user' ? 'user' : 'assistant',
              'content': [
                {
                  'type': message['role'] == 'user' ? 'input_text' : 'text',
                  'text': message['body'],
                },
              ],
            },
          }),
        );
      }
      receiptId = newId();
      await store.change(
        owner,
        (workspace) => (workspace['calls'] as List).add({
          'id': receiptId,
          'threadId': threadId,
          'startedAt': now(),
          'status': 'active',
          'transcript': <Json>[],
        }),
      );
      socket.add(
        jsonEncode({'type': 'copilot.connected', 'receiptId': receiptId}),
      );
      timeout = Timer(
        const Duration(minutes: 30),
        () => socket.close(1000, 'Call limit reached'),
      );
      final forward = voice.listen(
        (raw) {
          final event = jsonDecode(raw as String) as Json;
          if (event['type'] ==
              'conversation.item.input_audio_transcription.completed') {
            transcript.add({
              'role': 'user',
              'body': textOf(event, 'transcript'),
              'createdAt': now(),
            });
          } else if (event['type'] == 'response.output_audio_transcript.done') {
            transcript.add({
              'role': 'assistant',
              'body': textOf(event, 'transcript'),
              'createdAt': now(),
            });
          } else if (event['type'] == 'response.function_call_arguments.done' &&
              event['name'] == 'delegate_work') {
            unawaited(_delegate(owner!, threadId!, voice, event));
          }
          if (socket.readyState == WebSocket.open) socket.add(raw);
        },
        onDone: () => socket.close(),
        onError: (_) => socket.close(1011, 'Voice connection ended'),
      );
      while (await incoming.moveNext()) {
        final raw = incoming.current;
        if (raw is! String || raw.length > 100000) continue;
        final event = jsonDecode(raw) as Json;
        // Never forward client session/instructions/tools overrides to OpenAI.
        if ([
          'input_audio_buffer.append',
          'input_audio_buffer.clear',
          'response.cancel',
        ].contains(event['type'])) {
          voice.add(raw);
        }
      }
      await forward.cancel();
    } catch (error) {
      if (socket.readyState == WebSocket.open) {
        socket.add(
          jsonEncode({
            'type': 'copilot.error',
            'message': error is CopilotFailure
                ? error.message
                : 'The voice connection could not be established. Check microphone access and the voice model.',
          }),
        );
      }
    } finally {
      timeout?.cancel();
      await upstream?.close();
      await incoming.cancel();
      await socket.close();
      if (owner != null && threadId != null && receiptId != null) {
        await store.change(owner, (state) {
          final receipt = recordById(state, 'calls', receiptId!);
          receipt.addAll({
            'endedAt': now(),
            'status': 'ended',
            'transcript': transcript,
          });
          final thread = records(
            state['threads'],
          ).where((t) => t['id'] == threadId).firstOrNull;
          if (thread != null) {
            final current = recordById(state, 'threads', threadId!);
            (current['messages'] as List).addAll(
              transcript.map(
                (t) => {
                  ...t,
                  'id': newId(),
                  'status': 'complete',
                  'callId': receiptId,
                },
              ),
            );
            // Inject call context on the next text turn as well as displaying it.
            current['callContext'] = transcript;
          }
        });
      }
      _sessions.remove(socket)?.complete();
    }
  }

  Future<void> _delegate(
    String owner,
    String threadId,
    WebSocket voice,
    Json event,
  ) async {
    var result =
        'Work completed. See the conversation for results or approval requests.';
    try {
      final arguments = parseArguments(event);
      await runner.run(owner, threadId, prompt: textOf(arguments, 'prompt'));
      final thread = recordById(await store.read(owner), 'threads', threadId);
      result = jsonEncode({
        'status': thread['status'],
        'answer': records(thread['messages']).last['body'],
      });
    } catch (_) {
      result =
          'Another task is active or work failed. Review the conversation.';
    }
    if (voice.readyState != WebSocket.open) return;
    voice.add(
      jsonEncode({
        'type': 'conversation.item.create',
        'item': {
          'type': 'function_call_output',
          'call_id': event['call_id'],
          'output': result,
        },
      }),
    );
    voice.add(jsonEncode({'type': 'response.create'}));
  }
}
