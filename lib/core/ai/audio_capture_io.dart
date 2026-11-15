import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> createTempAudioPath() async {
  final dir = await getTemporaryDirectory();
  return '${dir.path}/copilot_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
}

Future<Uint8List?> readAndDeleteTempAudio(String path) async {
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  unawaited(file.delete());
  return bytes;
}
