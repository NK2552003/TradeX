import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:tradex/core/ai/unified_ai_service.dart';
import 'package:tradex/core/ai/voice_gateway_service.dart';
import 'package:tradex/core/config/env_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/workspace.dart';
import 'copilot_controller.dart';
import 'copilot_feature_connector.dart';

/// Selectable natural-language voice personas for the AI Copilot Voice Assistant.
enum CopilotVoiceModel {
  nova('nova', 'Nova', 'Warm & natural analyst'),
  alloy('alloy', 'Alloy', 'Crisp & executive'),
  echo('echo', 'Echo', 'Calm trading coach'),
  onyx('onyx', 'Onyx', 'Deep institutional desk'),
  shimmer('shimmer', 'Shimmer', 'Clear & expressive');

  const CopilotVoiceModel(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;
}

/// Current conversational stage of the Voice Assistant.
enum CopilotVoiceStage {
  idle('Idle'),
  connecting('Connecting'),
  listening('Listening'),
  thinking('Thinking'),
  speaking('Speaking'),
  muted('Muted');

  const CopilotVoiceStage(this.label);
  final String label;
}

class CopilotVoiceController extends ChangeNotifier {
  CopilotVoiceController(
    this.controller, {
    VoiceGatewayService? voiceGateway,
    SpeechToText? speech,
    AudioRecorder Function()? recorderFactory,
    AudioPlayer Function()? playerFactory,
  }) : _voiceGateway = voiceGateway ?? VoiceGatewayService.instance,
       _speech = speech ?? SpeechToText(),
       _recorderFactory = recorderFactory ?? AudioRecorder.new,
       _playerFactory = playerFactory ?? AudioPlayer.new {
    _epoch = controller.accountEpoch;
    controller.addListener(_accountChanged);
  }

  final CopilotController controller;
  final VoiceGatewayService _voiceGateway;
  final SpeechToText _speech;
  final AudioRecorder Function() _recorderFactory;
  final AudioPlayer Function() _playerFactory;
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _events;
  StreamSubscription<Uint8List>? _microphone;
  Timer? _timer;
  Timer? _speakTimer;
  Timer? _retrySpeechTimer;
  final _audio = BytesBuilder();

  bool active = false;
  bool connecting = false;
  bool microphoneMuted = false;
  bool speakerMuted = false;
  bool minimized = false;
  bool handsFree = true;
  bool recordingTurn = false;
  bool cloudTranscriptionActive = false;
  bool _recording = false;
  bool _speechAvailable = false;
  bool _localNaturalMode = false;
  bool _disposed = false;
  String _turnMimeType = 'audio/webm';
  String _turnFilename = 'speech.webm';

  /// Whether live OpenAI `web_search` is permitted for the active workspace and specialist.
  bool get canWebSearch =>
      controller.workspace.setup['research'] != false &&
      controller.workspace.settings['research'] == true &&
      controller.specialist?.research == true;

  CopilotVoiceModel voiceModel = CopilotVoiceModel.nova;
  CopilotVoiceStage stage = CopilotVoiceStage.idle;

  String? error;
  String userCaption = '';
  String assistantCaption = '';
  int seconds = 0;
  int _session = 0;
  late int _epoch;
  Future<void>? _ending;
  bool _ownsCall = false;
  DateTime? _startedAt;

  /// Transcript turns captured during the current voice session.
  final List<Json> transcript = <Json>[];

  /// Live waveform bars for visual feedback in the Voice Panel.
  List<double> waveform = const <double>[
    0.18,
    0.32,
    0.24,
    0.45,
    0.28,
    0.52,
    0.36,
    0.22,
    0.40,
    0.30,
    0.25,
    0.18,
  ];

  void _accountChanged() {
    if (_epoch == controller.accountEpoch) return;
    _epoch = controller.accountEpoch;
    userCaption = '';
    assistantCaption = '';
    error = null;
    transcript.clear();
    unawaited(end());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void setVoiceModel(CopilotVoiceModel model) {
    if (voiceModel == model) return;
    voiceModel = model;
    if (_channel != null) {
      try {
        _channel!.sink.add(
          jsonEncode({
            'type': 'session.update',
            'voice': model.id,
          }),
        );
      } catch (_) {}
    }
    _notify();
  }

  void toggleHandsFree() {
    handsFree = !handsFree;
    if (!handsFree) {
      if (_speechAvailable) {
        unawaited(_speech.stop());
      }
    } else if (_localNaturalMode &&
        active &&
        !microphoneMuted &&
        !recordingTurn) {
      unawaited(_startSpeechRecognition(_session));
    }
    _notify();
  }

  Future<void> start() async {
    await _ending;
    if (active || connecting || controller.voiceBusy) return;
    final session = ++_session;
    connecting = true;
    stage = CopilotVoiceStage.connecting;
    _ownsCall = true;
    controller.voiceBusy = true;
    error = null;
    seconds = 0;
    userCaption = '';
    assistantCaption = '';
    minimized = false;
    transcript.clear();
    _startedAt = DateTime.now().toUtc();
    _notify();

    final bool hasCustomWsEndpoint = EnvConfig.copilotApiUrl.trim().isNotEmpty;
    if (hasCustomWsEndpoint) {
      try {
        _recorder ??= _recorderFactory();
        final bool hasPerm = await _recorder!.hasPermission();
        final String? id = await controller.ensureThread();
        if (hasPerm && id != null && !_disposed && session == _session) {
          final channel = WebSocketChannel.connect(controller.api.voiceUri);
          _channel = channel;
          await channel.ready.timeout(const Duration(seconds: 3));
          if (_disposed || session != _session) {
            await channel.sink.close();
            return;
          }
          _localNaturalMode = false;
          channel.sink.add(
            jsonEncode({
              'authorization': controller.api.authorization,
              'threadId': id,
              'voice': voiceModel.id,
            }),
          );
          _events = channel.stream.listen(
            (raw) => _event(jsonDecode(raw as String) as Json),
            onDone: () => unawaited(end()),
            onError: (_) {
              _activateNaturalLanguageMode(session);
            },
          );
          return;
        }
      } catch (_) {
        // Fall through to natural-language conversational voice engine.
      }
    }

    await _activateNaturalLanguageMode(session);
  }

  Future<void> _activateNaturalLanguageMode(int session) async {
    if (_disposed || session != _session) return;
    _localNaturalMode = true;
    connecting = false;
    active = true;
    error = null;
    recordingTurn = false;
    cloudTranscriptionActive = false;
    stage = microphoneMuted
        ? CopilotVoiceStage.muted
        : CopilotVoiceStage.listening;

    final String specialistName = controller.specialist?.name ?? 'Atlas';
    assistantCaption =
        'Hi! I’m $specialistName (${voiceModel.label} voice). Ask me about your notes, journal trades, strategies, community posts, or live markets.';
    _startCallTimer();
    _notify();

    await _startSpeechRecognition(session);
  }

  void _startCallTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      if (_disposed || !active) return;
      seconds++;
      _updateWaveform();
      _notify();
    });
  }

  void _updateWaveform() {
    if (microphoneMuted || stage == CopilotVoiceStage.muted) {
      waveform = List<double>.filled(12, 0.12);
      return;
    }
    final double base = switch (stage) {
      CopilotVoiceStage.speaking => 0.48,
      CopilotVoiceStage.listening => 0.28,
      CopilotVoiceStage.thinking => 0.35,
      _ => 0.15,
    };
    waveform = List<double>.generate(12, (int i) {
      final double wave =
          math.sin((seconds * 1.9) + (i * 0.65)) * 0.22 +
          math.cos((seconds * 1.1) - (i * 0.4)) * 0.12;
      return (base + wave).clamp(0.12, 0.96);
    });
  }

  Future<void> _startSpeechRecognition(int session) async {
    if (_disposed || session != _session || microphoneMuted) return;
    _retrySpeechTimer?.cancel();
    if (!handsFree) {
      await _ensureRecorderPermission();
      return;
    }
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (String status) {
          if (_disposed || !active) return;
          if (status == 'done' &&
              handsFree &&
              userCaption.trim().isNotEmpty &&
              stage == CopilotVoiceStage.listening &&
              !recordingTurn) {
            unawaited(submitVoiceTurn(userCaption.trim()));
          }
        },
        onError: (dynamic err) {
          final raw = err is String ? err : '${err.errorMsg ?? err}';
          _handleSpeechError(raw, session);
        },
      );
      if (!_speechAvailable) {
        await _enableCloudTranscriptionFallback(session);
        return;
      }
      cloudTranscriptionActive = false;
      if (!_disposed && active && !microphoneMuted) {
        await _speech.listen(
          onResult: (SpeechRecognitionResult result) {
            if (_disposed || !active || microphoneMuted) return;
            final String spoken = result.recognizedWords.trim();
            if (spoken.isEmpty) return;
            error = null;
            userCaption = spoken;
            stage = CopilotVoiceStage.listening;
            _updateWaveform();
            _notify();
            if (result.finalResult && handsFree) {
              unawaited(submitVoiceTurn(spoken));
            }
          },
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
          ),
        );
      }
    } catch (e) {
      _speechAvailable = false;
      await _enableCloudTranscriptionFallback(session, cause: e);
    }
  }

  void _handleSpeechError(String rawError, int session) {
    if (_disposed || session != _session || !active) return;
    final lower = rawError.toLowerCase().trim();
    if (lower.contains('not-allowed') ||
        lower.contains('permission') ||
        lower.contains('denied')) {
      _speechAvailable = false;
      microphoneMuted = true;
      stage = CopilotVoiceStage.muted;
      error =
          'Microphone permission was denied. Allow microphone access in your browser or system settings and unmute to speak.';
      _updateWaveform();
      _notify();
      return;
    }
    if (lower.contains('audio-capture') ||
        lower.contains('no_microphone') ||
        lower.contains('error_audio')) {
      _speechAvailable = false;
      error = 'No microphone detected. Check your input device and try again.';
      _notify();
      return;
    }
    if (lower.contains('no-speech') ||
        lower.contains('speech_timeout') ||
        lower.contains('no_match')) {
      if (handsFree &&
          !microphoneMuted &&
          stage == CopilotVoiceStage.listening &&
          !recordingTurn) {
        _retrySpeechTimer?.cancel();
        _retrySpeechTimer = Timer(const Duration(milliseconds: 350), () {
          unawaited(_startSpeechRecognition(session));
        });
      }
      return;
    }
    _speechAvailable = false;
    unawaited(_enableCloudTranscriptionFallback(session, cause: rawError));
  }

  Future<bool> _ensureRecorderPermission() async {
    try {
      _recorder ??= _recorderFactory();
      final bool hasPerm = await _recorder!.hasPermission();
      if (!hasPerm) {
        microphoneMuted = true;
        stage = CopilotVoiceStage.muted;
        error =
            'Microphone permission is required for voice calls. Allow microphone access in your browser settings.';
        _updateWaveform();
        _notify();
        return false;
      }
      return true;
    } catch (e) {
      error = 'Microphone check failed: $e';
      _notify();
      return false;
    }
  }

  Future<void> _enableCloudTranscriptionFallback(
    int session, {
    Object? cause,
  }) async {
    if (_disposed || session != _session || !active) return;
    final bool hasPerm = await _ensureRecorderPermission();
    if (!hasPerm || _disposed || session != _session) return;
    if (_voiceGateway.hasProxy) {
      cloudTranscriptionActive = true;
      error = null;
      _notify();
    } else {
      cloudTranscriptionActive = false;
      error = cause == null
          ? 'Browser speech recognition is unavailable. Sign in to use cloud voice transcription.'
          : 'Speech recognition unavailable ($cause).';
      _notify();
    }
  }

  /// Records a spoken turn using OpenAI cloud transcription (`ai-voice`) when
  /// push-to-talk is active or browser speech recognition is unavailable.
  Future<void> toggleRecordedTurn() async {
    if (_disposed || stage == CopilotVoiceStage.thinking) return;
    if (!active && !connecting) {
      await start();
    }
    if (_disposed || !active) return;
    final int session = _session;

    if (recordingTurn) {
      await _finishAndTranscribeRecordedTurn(session);
      return;
    }

    if (microphoneMuted) {
      microphoneMuted = false;
      error = null;
    }
    try {
      if (_speechAvailable) await _speech.stop();
    } catch (_) {}
    try {
      await _player?.stop();
    } catch (_) {}

    final bool hasPerm = await _ensureRecorderPermission();
    if (!hasPerm || _disposed || session != _session) return;

    try {
      AudioEncoder encoder = AudioEncoder.opus;
      String path = '';
      if (kIsWeb) {
        final bool supportsOpus = await _recorder!.isEncoderSupported(
          AudioEncoder.opus,
        );
        if (supportsOpus) {
          encoder = AudioEncoder.opus;
          _turnMimeType = 'audio/webm';
          _turnFilename = 'voice_turn.webm';
        } else {
          final bool supportsAac = await _recorder!.isEncoderSupported(
            AudioEncoder.aacLc,
          );
          if (supportsAac) {
            encoder = AudioEncoder.aacLc;
            _turnMimeType = 'audio/mp4';
            _turnFilename = 'voice_turn.mp4';
          } else {
            encoder = AudioEncoder.wav;
            _turnMimeType = 'audio/wav';
            _turnFilename = 'voice_turn.wav';
          }
        }
      } else {
        encoder = AudioEncoder.aacLc;
        _turnMimeType = 'audio/m4a';
        _turnFilename = 'voice_turn.m4a';
        path = await VoiceGatewayService.createTempRecordingPath();
      }
      await _recorder!.start(RecordConfig(encoder: encoder), path: path);
      if (_disposed || session != _session) {
        await _recorder?.stop();
        return;
      }
      recordingTurn = true;
      error = null;
      stage = CopilotVoiceStage.listening;
      userCaption = 'Listening…';
      _updateWaveform();
      _notify();
    } catch (e) {
      recordingTurn = false;
      error = 'Could not start microphone recording: $e';
      _notify();
    }
  }

  Future<void> _finishAndTranscribeRecordedTurn(int session) async {
    recordingTurn = false;
    stage = CopilotVoiceStage.thinking;
    userCaption = 'Transcribing…';
    _updateWaveform();
    _notify();
    try {
      final String? path = await _recorder?.stop();
      if (_disposed || session != _session) return;
      final Uint8List? bytes = path == null
          ? null
          : await VoiceGatewayService.readRecordedBytes(path);
      if (bytes == null || bytes.length < 200) {
        userCaption = '';
        stage = microphoneMuted
            ? CopilotVoiceStage.muted
            : CopilotVoiceStage.listening;
        error = 'No speech detected. Tap "Tap to speak" and speak clearly.';
        _updateWaveform();
        _notify();
        return;
      }
      final String spoken = await _voiceGateway.transcribeAudio(
        bytes: bytes,
        mimeType: _turnMimeType,
        filename: _turnFilename,
        prompt: 'Trading desk analyst voice call, stocks, crypto, options.',
      );
      if (_disposed || session != _session || !active) return;
      if (spoken.trim().isEmpty) {
        userCaption = '';
        stage = CopilotVoiceStage.listening;
        error = 'Could not transcribe speech. Please try again.';
        _updateWaveform();
        _notify();
        return;
      }
      error = null;
      await submitVoiceTurn(spoken);
    } catch (e) {
      if (_disposed || session != _session) return;
      userCaption = '';
      stage = microphoneMuted
          ? CopilotVoiceStage.muted
          : CopilotVoiceStage.listening;
      error = e is StateError ? e.message : 'Transcription failed: $e';
      _updateWaveform();
      _notify();
    }
  }

  /// Processes a natural-language spoken turn (from microphone recognition or
  /// quick voice command) and streams back the spoken response.
  Future<void> submitVoiceTurn(String utterance) async {
    final String trimmed = utterance.trim();
    if (trimmed.isEmpty || _disposed) return;
    if (!active && !connecting) {
      await start();
    }
    if (_disposed) return;

    final int session = _session;
    try {
      if (_speechAvailable) {
        await _speech.stop();
      }
    } catch (_) {}

    controller.error = null;
    userCaption = trimmed;
    transcript.add(<String, dynamic>{
      'role': 'user',
      'body': trimmed,
    });
    stage = CopilotVoiceStage.thinking;
    assistantCaption = 'Thinking…';
    _updateWaveform();
    _notify();

    String reply = '';
    final String voiceMode = canWebSearch ? 'search' : 'auto';
    try {
      // Also send to the active thread if connected and not currently generating
      final bool wasLocked = controller.voiceBusy;
      if (wasLocked) controller.voiceBusy = false;
      final bool sentToThread =
          controller.connected && !controller.generating
          ? await controller.sendPrompt(trimmed, mode: voiceMode)
          : false;
      if (_ownsCall) controller.voiceBusy = true;

      if (sentToThread) {
        final CopilotMessage? lastMsg =
            controller.activeThread?.messages.lastOrNull;
        final String candidate = lastMsg?.body.trim() ?? '';
        final bool isQuotaOrGatewayError =
            lastMsg?.status == 'error' ||
            lastMsg?.status == 'failed' ||
            controller.error != null ||
            candidate.toLowerCase().contains('ai_queries_per_month') ||
            candidate.toLowerCase().contains('limit reached');
        if (lastMsg != null &&
            !lastMsg.isUser &&
            candidate.isNotEmpty &&
            !isQuotaOrGatewayError) {
          reply = candidate;
        } else if (isQuotaOrGatewayError) {
          controller.error = null;
        }
      }

      if (reply.trim().isEmpty) {
        try {
          final String specialistRole =
              controller.specialist?.role ?? 'Research analyst';
          final String specialistInstructions =
              controller.specialist?.instructions ??
              'Provide concise, natural-language spoken trading insights.';
          final String aiReply = await UnifiedAiService.instance.complete(
            prompt: trimmed,
            systemPrompt:
                'You are ${controller.specialist?.name ?? "Atlas"} ($specialistRole) speaking in a live natural-language voice call (${voiceModel.label} voice). '
                '$specialistInstructions Keep your spoken response conversational, insightful, and clear.',
            maxTokens: 600,
            mode: voiceMode,
            allowWebSearch: canWebSearch,
          );
          if (!aiReply.toLowerCase().contains('ai_queries_per_month') &&
              !aiReply.toLowerCase().contains('limit reached')) {
            reply = aiReply;
          }
        } catch (_) {}
      }

      if (reply.trim().isEmpty) {
        reply = await CopilotFeatureConnector.buildConnectedNaturalLanguageReply(
          trimmed,
          controller,
        );
      }
    } catch (_) {
      controller.error = null;
      reply = await CopilotFeatureConnector.buildConnectedNaturalLanguageReply(
        trimmed,
        controller,
      );
    }

    if (_disposed || session != _session || !active) return;

    // Append to active thread locally if not already added by backend
    _appendLocalThreadMessages(trimmed, reply);

    transcript.add(<String, dynamic>{
      'role': 'assistant',
      'body': _stripMarkdownForSpeech(reply),
    });

    await _streamSpokenCaption(_stripMarkdownForSpeech(reply), session);
  }

  /// Reads an existing assistant message aloud in the Voice Panel.
  Future<void> speakAssistantMessage(String markdownBody) async {
    final String clean = _stripMarkdownForSpeech(markdownBody);
    if (clean.isEmpty) return;
    if (!active) {
      await start();
    }
    if (_disposed || !active) return;
    await _streamSpokenCaption(clean, _session);
  }

  Future<void> _streamSpokenCaption(String cleanText, int session) async {
    _speakTimer?.cancel();
    final List<String> words = cleanText
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;

    stage = CopilotVoiceStage.speaking;
    assistantCaption = '';
    _updateWaveform();
    _notify();

    // Synthesize and stream audible speech via authenticated ai-voice Edge proxy.
    if (!speakerMuted && _voiceGateway.hasProxy) {
      unawaited(_synthesizeAndPlayOpenAiSpeech(cleanText, session));
    }

    int index = 0;
    final Completer<void> done = Completer<void>();
    _speakTimer = Timer.periodic(const Duration(milliseconds: 45), (Timer t) {
      if (_disposed || session != _session || !active) {
        t.cancel();
        if (!done.isCompleted) done.complete();
        return;
      }
      final int step = (words.length > 80) ? 4 : 2;
      final int nextEnd = math.min(index + step, words.length);
      assistantCaption = words.sublist(0, nextEnd).join(' ');
      index = nextEnd;
      _updateWaveform();
      _notify();
      if (index >= words.length) {
        t.cancel();
        stage = microphoneMuted
            ? CopilotVoiceStage.muted
            : CopilotVoiceStage.listening;
        _updateWaveform();
        _notify();
        if (!done.isCompleted) done.complete();
        if (handsFree && !microphoneMuted && _localNaturalMode) {
          unawaited(_startSpeechRecognition(session));
        }
      }
    });
    return done.future;
  }

  /// Synthesizes spoken audio via `ai-voice` Edge Function proxy and plays it through AudioPlayer.
  Future<void> _synthesizeAndPlayOpenAiSpeech(String text, int session) async {
    if (speakerMuted || _disposed || session != _session) return;
    try {
      final Uint8List audioBytes = await _voiceGateway.synthesizeSpeech(
        text: text,
        voice: voiceModel.id,
      );
      if (audioBytes.isNotEmpty) {
        if (_disposed || session != _session || speakerMuted) return;
        _player ??= _playerFactory();
        await _player!.stop();
        await _player!.play(
          BytesSource(audioBytes, mimeType: 'audio/mp3'),
        );
      }
    } on StateError catch (e) {
      if (_disposed || session != _session || speakerMuted) return;
      error = e.message;
      _notify();
    } catch (_) {
      // Audio playback fails gracefully without breaking interactive captions
    }
  }

  void _appendLocalThreadMessages(String prompt, String reply) {
    final List<Json> threads = records(controller.workspace.json['threads']);
    Json? target = threads
        .where((Json t) => t['id'] == controller.activeThreadId)
        .firstOrNull;
    final String stamp = DateTime.now().toUtc().toIso8601String();
    if (target == null) {
      final String newThreadId =
          'voice-${DateTime.now().millisecondsSinceEpoch}';
      target = <String, dynamic>{
        'id': newThreadId,
        'title': prompt.length > 64 ? '${prompt.substring(0, 61)}…' : prompt,
        'specialistId': controller.specialist?.id ?? controller.specialistId,
        'pageId': controller.pageContextId,
        'createdAt': stamp,
        'updatedAt': stamp,
        'status': 'idle',
        'messages': <Json>[],
        'approvals': <Json>[],
        'pinned': false,
      };
      threads.insert(0, target);
      controller.workspace.json['threads'] = threads;
      controller.activeThreadId = newThreadId;
    }
    final List<Json> msgs = records(target['messages']);
    if (msgs.isNotEmpty && msgs.last['role'] == 'assistant') {
      final String lastBody = textOf(msgs.last, 'body').trim().toLowerCase();
      if (lastBody == reply.trim().toLowerCase()) {
        return;
      }
      if (msgs.last['status'] == 'error' ||
          msgs.last['status'] == 'failed' ||
          lastBody.contains('ai_queries_per_month') ||
          lastBody.contains('limit reached')) {
        msgs.last['body'] = reply;
        msgs.last['status'] = 'complete';
        target['messages'] = msgs;
        target['status'] = 'idle';
        target['updatedAt'] = stamp;
        controller.workspace = CopilotWorkspace.fromJson(
          controller.workspace.json,
        );
        controller.error = null;
        return;
      }
    }
    msgs.addAll(<Json>[
      <String, dynamic>{
        'id': 'u-${DateTime.now().microsecondsSinceEpoch}',
        'role': 'user',
        'body': prompt,
        'status': 'complete',
        'createdAt': stamp,
      },
      <String, dynamic>{
        'id': 'a-${DateTime.now().microsecondsSinceEpoch}',
        'role': 'assistant',
        'body': reply,
        'status': 'complete',
        'createdAt': stamp,
      },
    ]);
    target['messages'] = msgs;
    target['status'] = 'idle';
    target['updatedAt'] = stamp;
    controller.workspace = CopilotWorkspace.fromJson(controller.workspace.json);
  }

  static String _stripMarkdownForSpeech(String text) {
    return text
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp(r'^>\s*\[![A-Z]+\]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^\)]+\)'), r'$1')
        .replaceAll(RegExp(r'[#*`|_~>]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _event(Json event) {
    switch (event['type']) {
      case 'copilot.connected':
        connecting = false;
        active = true;
        stage = CopilotVoiceStage.listening;
        _startCallTimer();
      case 'session.updated':
        unawaited(_record());
      case 'conversation.item.input_audio_transcription.completed':
        userCaption = textOf(event, 'transcript');
        if (userCaption.isNotEmpty) {
          transcript.add(<String, dynamic>{
            'role': 'user',
            'body': userCaption,
          });
        }
      case 'response.output_audio_transcript.delta':
        stage = CopilotVoiceStage.speaking;
        assistantCaption += textOf(event, 'delta');
      case 'response.created':
        stage = CopilotVoiceStage.thinking;
        assistantCaption = '';
        _audio.clear();
      case 'response.output_audio.delta':
        stage = CopilotVoiceStage.speaking;
        if (!speakerMuted) _audio.add(base64Decode(textOf(event, 'delta')));
      case 'response.output_audio.done':
        if (assistantCaption.isNotEmpty) {
          transcript.add(<String, dynamic>{
            'role': 'assistant',
            'body': assistantCaption,
          });
        }
        stage = microphoneMuted
            ? CopilotVoiceStage.muted
            : CopilotVoiceStage.listening;
        if (!speakerMuted && _audio.length > 0) {
          unawaited(_play(_audio.takeBytes()));
        }
      case 'input_audio_buffer.speech_started':
        stage = CopilotVoiceStage.listening;
        _audio.clear();
        unawaited(_player?.stop());
      case 'copilot.error':
        error = textOf(event, 'message');
        unawaited(end());
      case 'error':
        error = 'Voice could not process this turn. Try reconnecting.';
    }
    _notify();
  }

  Future<void> _record() async {
    if (_recording || _disposed || _channel == null) return;
    final session = _session;
    _recording = true;
    try {
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 24000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
          autoGain: true,
        ),
      );
      if (_disposed || session != _session) {
        await _recorder?.stop();
        return;
      }
      _microphone = stream.listen((bytes) {
        if (!microphoneMuted && _channel != null) {
          _channel!.sink.add(
            jsonEncode({
              'type': 'input_audio_buffer.append',
              'audio': base64Encode(bytes),
            }),
          );
        }
      });
    } catch (_) {
      await _activateNaturalLanguageMode(session);
    }
  }

  Future<void> _play(Uint8List pcm) async {
    try {
      _player ??= _playerFactory();
      await _player!.play(BytesSource(pcmWave(pcm), mimeType: 'audio/wav'));
    } catch (_) {
      error = 'Audio playback failed. Captions are still available.';
      _notify();
    }
  }

  void toggleMicrophone() {
    microphoneMuted = !microphoneMuted;
    if (microphoneMuted) {
      recordingTurn = false;
      stage = CopilotVoiceStage.muted;
      _channel?.sink.add(jsonEncode({'type': 'input_audio_buffer.clear'}));
      if (_speechAvailable) {
        unawaited(_speech.stop());
      }
      unawaited(_recorder?.stop().catchError((_) => null));
    } else {
      error = null;
      stage = CopilotVoiceStage.listening;
      if (_localNaturalMode && active) {
        unawaited(_startSpeechRecognition(_session));
      }
    }
    _updateWaveform();
    _notify();
  }

  void toggleSpeaker() {
    speakerMuted = !speakerMuted;
    if (speakerMuted) {
      _audio.clear();
      unawaited(_player?.stop());
    }
    _notify();
  }

  void toggleMinimized() {
    minimized = !minimized;
    _notify();
  }

  Future<void> end() => _ending ??= _end().whenComplete(() => _ending = null);

  Future<void> _end() async {
    final channel = _channel;
    final bool wasActive = active;
    final DateTime? started = _startedAt;
    final List<Json> savedTranscript = List<Json>.from(transcript);

    _channel = null;
    _session++;
    active = false;
    connecting = false;
    stage = CopilotVoiceStage.idle;
    if (_ownsCall) controller.voiceBusy = false;
    _ownsCall = false;
    _recording = false;
    recordingTurn = false;
    cloudTranscriptionActive = false;
    _timer?.cancel();
    _speakTimer?.cancel();
    _retrySpeechTimer?.cancel();
    await _events?.cancel();
    _events = null;
    await _microphone?.cancel();
    _microphone = null;
    try {
      if (_speechAvailable) await _speech.stop();
    } catch (_) {}
    try {
      await _recorder?.stop();
    } catch (_) {}
    try {
      await _player?.stop();
    } catch (_) {}
    await channel?.sink.close();
    _audio.clear();

    // Save call record into workspace.calls so Call History displays it
    if (wasActive && !_disposed) {
      final Json callRecord = <String, dynamic>{
        'id': 'call-${DateTime.now().millisecondsSinceEpoch}',
        'threadId': controller.activeThreadId ?? '',
        'specialistId': controller.specialist?.id ?? controller.specialistId,
        'voiceModel': voiceModel.id,
        'status': 'completed',
        'startedAt': (started ?? DateTime.now().toUtc()).toIso8601String(),
        'endedAt': DateTime.now().toUtc().toIso8601String(),
        'transcript': savedTranscript.isNotEmpty
            ? savedTranscript
            : <Json>[
                if (assistantCaption.isNotEmpty)
                  <String, dynamic>{
                    'role': 'assistant',
                    'body': assistantCaption,
                  },
              ],
      };
      final List<Json> calls = records(controller.workspace.json['calls']);
      calls.add(callRecord);
      controller.workspace.json['calls'] = calls;
    }

    _notify();
    if (!_disposed && ! _localNaturalMode) {
      unawaited(controller.reload(quiet: true));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_accountChanged);
    unawaited(
      end().then((_) async {
        try {
          await _recorder?.dispose();
        } catch (_) {}
        try {
          await _player?.dispose();
        } catch (_) {}
      }),
    );
    super.dispose();
  }
}

Uint8List pcmWave(Uint8List pcm) {
  final result = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(result);
  result.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, 36 + pcm.length, Endian.little);
  result.setRange(8, 16, ascii.encode('WAVEfmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 48000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  result.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, pcm.length, Endian.little);
  result.setRange(44, result.length, pcm);
  return result;
}
