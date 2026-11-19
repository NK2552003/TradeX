import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';

void main() {
  group('MessagesRepository Attachment Upload Tests', () {
    test(
      'uploadAttachment returns valid data URI fallback when storage is not configured or errors',
      () async {
        final repository = MessagesRepository();
        final bytes = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        final url = await repository.uploadAttachment(
          threadId: 'test_thread_123',
          bytes: bytes,
          filename: 'chart_breakout.png',
        );

        expect(url, isNotNull);
        expect(url, startsWith('data:image/png;base64,'));
      },
    );

    test(
      'uploadAttachment supports jpeg and pdf filenames for data URI fallback',
      () async {
        final repository = MessagesRepository();
        final bytes = Uint8List.fromList([10, 20, 30]);

        final jpegUrl = await repository.uploadAttachment(
          threadId: 'test_thread_123',
          bytes: bytes,
          filename: 'snapshot.jpg',
        );
        expect(jpegUrl, startsWith('data:image/jpeg;base64,'));

        final pdfUrl = await repository.uploadAttachment(
          threadId: 'test_thread_123',
          bytes: bytes,
          filename: 'report.pdf',
        );
        expect(pdfUrl, startsWith('data:application/pdf;base64,'));
      },
    );
  });
}
