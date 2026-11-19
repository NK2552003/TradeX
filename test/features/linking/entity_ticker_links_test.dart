import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/auth/models/auth_user_role.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/journal/data/journal_repository.dart';
import 'package:alphajournal/features/linking/entity_ticker_links_repository.dart';
import 'package:alphajournal/features/messages/data/messages_repository.dart';
import 'package:alphajournal/features/notes/data/notes_repository.dart';
import 'package:alphajournal/features/strategies/data/strategies_repository.dart';

void main() {
  setUp(() {
    EntityTickerLinksRepository.instance.clearForTesting();
  });

  group('EntityTickerLinksRepository Unit Tests', () {
    test('extractTickers pulls cashtags and ignores dollar amounts', () {
      final text = 'Bought \$AAPL at \$150 and \$TSLA at \$200 with \$^NSEI';
      final tickers = EntityTickerLinksRepository.extractTickers(text);

      expect(tickers, containsAll(<String>['AAPL', 'TSLA', '^NSEI']));
      expect(tickers, isNot(contains('150')));
      expect(tickers, isNot(contains('200')));
    });

    test('recordLinks saves and queries ticker links accurately', () async {
      await EntityTickerLinksRepository.instance.recordLinks(
        entityType: 'note',
        entityId: 'note_123',
        tickers: <String>['AAPL', 'MSFT'],
        contextSource: 'inline',
      );

      final aaplLinks = EntityTickerLinksRepository.instance.getLinksForTicker(
        'AAPL',
      );
      expect(aaplLinks.length, 1);
      expect(aaplLinks.first.entityType, 'note');
      expect(aaplLinks.first.entityId, 'note_123');
      expect(aaplLinks.first.ticker, 'AAPL');

      final entityLinks = EntityTickerLinksRepository.instance
          .getLinksForEntity('note', 'note_123');
      expect(entityLinks.length, 2);
      expect(
        entityLinks.map((l) => l.ticker),
        containsAll(<String>['AAPL', 'MSFT']),
      );
    });
  });

  group('Entity Ticker Links Cross-Surface Integration Tests', () {
    test(
      'Notes repository syncs linked tickers to EntityTickerLinksRepository',
      () async {
        final noteRepo = NotesRepositoryImpl.instance;
        final draft = AppNote(
          id: 'test_note_link_1',
          title: 'Breakout Plan',
          content: 'Watching \$NVDA closely around 120 level.',
          tags: const <String>['tech'],
          linkedTickers: const <String>['NVDA'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await noteRepo.create(draft);

        final nvdaLinks = EntityTickerLinksRepository.instance
            .getLinksForTicker('NVDA');
        expect(
          nvdaLinks.any(
            (l) => l.entityType == 'note' && l.entityId == 'test_note_link_1',
          ),
          isTrue,
        );

        await noteRepo.delete('test_note_link_1');
        final afterDelete = EntityTickerLinksRepository.instance
            .getLinksForTicker('NVDA');
        expect(
          afterDelete.any((l) => l.entityId == 'test_note_link_1'),
          isFalse,
        );
      },
    );

    test(
      'Journal repository syncs trade ticker to EntityTickerLinksRepository',
      () async {
        final journalRepo = JournalRepositoryImpl.instance;
        final trade = AppTrade(
          id: 'test_trd_link_1',
          ticker: 'RELIANCE',
          side: AppSide.long,
          entry: 2850,
          exit: 3000,
          openedAt: DateTime.now(),
          content: 'Long entry on 15m breakout for \$RELIANCE',
        );

        await journalRepo.create(trade);

        final relianceLinks = EntityTickerLinksRepository.instance
            .getLinksForTicker('RELIANCE');
        expect(
          relianceLinks.any(
            (l) => l.entityType == 'journal' && l.entityId == 'test_trd_link_1',
          ),
          isTrue,
        );

        await journalRepo.delete('test_trd_link_1');
        final afterDelete = EntityTickerLinksRepository.instance
            .getLinksForTicker('RELIANCE');
        expect(
          afterDelete.any((l) => l.entityId == 'test_trd_link_1'),
          isFalse,
        );
      },
    );

    test(
      'Strategies repository syncs playbook tickers to EntityTickerLinksRepository',
      () async {
        final strategyRepo = StrategiesRepositoryImpl.instance;
        final strategy = AppStrategy(
          id: 'test_stg_link_1',
          name: 'Crypto Momentum',
          content:
              'Trading setup for \$BTCUSDT and \$ETHUSDT when above 50 SMA.',
          linkedTickers: const <String>['BTCUSDT'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await strategyRepo.create(strategy);

        final btcLinks = EntityTickerLinksRepository.instance.getLinksForTicker(
          'BTCUSDT',
        );
        expect(
          btcLinks.any(
            (l) =>
                l.entityType == 'strategy' && l.entityId == 'test_stg_link_1',
          ),
          isTrue,
        );

        await strategyRepo.delete('test_stg_link_1');
        final afterDelete = EntityTickerLinksRepository.instance
            .getLinksForTicker('BTCUSDT');
        expect(
          afterDelete.any((l) => l.entityId == 'test_stg_link_1'),
          isFalse,
        );
      },
    );

    test(
      'Community repository syncs post tickers to EntityTickerLinksRepository',
      () async {
        final communityRepo = CommunityRepository();
        const author = CommunityAuthor(
          id: 'user_tester',
          handle: 'testtrader',
          displayName: 'Test Trader',
          userRole: UserRole.customer,
        );

        communityRepo.createPost(
          body: 'Huge volume spike on \$TATAMOTORS today!',
          tickers: const <String>['TATAMOTORS'],
          author: author,
        );

        final tataLinks = EntityTickerLinksRepository.instance
            .getLinksForTicker('TATAMOTORS');
        expect(tataLinks.any((l) => l.entityType == 'community_post'), isTrue);
      },
    );

    test(
      'Messages repository syncs message tickers to EntityTickerLinksRepository',
      () async {
        final messagesRepo = MessagesRepository.instance;
        const threadId = 'thread_test_link_1';

        messagesRepo.sendMessage(
          threadId,
          body: 'Check out the chart on \$INFY right now!',
        );

        final infyLinks = EntityTickerLinksRepository.instance
            .getLinksForTicker('INFY');
        expect(infyLinks.any((l) => l.entityType == 'message'), isTrue);
      },
    );
  });
}
