import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/workspace.dart';
import 'copilot_controller.dart';

class CopilotVoiceController extends ChangeNotifier {
  CopilotVoiceController(this.controller) {
    _epoch = controller.accountEpoch;
    controller.addListener(_accountChanged);
  }
  final CopilotController controller;
  AudioRecorder? _recorder;
  AudioPlayer? _player;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _events;
  StreamSubscription<Uint8List>? _microphone;
  Timer? _timer;
  final _audio = BytesBuilder();
  bool active = false;
  bool connecting = false;
  bool microphoneMuted = false;
  bool speakerMuted = false;
  bool minimized = false;
  bool _recording = false;
  bool _disposed = false;
  String? error;
  String userCaption = '';
  String assistantCaption = '';
  int seconds = 0;
  int _session = 0;
  late int _epoch;
  Future<void>? _ending;
  bool _ownsCall = false;

  void _accountChanged() {
    if (_epoch == controller.accountEpoch) return;
    _epoch = controller.accountEpoch;
    userCaption = '';
    assistantCaption = '';
    error = null;
    unawaited(end());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    await _ending;
    if (active || connecting || controller.voiceBusy) return;
    final session = ++_session;
    connecting = true;
    _ownsCall = true;
    controller.voiceBusy = true;
    error = null;
    seconds = 0;
    userCaption = '';
    assistantCaption = '';
    minimized = false;
    _notify();
    try {
      _recorder ??= AudioRecorder();
      if (!await _recorder!.hasPermission()) {
        throw StateError('Microphone permission is required to start a call.');
      }
      final id = await controller.ensureThread();
      if (id == null) {
        throw StateError(controller.error ?? 'Create a conversation first.');
      }
      if (_disposed || session != _session) return;
      final channel = WebSocketChannel.connect(controller.api.voiceUri);
      _channel = channel;
      await channel.ready;
      if (_disposed || session != _session) {
        await channel.sink.close();
        return;
      }
      channel.sink.add(
        jsonEncode({
          'authorization': controller.api.authorization,
          'threadId': id,
        }),
      );
      _events = channel.stream.listen(
        (raw) => _event(jsonDecode(raw as String) as Json),
        onDone: () => unawaited(end()),
        onError: (_) {
          error = 'The call connection ended.';
          unawaited(end());
        },
      );
    } catch (failure) {
      error = '$failure';
      await end();
    }
  }

  void _event(Json event) {
    switch (event['type']) {
      case 'copilot.connected':
        connecting = false;
        active = true;
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          seconds++;
          _notify();
        });
      case 'session.updated':
        unawaited(_record());
      case 'conversation.item.input_audio_transcription.completed':
        userCaption = textOf(event, 'transcript');
      case 'response.output_audio_transcript.delta':
        assistantCaption += textOf(event, 'delta');
      case 'response.created':
        assistantCaption = '';
        _audio.clear();
      case 'response.output_audio.delta':
        if (!speakerMuted) _audio.add(base64Decode(textOf(event, 'delta')));
      case 'response.output_audio.done':
        if (!speakerMuted && _audio.length > 0) {
          unawaited(_play(_audio.takeBytes()));
        }
      case 'input_audio_buffer.speech_started':
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
      error = 'This device could not open the microphone.';
      await end();
    }
  }

  Future<void> _play(Uint8List pcm) async {
    try {
      _player ??= AudioPlayer();
      await _player!.play(BytesSource(pcmWave(pcm), mimeType: 'audio/wav'));
    } catch (_) {
      error = 'Audio playback failed. Captions are still available.';
      _notify();
    }
  }

  void toggleMicrophone() {
    microphoneMuted = !microphoneMuted;
    if (microphoneMuted) {
      _channel?.sink.add(jsonEncode({'type': 'input_audio_buffer.clear'}));
    }
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
    _channel = null;
    _session++;
    active = false;
    connecting = false;
    if (_ownsCall) controller.voiceBusy = false;
    _ownsCall = false;
    _recording = false;
    _timer?.cancel();
    await _events?.cancel();
    _events = null;
    await _microphone?.cancel();
    _microphone = null;
    await _recorder?.stop();
    await _player?.stop();
    await channel?.sink.close();
    _audio.clear();
    _notify();
    if (!_disposed) unawaited(controller.reload(quiet: true));
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_accountChanged);
    unawaited(
      end().then((_) async {
        await _recorder?.dispose();
        await _player?.dispose();
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
