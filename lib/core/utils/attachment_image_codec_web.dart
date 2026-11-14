import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:web/web.dart' as web;

/// Uses the browser's native encoder for still images without a server request.
Future<Uint8List?> compressStaticImage(
  Uint8List bytes,
  int maxDimension,
  int maxBytes,
) async {
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  // Animated formats use the frame-aware path in the compression service.
  if (info == null || info.numFrames != 1) return null;
  if (decoder is img.WebPDecoder &&
      bytes.length <= maxBytes &&
      math.max(info.width, info.height) <= maxDimension) {
    return bytes;
  }
  web.ImageBitmap? bitmap;
  try {
    bitmap = await web.window
        .createImageBitmap(web.Blob([bytes.toJS].toJS))
        .toDart;
    final canvas = web.HTMLCanvasElement();
    final context = canvas.getContext('2d')! as web.CanvasRenderingContext2D;
    var dimension = math.min(
      maxDimension,
      math.max(bitmap.width, bitmap.height),
    );
    var quality = 0.8;
    while (true) {
      final scale = dimension / math.max(bitmap.width, bitmap.height);
      canvas.width = math.max(1, (bitmap.width * scale).round());
      canvas.height = math.max(1, (bitmap.height * scale).round());
      context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      final completer = Completer<web.Blob?>();
      canvas.toBlob(
        ((web.Blob? blob) => completer.complete(blob)).toJS,
        'image/webp',
        quality.toJS,
      );
      final blob = await completer.future;
      // Browsers without a WebP encoder return PNG.
      if (blob == null || blob.type != 'image/webp') return null;
      if (blob.size <= maxBytes) {
        return (await blob.arrayBuffer().toDart).toDart.asUint8List();
      }
      if (dimension <= 1) return null;
      dimension = math.max(1, (dimension * 0.75).floor());
      quality = math.max(0.35, quality - 0.1);
    }
  } catch (_) {
    return null;
  } finally {
    bitmap?.close();
  }
}
