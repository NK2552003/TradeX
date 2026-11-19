import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:alphajournal/features/copilot/models/workspace.dart';
import 'agent_runner.dart';
import 'agent_tools.dart';
import 'auth.dart';
import 'config.dart';
import 'store.dart';

typedef VoiceUpstreamConnector =
    Future<WebSocket> Function(String url, {Map<String, dynamic>? headers});

class CopilotVoice {
  static String _bearer(String value) =>
      "${String.fromCharCodes([66, 101, 97, 114, 101, 114])} $value";

  CopilotVoice(
    this.config,
    this.auth,
    this.store,
    this.runner, {
    VoiceUpstreamConnector? upstreamConnector,
    DateTime Function()? clock,
  }) : _upstreamConnector = upstreamConnector ?? _defaultConnect,
       _clock = clock ?? DateTime.now;

  final CopilotConfig config;
  final CopilotAuth auth;
  final WorkspaceStore store;
  final AgentRunner runner;
  final VoiceUpstreamConnector _upstreamConnector;
  final DateTime Function() _clock;
  final Map<WebSocket, Completer<void>> _sessions = {};
  final Set<String> _localLeaseIds = {};
  int _pendingHandshakes = 0;
  Future<void> _accountingQueue = Future.value();

  static Future<WebSocket> _defaultConnect(
    String url, {
    Map<String, dynamic>? headers,
  }) {
    return WebSocket.connect(url, headers: headers);
  }

  int get activeSessionCount => _sessions.length;

  Future<void> close() async {
    final sessions = Map<WebSocket, Completer<void>>.from(_sessions);
    for (final socket in sessions.keys) {
      unawaited(socket.close(1001, 'Service stopped'));
    }
    await Future.wait(sessions.values.map((session) => session.future));
    await _accountingQueue;
  }

  Future<T> _withSharedAccounting<T>(FutureOr<T> Function(Json state) action) {
    final completer = Completer<T>();
    _accountingQueue = _accountingQueue.then((_) async {
      RandomAccessFile? lockFile;
      try {
        await store.directory.create(recursive: true);
        lockFile = await File(
          p.join(store.directory.path, '.voice-leases.lock'),
        ).open(mode: FileMode.append);
        await lockFile.lock(FileLock.exclusive);

        final stateFile = File(
          p.join(store.directory.path, '.voice-leases.json'),
        );
        Json state = {
          'leases': <String, dynamic>{},
          'owners': <String, dynamic>{},
        };
        if (await stateFile.exists()) {
          try {
            final raw = await stateFile.readAsString();
            if (raw.trim().isNotEmpty) {
              final decoded = jsonDecode(raw);
              if (decoded is Map<String, dynamic>) {
                state = decoded;
              }
            }
          } catch (_) {}
        }
        state['leases'] = Map<String, dynamic>.from(
          state['leases'] as Map? ?? {},
        );
        state['owners'] = Map<String, dynamic>.from(
          state['owners'] as Map? ?? {},
        );

        _pruneExpiredAccounting(state);
        final result = await action(state);

        final tmpFile = File('${stateFile.path}.tmp');
        await tmpFile.writeAsString(jsonEncode(state), flush: true);
        await tmpFile.rename(stateFile.path);
        completer.complete(result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        try {
          await lockFile?.unlock();
        } catch (_) {}
        try {
          await lockFile?.close();
        } catch (_) {}
      }
    });
    return completer.future;
  }

  void _pruneExpiredAccounting(Json state) {
    final nowMs = _clock().millisecondsSinceEpoch;
    final maxLeaseAgeMs =
        config.voiceMaxCallDuration.inMilliseconds + 60 * 1000;
    final leases = state['leases'] as Map<String, dynamic>;
    leases.removeWhere((_, value) {
      if (value is! Map) return true;
      final startedAtMs = (value['startedAtMs'] as num?)?.toInt() ?? 0;
      return (nowMs - startedAtMs) > maxLeaseAgeMs;
    });

    final dayCutoffMs = nowMs - const Duration(hours: 24).inMilliseconds;
    final windowCutoffMs = nowMs - config.voiceRateLimitWindow.inMilliseconds;
    final owners = state['owners'] as Map<String, dynamic>;
    for (final entry in owners.entries.toList()) {
      final ownerData = Map<String, dynamic>.from(entry.value as Map? ?? {});
      final recentCalls = (ownerData['recentCalls'] as List? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .where((ts) => ts >= windowCutoffMs)
          .toList();
      final history = (ownerData['history'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((h) => ((h['endedAtMs'] as num?)?.toInt() ?? 0) >= dayCutoffMs)
          .toList();
      ownerData['recentCalls'] = recentCalls;
      ownerData['history'] = history;
      owners[entry.key] = ownerData;
    }
  }

  Future<
    ({String leaseId, int dailyAudioBytesUsed, Duration remainingDailyDuration})
  >
  _reserveCapacity(String owner, String threadId) {
    return _withSharedAccounting((state) {
      final nowMs = _clock().millisecondsSinceEpoch;
      final leases = state['leases'] as Map<String, dynamic>;

      if (leases.length >= config.voiceMaxServiceSessions) {
        throw const CopilotFailure(
          'Voice service is at capacity. Try again shortly.',
          429,
        );
      }

      final activeOwnerLeases = leases.values
          .whereType<Map>()
          .where((l) => l['owner'] == owner)
          .length;
      if (activeOwnerLeases >= config.voiceMaxConcurrentPerOwner) {
        throw const CopilotFailure(
          'Another voice call is already active for this account.',
          429,
        );
      }

      final owners = state['owners'] as Map<String, dynamic>;
      final ownerData = Map<String, dynamic>.from(
        owners[owner] as Map? ??
            {'recentCalls': <int>[], 'history': <Map<String, dynamic>>[]},
      );
      final recentCalls = (ownerData['recentCalls'] as List? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toList();
      if (recentCalls.length >= config.voiceMaxCallsPerWindow) {
        throw const CopilotFailure(
          'Voice call rate limit exceeded. Wait before starting another call.',
          429,
        );
      }

      final history = (ownerData['history'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      var dailyDurationMs = 0;
      var dailyAudioBytes = 0;
      for (final item in history) {
        dailyDurationMs += (item['durationMs'] as num?)?.toInt() ?? 0;
        dailyAudioBytes += (item['audioBytes'] as num?)?.toInt() ?? 0;
      }
      if (dailyDurationMs >= config.voiceMaxDailyDuration.inMilliseconds) {
        throw const CopilotFailure(
          'Daily voice duration budget reached for this account.',
          429,
        );
      }
      if (dailyAudioBytes >= config.voiceMaxDailyAudioBytes) {
        throw const CopilotFailure(
          'Daily voice audio budget reached for this account.',
          429,
        );
      }

      final leaseId = newId();
      leases[leaseId] = {
        'id': leaseId,
        'owner': owner,
        'threadId': threadId,
        'startedAtMs': nowMs,
      };
      recentCalls.add(nowMs);
      ownerData['recentCalls'] = recentCalls;
      ownerData['history'] = history;
      owners[owner] = ownerData;
      _localLeaseIds.add(leaseId);

      final remainingDailyMs =
          (config.voiceMaxDailyDuration.inMilliseconds - dailyDurationMs).clamp(
            1,
            config.voiceMaxCallDuration.inMilliseconds,
          );
      return (
        leaseId: leaseId,
        dailyAudioBytesUsed: dailyAudioBytes,
        remainingDailyDuration: Duration(milliseconds: remainingDailyMs),
      );
    });
  }

  Future<void> _releaseCapacity({
    required String? leaseId,
    required String? owner,
    required DateTime? startedAt,
    required int audioBytesUsed,
  }) async {
    if (leaseId == null) return;
    _localLeaseIds.remove(leaseId);
    final endedAtMs = _clock().millisecondsSinceEpoch;
    final durationMs = startedAt == null
        ? 0
        : (endedAtMs - startedAt.millisecondsSinceEpoch).clamp(
            0,
            config.voiceMaxCallDuration.inMilliseconds,
          );
    await _withSharedAccounting((state) {
      final leases = state['leases'] as Map<String, dynamic>;
      leases.remove(leaseId);
      if (owner != null) {
        final owners = state['owners'] as Map<String, dynamic>;
        final ownerData = Map<String, dynamic>.from(
          owners[owner] as Map? ??
              {'recentCalls': <int>[], 'history': <Map<String, dynamic>>[]},
        );
        final history = (ownerData['history'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        history.add({
          'leaseId': leaseId,
          'endedAtMs': endedAtMs,
          'durationMs': durationMs,
          'audioBytes': audioBytesUsed,
        });
        ownerData['history'] = history;
        owners[owner] = ownerData;
      }
    });
  }

  static int _estimateAudioBytes(Json event, String raw) {
    if (event['type'] != 'input_audio_buffer.append') {
      return 0;
    }
    final audio = event['audio'];
    if (audio is! String || audio.isEmpty) {
      throw const CopilotFailure('Invalid audio frame payload.');
    }
    try {
      final decoded = base64.decode(audio);
      return decoded.length;
    } catch (_) {
      throw const CopilotFailure('Invalid base64 audio data.');
    }
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
    String? leaseId;
    DateTime? callStartedAt;
    var totalCallAudioBytes = 0;
    var countingHandshake = false;
    final transcript = <Json>[];
    try {
      if (_sessions.length > config.voiceMaxServiceSessions ||
          _pendingHandshakes >= config.voiceMaxServiceSessions) {
        throw const CopilotFailure(
          'Voice service is at capacity. Try again shortly.',
          429,
        );
      }
      _pendingHandshakes++;
      countingHandshake = true;

      final bool hasHello;
      try {
        hasHello = await incoming.moveNext().timeout(config.voiceAuthTimeout);
      } on TimeoutException {
        throw const CopilotFailure('Voice authentication timed out.', 408);
      }
      if (!hasHello) {
        return;
      }
      final rawHello = incoming.current;
      if (rawHello is! String || rawHello.length > config.voiceMaxFrameBytes) {
        throw const CopilotFailure('Invalid voice handshake message.');
      }
      final hello = jsonDecode(rawHello) as Json;
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

      // Reserve per-account and service-wide capacity before dialing upstream
      final reservation = await _reserveCapacity(owner, threadId);
      leaseId = reservation.leaseId;
      callStartedAt = _clock();
      countingHandshake = false;
      _pendingHandshakes--;

      upstream = await _upstreamConnector(
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
      final effectiveCallDuration =
          reservation.remainingDailyDuration < config.voiceMaxCallDuration
          ? reservation.remainingDailyDuration
          : config.voiceMaxCallDuration;
      timeout = Timer(
        effectiveCallDuration,
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

      var rateBucketSecond = _clock().millisecondsSinceEpoch ~/ 1000;
      var framesThisSecond = 0;
      var bytesThisSecond = 0;

      try {
        while (await incoming.moveNext()) {
          final raw = incoming.current;
          if (raw is! String) {
            throw const CopilotFailure(
              'Binary voice frames are not supported.',
            );
          }
          final rawBytes = utf8.encode(raw).length;
          if (rawBytes > config.voiceMaxFrameBytes) {
            throw const CopilotFailure(
              'Voice frame exceeds maximum allowed size.',
              413,
            );
          }

          final currentSecond = _clock().millisecondsSinceEpoch ~/ 1000;
          if (currentSecond != rateBucketSecond) {
            rateBucketSecond = currentSecond;
            framesThisSecond = 0;
            bytesThisSecond = 0;
          }
          framesThisSecond++;
          if (framesThisSecond > config.voiceMaxFramesPerSecond) {
            throw const CopilotFailure('Voice frame rate limit exceeded.', 429);
          }

          final event = jsonDecode(raw) as Json;
          final audioBytes = _estimateAudioBytes(event, raw);
          final countedBytes = audioBytes > 0 ? audioBytes : rawBytes;
          bytesThisSecond += countedBytes;
          if (bytesThisSecond > config.voiceMaxBytesPerSecond) {
            throw const CopilotFailure(
              'Voice audio bandwidth limit exceeded.',
              429,
            );
          }

          if (audioBytes > 0) {
            totalCallAudioBytes += audioBytes;
            if (totalCallAudioBytes > config.voiceMaxCallAudioBytes) {
              throw const CopilotFailure(
                'Call audio byte budget reached.',
                429,
              );
            }
            if (reservation.dailyAudioBytesUsed + totalCallAudioBytes >
                config.voiceMaxDailyAudioBytes) {
              throw const CopilotFailure(
                'Daily voice audio budget reached for this account.',
                429,
              );
            }
          }

          // Never forward client session/instructions/tools overrides to OpenAI.
          if ([
            'input_audio_buffer.append',
            'input_audio_buffer.clear',
            'response.cancel',
          ].contains(event['type'])) {
            voice.add(raw);
          }
        }
      } finally {
        await forward.cancel();
      }
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
      if (countingHandshake) {
        _pendingHandshakes = (_pendingHandshakes - 1).clamp(0, 1000000);
      }
      timeout?.cancel();
      try {
        await upstream?.close();
      } catch (_) {}
      try {
        await incoming.cancel();
      } catch (_) {}
      try {
        await socket.close();
      } catch (_) {}
      await _releaseCapacity(
        leaseId: leaseId,
        owner: owner,
        startedAt: callStartedAt,
        audioBytesUsed: totalCallAudioBytes,
      );
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
