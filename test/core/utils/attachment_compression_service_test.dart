import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tradex/core/utils/attachment_compression_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentCompressionService Tests', () {
    test('Non-image attachments pass through untouched', () async {
      final samplePdfBytes = Uint8List.fromList([
        37,
        80,
        68,
        70,
        45,
        49,
        46,
        52,
      ]); // %PDF-1.4
      final result = await AttachmentCompressionService.compressAttachment(
        bytes: samplePdfBytes,
        filename: 'statement.pdf',
        mimeType: 'application/pdf',
      );

      expect(result.isImage, isFalse);
      expect(result.filename, equals('statement.pdf'));
      expect(result.mimeType, equals('application/pdf'));
      expect(result.bytes, equals(samplePdfBytes));
      expect(result.compressedByteSize, equals(samplePdfBytes.length));
    });

    test(
      'Compresses raw image payload below 100 KB and outputs WebP',
      () async {
        // Create a 1400x1400 test image so uncompressed PNG is > 200 KB
        final rawImage = img.Image(width: 1400, height: 1400);
        for (int y = 0; y < 1400; y++) {
          for (int x = 0; x < 1400; x++) {
            final r = (x * 7 + y * 13) % 256;
            final g = (x * 11 + y * 19) % 256;
            final b = (x * 17 + y * 23) % 256;
            rawImage.setPixelRgba(x, y, r, g, b, 255);
          }
        }
        final rawPng = Uint8List.fromList(img.encodePng(rawImage));
        expect(rawPng.length, greaterThan(100 * 1024));

        final result = await AttachmentCompressionService.compressAttachment(
          bytes: rawPng,
          filename: 'high_res_chart.png',
        );

        expect(result.isImage, isTrue);
        expect(result.filename, equals('high_res_chart.webp'));
        expect(result.mimeType, equals('image/webp'));
        expect(result.compressedByteSize, lessThanOrEqualTo(100 * 1024));
        expect(result.compressedByteSize, lessThan(result.originalByteSize));
        expect(result.savingsRatio, greaterThan(0.0));

        // Verify that the output bytes can be decoded as a valid image
        final decoded = img.decodeImage(result.bytes);
        expect(decoded, isNotNull);
      },
    );

    test(
      'invalid raster files fail before upload instead of returning original bytes',
      () async {
        await expectLater(
          AttachmentCompressionService.compressAttachment(
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'broken.png',
          ),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'animated GIF compression retains animation and frame timing',
      () async {
        final animation = img.Image(width: 32, height: 32);
        img.fill(animation, color: img.ColorRgb8(255, 0, 0));
        animation.frameDuration = 100;
        final frame = animation.addFrame(img.Image(width: 32, height: 32));
        img.fill(frame, color: img.ColorRgb8(0, 0, 255));
        frame.frameDuration = 200;
        final result = await AttachmentCompressionService.compressAttachment(
          bytes: Uint8List.fromList(img.encodeGif(animation)),
          filename: 'motion.gif',
        );
        final decoded = img.decodeWebP(result.bytes)!;
        expect(decoded.numFrames, 2);
        expect(decoded.frames.map((f) => f.frameDuration), [100, 200]);
        expect(result.bytes.length, lessThanOrEqualTo(100 * 1024));
      },
    );

    test(
      'large animated GIF is decoded with bounded retained frames',
      () async {
        final frame = img.Image(width: 800, height: 800);
        img.fill(frame, color: img.ColorRgb8(30, 90, 150));
        frame.frameDuration = 100;
        final oneFrame = img.GifEncoder(delay: 10).encode(frame);
        // Repeat an independently encoded full-canvas frame after the header.
        final decoder = img.GifDecoder()..startDecode(oneFrame);
        final firstFrameOffset = oneFrame.indexOf(
          0x21,
          13 + 3 * (1 << ((oneFrame[10] & 7) + 1)),
        );
        expect(decoder.info!.numFrames, 1);
        final gif = Uint8List.fromList([
          ...oneFrame.sublist(0, firstFrameOffset),
          for (var i = 0; i < 28; i++)
            ...oneFrame.sublist(firstFrameOffset, oneFrame.length - 1),
          0x3b,
        ]);
        final result = await AttachmentCompressionService.compressAttachment(
          bytes: gif,
          filename: 'large-motion.gif',
        );
        final decoded = img.decodeWebP(result.bytes)!;
        expect(decoded.numFrames, greaterThan(1));
        expect(decoded.numFrames, lessThanOrEqualTo(16));
        expect(
          decoded.frames.fold<int>(0, (sum, f) => sum + f.frameDuration),
          2800,
        );
        expect(result.bytes.length, lessThanOrEqualTo(100 * 1024));
      },
    );

    test('Avatar compression scales to within 512x512', () async {
      final rawImage = img.Image(width: 1200, height: 1200);
      img.fill(rawImage, color: img.ColorRgb8(50, 100, 200));
      final rawJpg = Uint8List.fromList(img.encodeJpg(rawImage, quality: 95));

      final result = await AttachmentCompressionService.compressAttachment(
        bytes: rawJpg,
        filename: 'profile_picture.jpg',
        isAvatar: true,
      );

      expect(result.isImage, isTrue);
      expect(result.filename, equals('profile_picture.webp'));
      expect(result.compressedByteSize, lessThanOrEqualTo(100 * 1024));

      final decoded = img.decodeImage(result.bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(512));
      expect(decoded.height, lessThanOrEqualTo(512));
    });
  });
}
