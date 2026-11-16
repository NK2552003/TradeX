import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart'
    as impl;

/// Saves or triggers a browser download of raw binary [bytes] as [filename].
Future<bool> downloadBytesFile(
  Uint8List bytes, {
  required String filename,
  String mimeType = 'application/octet-stream',
}) {
  return impl.downloadBytesFileImpl(
    bytes,
    filename: filename,
    mimeType: mimeType,
  );
}
