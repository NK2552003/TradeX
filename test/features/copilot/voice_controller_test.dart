import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tradex/core/ai/voice_gateway_service.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/app_session.dart';
import 'package:tradex/features/copilot/copilot.dart';
import 'package:tradex/features/copilot/data/copilot_api.dart';
import 'package:tradex/features/copilot/data/voice_controller.dart';
import 'package:tradex/features/copilot/presentation/voice_panel.dart';

class _RecordingCopilotApi extends CopilotApi {
  final Json state = initialWorkspace();
  final List<Json> runPayloads = <Json>[];

  @override
  Future<Json> getWorkspace() async => state;

  @override
  Future<Json> action(Json body) async {
    if (body['action'] == 'thread.create') {
      final thread = <String, dynamic>{
        'id': 'thread-voice',
        'specialistId': body['specialistId'] ?? 'analyst',
        'title': 'New conversation',
        'status': 'idle',
        'messages': <Json>[],
        'approvals': <Json>[],
      };
      (state['threads'] as List).insert(0, thread);
      return thread;
    }
    return <String, dynamic>{};
  }

  @override
  Stream<Json> run(
    String threadId,
    Json body, {
    bool approval = false,
  }) async* {
    runPayloads.add(body);
    yield {'type': 'started', 'messageId': 'msg-1'};
    yield {'type': 'delta', 'text': 'Live NVDA price is up 2.1% today.'};
    yield {'type': 'done'};
  }
}

class _FakeSpeech extends Fake implements SpeechToText {
  _FakeSpeech({this.available = false, this.errorOnInit});

  final bool available;
  final String? errorOnInit;
  void Function(SpeechRecognitionError)? onErrorCallback;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = const Duration(seconds: 2),
    List<SpeechConfigOption>? options,
  }) async {
    onErrorCallback = onError;
    if (errorOnInit != null && onError != null) {
      onError(SpeechRecognitionError(errorOnInit!, true));
    }
    return available;
  }

  @override
  Future<dynamic> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate,
    SpeechListenOptions? listenOptions,
  }) async {}

  @override
  Future<void> stop() async {}
}

class _FakeRecorder extends Fake implements AudioRecorder {
  _FakeRecorder({this.permission = true});

  final bool permission;
  bool started = false;
  bool stopped = false;

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    started = true;
  }

  @override
  Future<String?> stop() async {
    stopped = true;
    return null;
  }

  @override
  Future<void> dispose() async {}
}

class _FakePlayer extends Fake implements AudioPlayer {
  final List<BytesSource> playedSources = <BytesSource>[];
  bool stopped = false;

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    if (source is BytesSource) playedSources.add(source);
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'VoiceGatewayService proxies TTS and transcription with Supabase JWT and zero client API keys',
    () async {
      final calls = <Map<String, dynamic>>[];
      final gateway = VoiceGatewayService(
        proxyUri: () => Uri.parse('https://demo.supabase.co/functions/v1/ai-voice'),
        authHeaders: () => <String, String>{
          'Authorization': 'Bearer user-jwt',
          'apikey': 'anon-key',
          'Content-Type': 'application/json',
        },
        devOpenAiKey: () => '',
        clientFactory: () => MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          calls.add(<String, dynamic>{
            'url': request.url.toString(),
            'auth': request.headers['Authorization'],
            'apikey': request.headers['apikey'],
            'body': body,
          });
          if (body['action'] == 'speech') {
            return http.Response.bytes([1, 2, 3, 4], 200);
          }
          if (body['action'] == 'transcribe') {
            return http.Response(jsonEncode({'text': 'Buy NVDA calls'}), 200);
          }
          return http.Response(jsonEncode({'error': 'bad action'}), 400);
        }),
      );

      final mp3 = await gateway.synthesizeSpeech(
        text: 'Market rally continues.',
        voice: 'onyx',
      );
      expect(mp3, Uint8List.fromList([1, 2, 3, 4]));
      expect(calls.first['auth'], 'Bearer user-jwt');
      expect(calls.first['apikey'], 'anon-key');
      expect(calls.first['body']['action'], 'speech');
      expect(calls.first['body']['voice'], 'onyx');

      final transcript = await gateway.transcribeAudio(
        bytes: Uint8List.fromList([9, 8, 7]),
        mimeType: 'audio/webm',
        filename: 'turn.webm',
      );
      expect(transcript, 'Buy NVDA calls');
      expect(calls.last['body']['action'], 'transcribe');
      expect(calls.last['body']['mime_type'], 'audio/webm');
    },
  );

  test(
    'CopilotVoiceController passes mode=search when research is allowed and plays TTS via proxy',
    () async {
      final api = _RecordingCopilotApi();
      final controller = CopilotController(api: api, autoLoad: false);
      addTearDown(controller.dispose);
      await controller.reload();

      final player = _FakePlayer();
      final recorder = _FakeRecorder(permission: true);
      final gateway = VoiceGatewayService(
        proxyUri: () => Uri.parse('https://demo.supabase.co/functions/v1/ai-voice'),
        authHeaders: () => <String, String>{
          'Authorization': 'Bearer user-jwt',
          'apikey': 'anon-key',
          'Content-Type': 'application/json',
        },
        devOpenAiKey: () => '',
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes([11, 22, 33], 200),
        ),
      );

      final voice = CopilotVoiceController(
        controller,
        voiceGateway: gateway,
        speech: _FakeSpeech(available: false),
        recorderFactory: () => recorder,
        playerFactory: () => player,
      );
      addTearDown(voice.dispose);

      await voice.start();
      // Browser STT unavailable, but recorder has permission + proxy -> cloud fallback ready!
      expect(voice.cloudTranscriptionActive, isTrue);
      expect(voice.error, isNull);

      await voice.submitVoiceTurn('What is NVDA trading at right now?');
      expect(api.runPayloads, isNotEmpty);
      expect(api.runPayloads.last['mode'], 'search');

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(player.playedSources, isNotEmpty);
      expect(player.playedSources.first.mimeType, 'audio/mp3');
    },
  );

  test(
    'CopilotVoiceController surfaces microphone permission denial instead of swallowing errors',
    () async {
      final api = _RecordingCopilotApi();
      final controller = CopilotController(api: api, autoLoad: false);
      addTearDown(controller.dispose);
      await controller.reload();

      final voice = CopilotVoiceController(
        controller,
        voiceGateway: VoiceGatewayService(
          proxyUri: () => Uri.parse('https://demo.supabase.co/functions/v1/ai-voice'),
          authHeaders: () => const <String, String>{},
          devOpenAiKey: () => '',
        ),
        speech: _FakeSpeech(available: false, errorOnInit: 'not-allowed'),
        recorderFactory: () => _FakeRecorder(permission: false),
        playerFactory: _FakePlayer.new,
      );
      addTearDown(voice.dispose);

      await voice.start();
      expect(voice.microphoneMuted, isTrue);
      expect(voice.stage, CopilotVoiceStage.muted);
      expect(voice.error, contains('Microphone permission'));
    },
  );

  testWidgets('CopilotVoicePanel shows Tap to speak when cloud transcription fallback is active', (
    tester,
  ) async {
    final api = _RecordingCopilotApi();
    final controller = CopilotController(api: api, autoLoad: false);
    addTearDown(controller.dispose);
    await controller.reload();

    final voice = CopilotVoiceController(
      controller,
      voiceGateway: VoiceGatewayService(
        proxyUri: () => Uri.parse('https://demo.supabase.co/functions/v1/ai-voice'),
        authHeaders: () => <String, String>{'Authorization': 'Bearer t'},
        devOpenAiKey: () => '',
      ),
      speech: _FakeSpeech(available: false),
      recorderFactory: () => _FakeRecorder(permission: true),
      playerFactory: _FakePlayer.new,
    );
    addTearDown(voice.dispose);

    await voice.start();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CopilotVoicePanel(voice: voice, name: 'Atlas'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tap to speak'), findsOneWidget);
    expect(find.text('End call'), findsOneWidget);

    await voice.end();
    await tester.pump();
  });

  test(
    'CopilotVoiceController blocks voice start and turn submission when AI quota is exhausted',
    () async {
      final previousTier = AppSession.instance.tier.value;
      AppSession.instance.changeTier(AppTier.free);
      AppSession.instance.aiQueriesUsed.value = 5;
      addTearDown(() {
        AppSession.instance.aiQueriesUsed.value = 0;
        AppSession.instance.changeTier(previousTier);
      });

      final api = _RecordingCopilotApi();
      final controller = CopilotController(api: api, autoLoad: false);
      addTearDown(controller.dispose);
      await controller.reload();

      final voice = CopilotVoiceController(
        controller,
        voiceGateway: VoiceGatewayService(
          proxyUri: () => Uri.parse('https://demo.supabase.co/functions/v1/ai-voice'),
          authHeaders: () => const <String, String>{},
          devOpenAiKey: () => '',
        ),
        speech: _FakeSpeech(available: true),
        recorderFactory: () => _FakeRecorder(permission: true),
        playerFactory: _FakePlayer.new,
      );
      addTearDown(voice.dispose);

      await voice.start();
      expect(voice.active, isFalse);
      expect(voice.error, contains('quota'));

      await voice.submitVoiceTurn('Check NIFTY levels');
      expect(voice.transcript, isEmpty);
      expect(api.runPayloads, isEmpty);
    },
  );
}
