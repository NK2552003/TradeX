import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<bool> downloadBytesFileImpl(
  Uint8List bytes, {
  required String filename,
  required String mimeType,
}) async {
  final safeName = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  final dir = await getTemporaryDirectory();
  final file = File(p.join(dir.path, safeName));
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: mimeType, name: safeName)],
      subject: safeName,
    ),
  );
  return true;
}
