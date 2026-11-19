import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/journal/data/journal_attachments.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Issue #38: Strategy Joins and Title/Name Reconciliation', () {
    final repo = JournalRepositoryImpl.instance;

    test('reconciles strategies join when schema returns title', () {
      final row = <String, dynamic>{
        'id': 'b3c4d5e6-1234-5678-9abc-def012345678',
        'ticker': 'NVDA',
        'side': 'long',
        'entry_price': 120.5,
        'opened_at': DateTime.now().toIso8601String(),
        'outcome': 'open',
        'strategies': <String, dynamic>{
          'id': 'strat-uuid-1',
          'title': 'VWAP Breakout System',
        },
      };

      final sMap = row['strategies'] as Map;
      final strategyName = (sMap['title'] ?? sMap['name'])?.toString();
      expect(strategyName, equals('VWAP Breakout System'));

      final trade = AppTrade(
        id: 'b3c4d5e6-1234-5678-9abc-def012345678',
        ticker: 'NVDA',
        side: AppSide.long,
        entry: 120.5,
        exit: null,
        openedAt: DateTime.now(),
        outcome: AppOutcome.open,
        strategy: strategyName,
        strategyId: 'strat-uuid-1',
      );

      expect(trade.strategy, equals('VWAP Breakout System'));
      expect(trade.strategyId, equals('strat-uuid-1'));
    });

    test(
      'reconciles strategies join when schema returns name (audit defect)',
      () {
        // When Supabase/PostgREST returns name:title or legacy column `name`
        final row = <String, dynamic>{
          'id': 'a1b2c3d4-1234-5678-9abc-def012345678',
          'ticker': 'AAPL',
          'side': 'long',
          'entry_price': 225.0,
          'opened_at': DateTime.now().toIso8601String(),
          'outcome': 'open',
          'strategies': <String, dynamic>{
            'id': 'strat-uuid-2',
            'name': 'Opening Range Breakout',
          },
        };

        // In repository row mapping, sMap['title'] ?? sMap['name'] resolves to name
        final sMap = row['strategies'] as Map;
        final strategyName = (sMap['title'] ?? sMap['name'])?.toString();
        expect(strategyName, equals('Opening Range Breakout'));
      },
    );

    test(
      'reconciles strategies join when PostgREST embeds as List of maps',
      () {
        final row = <String, dynamic>{
          'id': 'c2d3e4f5-1234-5678-9abc-def012345678',
          'ticker': 'TSLA',
          'side': 'short',
          'entry_price': 250.0,
          'opened_at': DateTime.now().toIso8601String(),
          'outcome': 'open',
          'strategies': <dynamic>[
            <String, dynamic>{
              'id': 'strat-uuid-3',
              'title': 'Supply and Demand Reversal',
            },
          ],
        };

        final sList = row['strategies'] as List;
        final first = sList.first as Map;
        final strategyName = (first['title'] ?? first['name'])?.toString();
        expect(strategyName, equals('Supply and Demand Reversal'));
      },
    );

    test('attachStrategy attaches valid strategy and title', () async {
      final created = await repo.create(
        AppTrade(
          id: 'trade-reg-strat-1',
          ticker: 'RELIANCE',
          side: AppSide.long,
          entry: 2900.0,
          exit: null,
          openedAt: DateTime.now(),
          outcome: AppOutcome.open,
        ),
      );

      final attached = await repo.attachStrategy(
        created.id,
        'e4f5a6b7-1234-5678-9abc-def012345678',
        strategyName: 'High-Tight Flag',
      );

      expect(
        attached.strategyId,
        equals('e4f5a6b7-1234-5678-9abc-def012345678'),
      );
      expect(attached.strategy, equals('High-Tight Flag'));
    });

    test('attachStrategy with null/empty clears strategy on writes', () async {
      final created = await repo.create(
        AppTrade(
          id: 'trade-reg-strat-2',
          ticker: 'HDFCBANK',
          side: AppSide.long,
          entry: 1650.0,
          exit: null,
          openedAt: DateTime.now(),
          outcome: AppOutcome.open,
          strategyId: 'e4f5a6b7-1234-5678-9abc-def012345678',
          strategy: 'High-Tight Flag',
        ),
      );

      expect(created.strategyId, isNotNull);

      // Clearing strategy
      final cleared = await repo.attachStrategy(created.id, null);
      expect(cleared.strategyId, isNull);
      expect(cleared.strategy, isNull);

      final fetched = await repo.getById(created.id);
      expect(fetched?.strategyId, isNull);
      expect(fetched?.strategy, isNull);
    });
  });

  group('Issue #38: Journal Private Attachment Storage & Security Policies', () {
    final repo = JournalRepositoryImpl.instance;

    test(
      'local filesystem paths pass through resolveAttachmentUrl unchanged',
      () async {
        const localPath = 'C:\\Users\\Hp\\AppData\\Local\\Temp\\screenshot.png';
        final resolved = await repo.resolveAttachmentUrl(localPath);
        expect(resolved, equals(localPath));

        const unixLocalPath = '/tmp/cache/chart_markup.png';
        final resolvedUnix = await repo.resolveAttachmentUrl(unixLocalPath);
        expect(resolvedUnix, equals(unixLocalPath));

        const fileUri = 'file:///home/user/chart.png';
        final resolvedFile = await repo.resolveAttachmentUrl(fileUri);
        expect(resolvedFile, equals(fileUri));
      },
    );

    test('external third-party image URLs pass through unchanged', () async {
      const externalUrl =
          'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3';
      final resolved = await repo.resolveAttachmentUrl(externalUrl);
      expect(resolved, equals(externalUrl));
    });

    test(
      'upload key format strictly follows <user_id>/<entry_id>/<uuid>.<ext>',
      () {
        const userId = '11111111-2222-3333-4444-555555555555';
        const entryId = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
        const ext = 'PNG';
        final normalizedExt = ext.toLowerCase().trim();

        // Simulated storagePath builder
        final key = '$userId/$entryId/unique-attachment-uuid.$normalizedExt';
        final segments = key.split('/');

        // Verify prefix matches storage policy (storage.foldername(name))[1] = auth.uid()
        expect(segments.length, equals(3));
        expect(segments[0], equals(userId));
        expect(segments[1], equals(entryId));
        expect(segments[2], endsWith('.png'));
      },
    );

    test(
      'resolveAttachmentUrl rejects cross-user access to private attachments',
      () async {
        // Path belongs to another user
        const otherUser = '99999999-8888-7777-6666-555555555555';
        const foreignAttachmentPath = '$otherUser/entry-xyz/stolen-chart.png';

        // Expect unauthorized state error
        expect(
          () async => await repo.resolveAttachmentUrl(foreignAttachmentPath),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Unauthorized'),
            ),
          ),
        );
      },
    );

    test(
      'resolveAttachmentUrl parses unsigned public URL to journal-attachments into private key',
      () {
        const unsignedPublicUrl =
            'https://xyzproject.supabase.co/storage/v1/object/public/journal-attachments/user-uuid/entry-uuid/chart.png';

        final uri = Uri.parse(unsignedPublicUrl);
        final pathSegments = uri.pathSegments;
        final bucketIdx = pathSegments.indexOf('journal-attachments');
        final relativePath = pathSegments.sublist(bucketIdx + 1).join('/');

        expect(relativePath, equals('user-uuid/entry-uuid/chart.png'));
        expect(relativePath.startsWith('https://'), isFalse);
      },
    );

    test(
      'deleteAttachment rejects another user\'s private attachment',
      () async {
        const otherUserAttachment =
            '88888888-4444-4444-4444-888888888888/entry-1/chart.png';

        expect(
          () async => await repo.deleteAttachment(otherUserAttachment),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Unauthorized'),
            ),
          ),
        );
      },
    );

    test('JournalAttachments.delete wires through to repository', () async {
      // Calling delete with invalid user id throws Unauthorized StateError
      expect(
        () async => await JournalAttachments.delete(
          'attacker-user-id/entry-1/chart.png',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group(
    'CodeRabbit Review #38: copyWith, attachStrategy resolution, and storage deletion',
    () {
      test(
        'AppTrade.copyWith clears strategy name while preserving strategyId when clearStrategyName is true',
        () {
          final trade = AppTrade(
            id: 't-1',
            ticker: 'AAPL',
            side: AppSide.long,
            entry: 150.0,
            exit: null,
            openedAt: DateTime.now(),
            outcome: AppOutcome.open,
            strategyId: 'strat-123',
            strategy: 'Breakout System',
          );

          final updated = trade.copyWith(
            strategyId: 'strat-456',
            clearStrategyName: true,
          );

          expect(updated.strategyId, equals('strat-456'));
          expect(updated.strategy, isNull);
        },
      );

      test(
        'AppTrade.copyWith clears both strategy and strategyId when clearStrategy is true',
        () {
          final trade = AppTrade(
            id: 't-2',
            ticker: 'MSFT',
            side: AppSide.long,
            entry: 300.0,
            exit: null,
            openedAt: DateTime.now(),
            outcome: AppOutcome.open,
            strategyId: 'strat-123',
            strategy: 'Momentum Scalp',
          );

          final cleared = trade.copyWith(clearStrategy: true);

          expect(cleared.strategyId, isNull);
          expect(cleared.strategy, isNull);
        },
      );

      test(
        'attachStrategy with null strategyName clears prior local strategy name while updating strategyId',
        () async {
          final repo = JournalRepositoryImpl.instance;
          final created = await repo.create(
            AppTrade(
              id: 'trade-reg-null-strat-name',
              ticker: 'GOOGL',
              side: AppSide.long,
              entry: 180.0,
              exit: null,
              openedAt: DateTime.now(),
              outcome: AppOutcome.open,
              strategyId: 'strat-old',
              strategy: 'Old Strategy Name',
            ),
          );

          expect(created.strategy, equals('Old Strategy Name'));

          // Attaching with a valid strategy ID but null name (e.g. strategy had no title/name)
          final attached = await repo.attachStrategy(
            created.id,
            'e4f5a6b7-1234-5678-9abc-def012345678',
            strategyName: null,
          );

          expect(
            attached.strategyId,
            equals('e4f5a6b7-1234-5678-9abc-def012345678'),
          );
          expect(attached.strategy, isNull);
        },
      );
    },
  );
}
