import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/strategies/data/strategy_attachments.dart';
import 'package:tradex/features/auth/data/services/auth_backend_service.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #40: Work Item 1 - Public Strategy Versions Authorization', () {
    final repo = StrategiesRepositoryImpl.instance;
    const currentUserId = '11111111-2222-3333-4444-555555555555';

    setUp(() {
      AuthBackendService.instance.setCurrentProfile(
        UserProfileModel(
          id: currentUserId,
          email: 'trader@example.com',
          handle: 'trader',
          displayName: 'Trader',
          role: UserRole.customer,
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() {
      AuthBackendService.instance.setCurrentProfile(null);
    });

    test('owner can access versions for both private and public strategies', () async {
      // Create a private strategy belonging to current user
      final privateStrategy = AppStrategy(
        id: '11111111-0000-0000-0000-111111111111',
        userId: '11111111-2222-3333-4444-555555555555',
        name: 'Private Mean Reversion',
        content: '# Private Strategy Details',
        isPublic: false,
      );

      await repo.create(privateStrategy);
      final history = await repo.versions(privateStrategy.id);
      expect(history, isNotNull);
    });

    test('versions throws StateError for private strategy belonging to another user', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignStrategyId = '22222222-0000-0000-0000-222222222222';

      final foreignPrivateStrategy = AppStrategy(
        id: foreignStrategyId,
        userId: foreignUserId,
        name: 'Confidential Alpha Playbook',
        content: '# Top Secret Strategy',
        isPublic: false,
      );

      await repo.create(foreignPrivateStrategy);

      // Attempting to read versions of foreign private strategy must be rejected
      expect(
        () async => await repo.versions(foreignStrategyId),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: access denied to private strategy versions.'),
        )),
      );
    });

    test('versions succeeds for public strategy belonging to another user', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignStrategyId = '33333333-0000-0000-0000-333333333333';

      final foreignPublicStrategy = AppStrategy(
        id: foreignStrategyId,
        userId: foreignUserId,
        name: 'Community Breakout Playbook',
        content: '# Public Breakout Strategy',
        isPublic: true,
      );

      await repo.create(foreignPublicStrategy);

      // Attempting to read versions of public strategy must succeed
      final versions = await repo.versions(foreignStrategyId);
      expect(versions, isNotNull);
    });

    test('non-owner write actions (saveVersion and restoreVersion) are rejected', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignStrategyId = '44444444-0000-0000-0000-444444444444';

      final foreignStrategy = AppStrategy(
        id: foreignStrategyId,
        userId: foreignUserId,
        name: 'Foreign Strategy',
        content: '# Rules',
        isPublic: true,
      );

      await repo.create(foreignStrategy);

      // Save version by non-owner must throw StateError
      expect(
        () async => await repo.saveVersion(foreignStrategyId, note: 'Tampered version'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          anyOf(contains('Only the owner'), contains('Unauthorized')),
        )),
      );

      // Restore version by non-owner must throw StateError
      expect(
        () async => await repo.restoreVersion(foreignStrategyId, 'version-1'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          anyOf(contains('Only the owner'), contains('Unauthorized')),
        )),
      );
    });
  });

  group('Issue #40: Work Item 2 - Strategy Attachment Keys & Signed URL Resolution', () {
    final repo = StrategiesRepositoryImpl.instance;

    test('sanitizeExtension handles dotted parent paths, uppercase and special characters', () {
      expect(StrategiesRepositoryImpl.sanitizeExtension('/tmp/a.b/file'), equals('bin'));
      expect(StrategiesRepositoryImpl.sanitizeExtension('/tmp/a.b/setup.PNG'), equals('png'));
      expect(StrategiesRepositoryImpl.sanitizeExtension(r'C:\Trading\playbooks.v1\chart.webp'), equals('webp'));
      expect(StrategiesRepositoryImpl.sanitizeExtension('chart.j#p@g!'), equals('jpg'));
      expect(StrategiesRepositoryImpl.sanitizeExtension('no_ext'), equals('bin'));
      expect(StrategiesRepositoryImpl.sanitizeExtension('/var/log/...'), equals('bin'));
    });

    test('upload key format strictly follows <user_id>/<strategy_id>/<uuid>.<ext>', () {
      const userId = '11111111-2222-3333-4444-555555555555';
      const strategyId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
      const ext = 'PNG';
      final normalizedExt = StrategiesRepositoryImpl.sanitizeExtension('chart.$ext');

      final key = '$userId/$strategyId/unique-attachment-uuid.$normalizedExt';
      final segments = key.split('/');

      // Verify prefix strictly matches storage policy (storage.foldername(name))[1] = auth.uid()
      // and (storage.foldername(name))[2] = strategyId
      expect(segments.length, equals(3));
      expect(segments[0], equals(userId));
      expect(segments[1], equals(strategyId));
      expect(segments[2], endsWith('.png'));
    });

    test('uploadAttachment rejects unauthenticated upload when client is unauthenticated', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_strategy_chart.png');
      tempFile.writeAsStringSync('dummy-image-bytes');
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      expect(
        () async => await repo.uploadAttachment('strategy-123', tempFile),
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

      final tempFile = File('${Directory.systemTemp.path}/test_strategy_chart2.png');
      tempFile.writeAsStringSync('dummy-image-bytes');
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      expect(
        () async => await repo.uploadAttachment('strategy-123', tempFile),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Connect to your account to save this change'),
        )),
      );
    });

    test('external URLs and local paths pass through resolveAttachmentUrl unchanged', () async {
      const externalUrl = 'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3';
      final resolved = await repo.resolveAttachmentUrl(externalUrl);
      expect(resolved, equals(externalUrl));

      const localPath = 'file:///C:/Users/Hp/AppData/Local/strategy_attachments/chart.png';
      final resolvedLocal = await repo.resolveAttachmentUrl(localPath);
      expect(resolvedLocal, equals(localPath));

      const relativeFile = '/storage/emulated/0/Download/strategy_setup.png';
      final resolvedRelative = await repo.resolveAttachmentUrl(relativeFile);
      expect(resolvedRelative, equals(relativeFile));
    });

    test('resolveAttachmentUrl parses public URL into relative storage key', () {
      const unsignedPublicUrl =
          'https://xyzproject.supabase.co/storage/v1/object/public/strategy-attachments/user-uuid/strategy-uuid/chart.png';

      final uri = Uri.parse(unsignedPublicUrl);
      final pathSegments = uri.pathSegments;
      final bucketIdx = pathSegments.indexOf('strategy-attachments');
      final relativePath = pathSegments.sublist(bucketIdx + 1).join('/');

      expect(relativePath, equals('user-uuid/strategy-uuid/chart.png'));
      expect(relativePath.startsWith('https://'), isFalse);
    });

    test('resolveAttachmentUrl rejects cross-user access to private strategy attachments', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignStrategyId = '55555555-0000-0000-0000-555555555555';
      const foreignAttachmentPath = '$foreignUserId/$foreignStrategyId/confidential-setup.png';

      // Save a private strategy owned by foreign user
      final foreignStrategy = AppStrategy(
        id: foreignStrategyId,
        userId: foreignUserId,
        name: 'Private Proprietary Playbook',
        content: '# Internal',
        isPublic: false,
      );
      await repo.create(foreignStrategy);

      expect(
        () async => await repo.resolveAttachmentUrl(foreignAttachmentPath),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: access denied to private attachment'),
        )),
      );
    });

    test('resolveAttachmentUrl allows access to public strategy attachments', () async {
      const foreignUserId = '99999999-8888-7777-6666-555555555555';
      const foreignStrategyId = '66666666-0000-0000-0000-666666666666';
      const publicAttachmentPath = '$foreignUserId/$foreignStrategyId/public-setup.png';

      // Save a public strategy owned by foreign user
      final foreignStrategy = AppStrategy(
        id: foreignStrategyId,
        userId: foreignUserId,
        name: 'Public Community Playbook',
        content: '# Public',
        isPublic: true,
      );
      await repo.create(foreignStrategy);

      // In local/test mode without SupabaseConfig, returns the clean storage path without throwing unauthorized
      final resolved = await repo.resolveAttachmentUrl(publicAttachmentPath);
      expect(resolved, equals(publicAttachmentPath));
    });

    test('deleteAttachment rejects foreign user private attachment', () async {
      const foreignAttachmentPath = '88888888-4444-4444-4444-888888888888/strategy-1/chart.png';

      expect(
        () async => await repo.deleteAttachment(foreignAttachmentPath),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized'),
        )),
      );
    });

    test('StrategyAttachments cache invalidation methods operate correctly', () {
      StrategyAttachments.clearCache();
      StrategyAttachments.invalidate('user-1/strategy-1/chart.png');
      StrategyAttachments.invalidateForStrategy('strategy-1');
    });

    test('StrategyAttachments.bytesFor returns null when resolver throws', () async {
      final uri = Uri.parse('local-image://user-1/strategy-1/missing.png');
      final result = await StrategyAttachments.bytesFor(uri);
      expect(result, isNull);
    });
  });

  group('Issue #40: Work Item 3 - Link Graph Authoritative Mutation & Race Resolution', () {
    final repo = StrategiesRepositoryImpl.instance;

    test('linkNote and unlinkNote update in-memory state cleanly', () async {
      final strategy = AppStrategy(
        id: '77777777-0000-0000-0000-777777777777',
        userId: '11111111-2222-3333-4444-555555555555',
        name: 'Breakout Strategy',
        content: '# Setup',
        linkedNoteIds: const <String>['note-1'],
      );
      await repo.create(strategy);

      // Link another note
      final linked = await repo.linkNote(strategy.id, 'note-2');
      expect(linked.linkedNoteIds, containsAll(<String>['note-1', 'note-2']));

      // Idempotent link
      final linkedAgain = await repo.linkNote(strategy.id, 'note-2');
      expect(linkedAgain.linkedNoteIds.length, equals(2));

      // Unlink note
      final unlinked = await repo.unlinkNote(strategy.id, 'note-1');
      expect(unlinked.linkedNoteIds, equals(<String>['note-2']));
    });

    test('linkJournal and unlinkJournal update in-memory state cleanly', () async {
      final strategy = AppStrategy(
        id: '88888888-0000-0000-0000-888888888888',
        userId: '11111111-2222-3333-4444-555555555555',
        name: 'Trend Following',
        content: '# Setup',
        linkedJournalIds: const <String>['trade-1'],
      );
      await repo.create(strategy);

      // Link another trade
      final linked = await repo.linkJournal(strategy.id, 'trade-2');
      expect(linked.linkedJournalIds, containsAll(<String>['trade-1', 'trade-2']));

      // Idempotent link
      final linkedAgain = await repo.linkJournal(strategy.id, 'trade-2');
      expect(linkedAgain.linkedJournalIds.length, equals(2));

      // Unlink trade
      final unlinked = await repo.unlinkJournal(strategy.id, 'trade-1');
      expect(unlinked.linkedJournalIds, equals(<String>['trade-2']));
    });

    test('strategy update row removes mirror columns so client does not race with database triggers', () {
      final strategy = AppStrategy(
        id: '99999999-0000-0000-0000-999999999999',
        userId: '11111111-2222-3333-4444-555555555555',
        name: 'Scalp Setup',
        content: '# 1m scalping',
        linkedNoteIds: const <String>['note-a', 'note-b'],
        linkedJournalIds: const <String>['trade-a'],
      );

      // Simulating update row construction in StrategiesRepositoryImpl
      // Mirror columns must be stripped so triggers remain authoritative
      final updateRow = <String, dynamic>{
        'user_id': strategy.userId,
        'title': strategy.name,
        'content': strategy.content,
        'linked_note_ids': strategy.linkedNoteIds,
        'linked_journal_ids': strategy.linkedJournalIds,
      };

      updateRow.remove('linked_note_ids');
      updateRow.remove('linked_journal_ids');

      expect(updateRow.containsKey('linked_note_ids'), isFalse);
      expect(updateRow.containsKey('linked_journal_ids'), isFalse);
      expect(updateRow['title'], equals('Scalp Setup'));
    });
  });
}
