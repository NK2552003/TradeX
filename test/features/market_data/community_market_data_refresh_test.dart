import 'package:flutter_test/flutter_test.dart';

import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';

class _SnapshotMarketRepository extends AssetMarketRepository {
  _SnapshotMarketRepository(this.snapshotValue);

  final MarketSnapshot snapshotValue;
  int attempts = 0;
  bool failFirst = false;

  @override
  Future<MarketSnapshot> communityPreview({bool refresh = false}) async {
    attempts++;
    if (failFirst && attempts == 1) {
      throw StateError('temporary market failure');
    }
    return snapshotValue;
  }
}

void main() {
  test(
    'market data keeps the latest article first and builds live trends',
    () async {
      final DateTime now = DateTime.now();
      final MarketSnapshot snapshot = MarketSnapshot(
        instruments: <MarketInstrument>[
          MarketInstrument.fromJson(
            <String, dynamic>{
              'ticker': 'AAPL',
              'price': 250.0,
              'change_pct': 2.4,
              'market': 'US',
              'currency': 'USD',
            },
            <String, dynamic>{'name': 'Apple'},
          ),
        ],
        articles: <MarketArticle>[
          MarketArticle.fromJson(<String, dynamic>{
            'title': 'Older story',
            'publisher': 'Market Desk',
            'link': 'https://example.com/older',
            'published_at': now
                .subtract(const Duration(days: 1))
                .toIso8601String(),
            'related_tickers': <String>['AAPL'],
          }),
          MarketArticle.fromJson(<String, dynamic>{
            'title': 'Newest story',
            'publisher': 'Market Desk',
            'link': 'https://example.com/newest',
            'published_at': now.toIso8601String(),
            'related_tickers': <String>['AAPL'],
          }),
        ],
      );
      final CommunityRepository repository = CommunityRepository();
      addTearDown(repository.dispose);

      await repository.loadMarketData(
        source: _SnapshotMarketRepository(snapshot),
      );

      expect(repository.news.map((item) => item.headline), <String>[
        'Newest story',
        'Older story',
      ]);
      expect(repository.trending.first.topic, r'$AAPL');
      expect(repository.trending.first.postCount, '+2.40%');
    },
  );

  test('market data can retry after a temporary failure', () async {
    final _SnapshotMarketRepository source = _SnapshotMarketRepository(
      const MarketSnapshot(
        instruments: <MarketInstrument>[],
        articles: <MarketArticle>[],
      ),
    )..failFirst = true;
    final CommunityRepository repository = CommunityRepository();
    addTearDown(repository.dispose);

    await repository.loadMarketData(source: source);
    expect(repository.marketDataError, isNotNull);

    await repository.loadMarketData(source: source);
    expect(source.attempts, 2);
    expect(repository.marketDataError, isNull);
  });
}
