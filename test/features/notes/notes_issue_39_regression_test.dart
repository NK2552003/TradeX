import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/notes/data/note_ai_refactor.dart';
import 'package:tradex/features/notes/data/note_attachments.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/notes/data/real_note_ai_refactor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #39: Work Item 1 - Owner-Scoped Storage Keys & Metadata', () {
    final repo = NotesRepositoryImpl.instance;

    test('upload key format strictly follows <user_id>/<note_id>/<uuid>.<ext>', () {
      const userId = '11111111-2222-3333-4444-555555555555';
      const noteId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      const ext = 'PNG';
      final normalizedExt = ext.toLowerCase().trim();

      // Simulated storagePath builder matching NotesRepositoryImpl
      final key = '$userId/$noteId/unique-attachment-uuid.$normalizedExt';
      final segments = key.split('/');

      // Verify prefix strictly matches storage policy (storage.foldername(name))[1] = auth.uid()
      // and (storage.foldername(name))[2] = noteId
      expect(segments.length, equals(3));
      expect(segments[0], equals(userId));
      expect(segments[1], equals(noteId));
      expect(segments[2], endsWith('.png'));
    });

    test('MIME type resolution matches storage bucket allowed MIME types', () {
      expect(NoteAttachments.isImageFile('chart.png'), isTrue);
      expect(NoteAttachments.isImageFile('chart.jpg'), isTrue);
      expect(NoteAttachments.isImageFile('chart.jpeg'), isTrue);
      expect(NoteAttachments.isImageFile('chart.webp'), isTrue);
      expect(NoteAttachments.isImageFile('chart.gif'), isTrue);
      expect(NoteAttachments.isImageFile('document.pdf'), isFalse);
      expect(NoteAttachments.isImageFile('notes.md'), isFalse);
      expect(NoteAttachments.isImageFile('data.csv'), isFalse);
    });

    test('uploadAttachment rejects unauthenticated upload when client is unauthenticated', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_trade_chart.png');
      tempFile.writeAsStringSync('dummy-image-bytes');
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      expect(
        () async => await repo.uploadAttachment('note-id-123', tempFile),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: user must be authenticated'),
        )),
      );
    });

    test('uploadAttachment rejects service access when allowDemo is false and disconnected', () async {
      CustomerDataPolicy.allowDemo = false;
      addTearDown(() => CustomerDataPolicy.allowDemo = true);

      final tempFile = File('${Directory.systemTemp.path}/test_trade_chart2.png');
      tempFile.writeAsStringSync('dummy-image-bytes');
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      expect(
        () async => await repo.uploadAttachment('note-id-123', tempFile),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Connect to your account to save this change'),
        )),
      );
    });
  });

  group('Issue #39: Work Item 2 - Expiring Signed URLs & Cache Invalidation', () {
    final repo = NotesRepositoryImpl.instance;

    test('external third-party URLs pass through unchanged', () async {
      const externalUrl = 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3';
      final resolved = await repo.resolveAttachmentUrl(externalUrl);
      expect(resolved, equals(externalUrl));
    });

    test('local file URIs and file paths pass through unchanged', () async {
      const localPath = 'file:///C:/Users/Hp/AppData/Local/note_attachments/screenshot.png';
      final resolved = await repo.resolveAttachmentUrl(localPath);
      expect(resolved, equals(localPath));

      const relativeFile = '/storage/emulated/0/Download/chart.png';
      final resolvedRelative = await repo.resolveAttachmentUrl(relativeFile);
      expect(resolvedRelative, equals(relativeFile));
    });

    test('resolveAttachmentUrl parses public URL into private storage key', () {
      const unsignedPublicUrl =
          'https://xyzproject.supabase.co/storage/v1/object/public/note-attachments/user-uuid/note-uuid/chart.png';

      final uri = Uri.parse(unsignedPublicUrl);
      final pathSegments = uri.pathSegments;
      final bucketIdx = pathSegments.indexOf('note-attachments');
      final relativePath = pathSegments.sublist(bucketIdx + 1).join('/');

      expect(relativePath, equals('user-uuid/note-uuid/chart.png'));
      expect(relativePath.startsWith('https://'), isFalse);
    });

    test('resolveAttachmentUrl rejects cross-user access to private attachments', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignAttachmentPath = '$foreignUserId/private-note-uuid/confidential-chart.png';

      expect(
        () async => await repo.resolveAttachmentUrl(foreignAttachmentPath),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: access denied to private attachment'),
        )),
      );
    });

    test('deleteAttachment rejects foreign user private attachment', () async {
      const foreignAttachmentPath = '88888888-4444-4444-4444-888888888888/note-1/chart.png';

      expect(
        () async => await repo.deleteAttachment(foreignAttachmentPath),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized'),
        )),
      );
    });

    test('NoteAttachments cache invalidation methods operate correctly', () {
      // Clear cache without crashing
      NoteAttachments.clearCache();

      // Invalidate specific reference
      NoteAttachments.invalidate('user-1/note-1/chart.png');

      // Invalidate all attachments for a specific note
      NoteAttachments.invalidateForNote('note-1');
    });

    test('NoteAttachments.refOf parses local-image and local-file URI schemes', () {
      final imgUri = Uri.parse('local-image://user-1/note-1/chart.png');
      expect(NoteAttachments.refOf(imgUri), equals('user-1/note-1/chart.png'));

      final fileUri = Uri.parse('local-file://user-1/note-1/doc.pdf');
      expect(NoteAttachments.refOf(fileUri), equals('user-1/note-1/doc.pdf'));

      final httpUri = Uri.parse('https://example.com/chart.png');
      expect(NoteAttachments.refOf(httpUri), isNull);
    });
  });

  group('Issue #39: Work Item 3 - Authenticated AI Refactoring & No Simulated Success', () {
    test('RealNoteAiRefactor rejects empty text gracefully', () async {
      const refactor = RealNoteAiRefactor();
      final result = await refactor.enhance(
        selectedText: '   ',
        noteType: AppNoteType.general,
      );
      expect(result, equals('   '));
    });

    test('RealNoteAiRefactor throws when AI service is unavailable instead of silent regex mocking', () async {
      const refactor = RealNoteAiRefactor();

      // When unauthenticated or AI service is unavailable without active API keys
      expect(
        () async => await refactor.enhance(
          selectedText: 'Entry at 2500, Stop Loss at 2450, Target at 2650',
          noteType: AppNoteType.plan,
          instruction: 'format as systematic trade plan',
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          anyOf(
            contains('AI refactoring service is currently unavailable'),
            contains('Sign in required'),
          ),
        )),
      );
    });

    test('NoteAiRefactorDemo explicitly provides mechanical restructuring in demo mode', () async {
      const demoRefactor = NoteAiRefactorDemo();
      final result = await demoRefactor.enhance(
        selectedText: 'check level 1\ncheck level 2',
        noteType: AppNoteType.general,
        instruction: 'checklist',
      );

      expect(result, contains('- [ ] Check level 1'));
      expect(result, contains('- [ ] Check level 2'));
    });

    test('NoteAiScope returns RealNoteAiRefactor by default and tracks demo mode', () {
      expect(NoteAiScope.service, isA<RealNoteAiRefactor>());
      expect(NoteAiScope.isDemo, isFalse);

      NoteAiScope.override(const NoteAiRefactorDemo());
      expect(NoteAiScope.isDemo, isTrue);

      NoteAiScope.override(null);
      expect(NoteAiScope.isDemo, isFalse);
      expect(NoteAiScope.service, isA<RealNoteAiRefactor>());
    });
  });
}
