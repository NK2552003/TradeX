import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

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
/// them below 100 KB while preserving crisp visual fidelity across all surfaces.
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

    if (!appearsToBeImage || bytes.isEmpty) {
      return CompressedAttachment(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType ?? _guessNonImageMime(filename),
        isImage: false,
        originalByteSize: originalLength,
        compressedByteSize: originalLength,
      );
    }

    // If already WebP and already under the target limit, preserve directly
    if (filename.toLowerCase().trim().endsWith('.webp') &&
        originalLength <= maxSizeBytes &&
        !isAvatar) {
      return CompressedAttachment(
        bytes: bytes,
        filename: filename,
        mimeType: 'image/webp',
        isImage: true,
        originalByteSize: originalLength,
        compressedByteSize: originalLength,
      );
    }

    try {
      final int effectiveMaxDimension =
          isAvatar ? avatarMaxDimension : maxDimension;

      final Uint8List optimized = await compute(
        _compressInIsolate,
        _CompressionParams(
          rawBytes: bytes,
          maxSizeBytes: maxSizeBytes,
          maxDimension: effectiveMaxDimension,
        ),
      );

      // Determine updated WebP filename
      final String baseName = filename.contains('.')
          ? filename.substring(0, filename.lastIndexOf('.'))
          : filename;
      final String webpFilename = '$baseName.webp';

      return CompressedAttachment(
        bytes: optimized,
        filename: webpFilename,
        mimeType: 'image/webp',
        isImage: true,
        originalByteSize: originalLength,
        compressedByteSize: optimized.length,
      );
    } catch (e) {
      debugPrint('[AttachmentCompressionService] Optimization fallback: $e');
      return CompressedAttachment(
        bytes: bytes,
        filename: filename,
        mimeType: mimeType ?? 'application/octet-stream',
        isImage: appearsToBeImage,
        originalByteSize: originalLength,
        compressedByteSize: originalLength,
      );
    }
  }

  /// Internal worker executed in background isolate to keep UI frame-rates smooth.
  static Uint8List _compressInIsolate(_CompressionParams params) {
    return optimizeImageToWebpSync(
      params.rawBytes,
      maxSizeBytes: params.maxSizeBytes,
      maxDimension: params.maxDimension,
    );
  }

  /// Synchronous image optimization logic.
  static Uint8List optimizeImageToWebpSync(
    Uint8List rawBytes, {
    int maxSizeBytes = defaultMaxSizeBytes,
    int maxDimension = defaultMaxDimension,
  }) {
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) {
      return rawBytes;
    }

    img.Image current = decoded;

    // 1. Initial downscale if dimensions exceed maxDimension
    if (current.width > maxDimension || current.height > maxDimension) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? maxDimension : null,
        height: current.height > current.width ? maxDimension : null,
        interpolation: img.Interpolation.linear,
      );
    }

    // 2. Progressive quality & dimension steps targeting < maxSizeBytes (< 100 KB)
    final List<int> qualitySteps = <int>[80, 68, 55, 42, 30];
    Uint8List? bestCandidate;

    for (final int quality in qualitySteps) {
      final Uint8List webpBytes = img.encodeWebP(
        current,
        lossless: false,
        quality: quality,
        method: 4,
      );

      bestCandidate = webpBytes;
      if (webpBytes.length <= maxSizeBytes) {
        return webpBytes;
      }

      // If still above limit, scale down dimensions progressively
      final int targetDimension = switch (quality) {
        80 => 1200,
        68 => 960,
        55 => 720,
        42 => 540,
        _ => 400,
      };

      if (current.width > targetDimension || current.height > targetDimension) {
        current = img.copyResize(
          current,
          width: current.width >= current.height ? targetDimension : null,
          height: current.height > current.width ? targetDimension : null,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 3. Fallback aggressive loop if image contains extreme high-frequency entropy
    while (bestCandidate != null &&
        bestCandidate.length > maxSizeBytes &&
        current.width > 200 &&
        current.height > 200) {
      final newW = (current.width * 0.75).round();
      final newH = (current.height * 0.75).round();
      current = img.copyResize(current, width: newW, height: newH);
      bestCandidate = img.encodeWebP(
        current,
        lossless: false,
        quality: 35,
        method: 3,
      );
    }

    return bestCandidate ?? rawBytes;
  }

  static String _guessNonImageMime(String filename) {
    final lower = filename.toLowerCase().trim();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.webm')) return 'audio/webm';
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
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
