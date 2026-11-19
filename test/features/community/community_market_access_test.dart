import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/market_data/data/asset_market_repository.dart';
import 'package:alphajournal/features/market_data/models/market_snapshot.dart';

class _TrackingMarketRepository extends AssetMarketRepository {
  _TrackingMarketRepository() : super(bundle: rootBundle);

  int communityPreviewCalls = 0;
  int fullSnapshotCalls = 0;

  @override
  Future<MarketSnapshot> communityPreview({bool refresh = false}) async {
    communityPreviewCalls++;
    return const MarketSnapshot(
      manifest: <String, dynamic>{
        'data_source': 'community_preview',
        'limited': true,
      },
      instruments: <MarketInstrument>[],
      articles: <MarketArticle>[],
    );
  }

  @override
  Future<MarketSnapshot> snapshot({bool refresh = false}) async {
    fullSnapshotCalls++;
    return const MarketSnapshot(
      instruments: <MarketInstrument>[],
      articles: <MarketArticle>[],
    );
  }
}

void main() {
  test('Community loads only the bounded market preview', () async {
    final repository = CommunityRepository();
    final market = _TrackingMarketRepository();
    addTearDown(repository.dispose);

    await repository.loadMarketData(source: market);

    expect(market.communityPreviewCalls, 1);
    expect(market.fullSnapshotCalls, 0);
    expect(repository.marketSnapshot?.manifest['limited'], isTrue);
  });
}
