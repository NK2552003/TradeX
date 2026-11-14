import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'attachment_image_codec_stub.dart'
    if (dart.library.js_interop) 'attachment_image_codec_web.dart'
    as browser_codec;

/// Representation of an optimized attachment ready for cloud storage upload.
class CompressedAttachment {
  const CompressedAttachment({
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.isImage,
    required this.originalByteSize,
    required this.compressedByteSize,
  });

  /// The binary payload (compressed into modern WebP for images).
  final Uint8List bytes;

  /// The updated filename with optimal extension (e.g. `.webp` for compressed images).
  final String filename;

  /// The standard MIME type (e.g. `image/webp`).
  final String mimeType;

  /// Whether the attachment is an image.
  final bool isImage;

  /// Original byte size prior to compression.
  final int originalByteSize;

  /// Final byte size after compression.
  final int compressedByteSize;

  /// Ratio of storage bytes saved (0.0 to 1.0).
  double get savingsRatio => originalByteSize > 0
      ? (1.0 - (compressedByteSize / originalByteSize)).clamp(0.0, 1.0)
      : 0.0;

  /// Human-readable savings percentage string.
  String get savingsPercent => '${(savingsRatio * 100).toStringAsFixed(1)}%';
}

/// Global unified attachment and image compression strategy.
///
/// Converts images to modern high-efficiency WebP format and compresses
/// them to a 100 KB budget. Large animations retain sampled frames and timing.
class AttachmentCompressionService {
  AttachmentCompressionService._();

  /// Default ceiling for compressed image size: 100 KB (102,400 bytes).
  static const int defaultMaxSizeBytes = 100 * 1024;

  /// Default maximum dimension for general image uploads (posts, notes, chats).
  static const int defaultMaxDimension = 1600;

  /// Default maximum dimension for profile avatars (512x512).
  static const int avatarMaxDimension = 512;

  /// Checks if a file name represents an image by extension.
  static bool isImageFileName(String filename) {
    final lower = filename.toLowerCase().trim();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.tif') ||
        lower.endsWith('.tiff') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  /// Checks if a MIME type represents a raster image.
  static bool isImageMime(String? mimeType) {
    if (mimeType == null) return false;
    final lower = mimeType.toLowerCase().trim();
    return lower.startsWith('image/') && !lower.contains('svg');
  }

  /// Compresses and formats any image attachment to WebP under [maxSizeBytes] (< 100 KB).
  ///
  /// Non-image attachments (e.g. PDF, CSV, audio) are safely passed through untouched.
  static Future<CompressedAttachment> compressAttachment({
    required Uint8List bytes,
    required String filename,
    String? mimeType,
    int maxSizeBytes = defaultMaxSizeBytes,
    int maxDimension = defaultMaxDimension,
    bool isAvatar = false,
  }) async {
    final int originalLength = bytes.length;
    final bool appearsToBeImage =
        isImageFileName(filename) || isImageMime(mimeType);

    if (maxSizeBytes < 1 || maxDimension < 1) {
      throw ArgumentError('Invalid image budget.');
    }
    if (bytes.isEmpty) throw const FormatException('Attachment is empty.');
    if (!appearsToBeImage) {
      return CompressedAttachment(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType ?? _guessNonImageMime(filename),
        isImage: false,
        originalByteSize: originalLength,
        compressedByteSize: originalLength,
      );
    }

    final dimension = isAvatar ? avatarMaxDimension : maxDimension;
    final params = _CompressionParams(
      rawBytes: bytes,
      maxSizeBytes: maxSizeBytes,
      maxDimension: dimension,
    );
    Uint8List optimized;
    try {
      optimized =
          await browser_codec.compressStaticImage(
            bytes,
            dimension,
            maxSizeBytes,
          ) ??
          await compute(_compressInIsolate, params);
    } on _PlatformDecodeRequired {
      // Use the platform's image codec for large animations and formats such
      // as HEIC where the device has a decoder. Read composited frames in order.
      optimized = await _compressWithPlatformCodec(params);
    }
    final dot = filename.lastIndexOf('.');
    return CompressedAttachment(
      bytes: optimized,
      filename: '${dot > 0 ? filename.substring(0, dot) : filename}.webp',
      mimeType: 'image/webp',
      isImage: true,
      originalByteSize: originalLength,
      compressedByteSize: optimized.length,
    );
  }

  static Uint8List _compressInIsolate(_CompressionParams params) =>
      optimizeImageToWebpSync(
        params.rawBytes,
        maxSizeBytes: params.maxSizeBytes,
        maxDimension: params.maxDimension,
      );

  static Uint8List optimizeImageToWebpSync(
    Uint8List rawBytes, {
    int maxSizeBytes = defaultMaxSizeBytes,
    int maxDimension = defaultMaxDimension,
  }) {
    final decoder = img.findDecoderForData(rawBytes);
    final info = decoder?.startDecode(rawBytes);
    if (info == null) throw const _PlatformDecodeRequired();
    final dimension = math.max(info.width, info.height);
    if (decoder is img.WebPDecoder &&
        rawBytes.length <= maxSizeBytes &&
        dimension <= maxDimension) {
      return rawBytes;
    }
    // Avoid a full-size RGBA allocation for every frame of a large animation.
    if (info.width * info.height * info.numFrames > 16 * 1024 * 1024) {
      throw const _PlatformDecodeRequired();
    }
    final decoded = decoder!.decode(rawBytes);
    if (decoded == null) throw const _PlatformDecodeRequired();
    return _encodeWithinBudget(
      img.bakeOrientation(decoded),
      maxDimension,
      maxSizeBytes,
    );
  }

  static Future<Uint8List> _compressWithPlatformCodec(
    _CompressionParams params,
  ) async {
    ui.Codec? codec;
    try {
      final info = img
          .findDecoderForData(params.rawBytes)
          ?.startDecode(params.rawBytes);
      // When the Dart decoder requires a fallback, keep the frame working set small.
      final limit = math.min(params.maxDimension, 640);
      final portrait = info != null && info.height > info.width;
      codec = await ui.instantiateImageCodec(
        params.rawBytes,
        targetWidth: portrait ? null : limit,
        targetHeight: portrait ? limit : null,
        allowUpscaling: false,
      );
      final step = (codec.frameCount / 16).ceil();
      img.Image? animation;
      img.Image? sampledFrame;
      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        try {
          if (i % step == 0) {
            final rgba = await frame.image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            );
            if (rgba == null) {
              throw const FormatException('Unable to read image pixels.');
            }
            sampledFrame = img.Image.fromBytes(
              width: frame.image.width,
              height: frame.image.height,
              bytes: rgba.buffer,
              bytesOffset: rgba.offsetInBytes,
              numChannels: 4,
            );
            if (math.max(sampledFrame.width, sampledFrame.height) > limit) {
              sampledFrame = img.copyResize(
                sampledFrame,
                width: sampledFrame.width >= sampledFrame.height ? limit : null,
                height: sampledFrame.height > sampledFrame.width ? limit : null,
              );
            }
            if (animation == null) {
              animation = sampledFrame;
              animation.loopCount = codec.repetitionCount + 1;
            } else {
              animation.addFrame(sampledFrame);
            }
          }
          sampledFrame!.frameDuration += frame.duration.inMilliseconds;
        } finally {
          frame.image.dispose();
        }
      }
      if (animation == null) {
        throw const FormatException('Image contains no frames.');
      }
      return await compute(_encodeDecoded, (
        animation,
        limit,
        params.maxSizeBytes,
      ));
    } catch (error) {
      debugPrint(
        '[AttachmentCompressionService] Image preparation failed: $error',
      );
      throw const FormatException(
        'This image could not be optimized. Try a JPEG, PNG, WebP or GIF.',
      );
    } finally {
      codec?.dispose();
    }
  }

  static Uint8List _encodeDecoded((img.Image, int, int) input) =>
      _encodeWithinBudget(input.$1, input.$2, input.$3);

  static Uint8List _encodeWithinBudget(
    img.Image image,
    int maxDimension,
    int maxBytes,
  ) {
    if (maxBytes < 1 || maxDimension < 1) {
      throw ArgumentError('Invalid image budget.');
    }
    var current = image;
    var dimension = math.min(maxDimension, math.max(image.width, image.height));
    var quality = 80;
    while (true) {
      if (math.max(current.width, current.height) > dimension) {
        current = img.copyResize(
          current,
          width: current.width >= current.height ? dimension : null,
          height: current.height > current.width ? dimension : null,
          interpolation: img.Interpolation.average,
        );
      }
      final encoded = img.encodeWebP(
        current,
        lossless: false,
        quality: quality,
        method: 2,
      );
      if (encoded.length <= maxBytes) return encoded;
      if (dimension <= 1) {
        throw const FormatException('Image exceeds the storage budget.');
      }
      dimension = math.max(1, (dimension * 0.75).floor());
      quality = math.max(35, quality - 10);
    }
  }

  static String _guessNonImageMime(String filename) {
    final lower = filename.toLowerCase().trim();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return 'application/octet-stream';
  }
}

class _CompressionParams {
  const _CompressionParams({
    required this.rawBytes,
    required this.maxSizeBytes,
    required this.maxDimension,
  });

  final Uint8List rawBytes;
  final int maxSizeBytes;
  final int maxDimension;
}

class _PlatformDecodeRequired implements Exception {
  const _PlatformDecodeRequired();
}
