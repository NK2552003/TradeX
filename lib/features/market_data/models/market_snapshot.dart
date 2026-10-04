import 'package:tradex/core/app-ui/app_ui.dart';

class MarketArticle {
  MarketArticle.fromJson(Map<String, dynamic> row)
    : title = row['title'] as String? ?? '',
      summary = row['summary'] as String? ?? '',
      publisher = row['publisher'] as String? ?? '',
      thumbnailUrl = row['thumbnail_url'] as String?,
      link = row['link'] as String? ?? '',
      publishedAt = DateTime.tryParse('${row['published_at']}'),
      contentType = row['content_type'] as String? ?? 'STORY',
      tickers = (row['related_tickers'] as List? ?? [row['ticker']])
          .whereType<String>()
          .toList();
  final String title, summary, publisher, link, contentType;
  final String? thumbnailUrl;
  final DateTime? publishedAt;
  final List<String> tickers;

  bool get isVideo =>
      contentType.toUpperCase() == 'VIDEO' || link.contains('/video/');
}

class MarketInstrument {
  MarketInstrument.fromJson(
    Map<String, dynamic> quote,
    Map<String, dynamic> fundamental, {
    List<double> history = const [],
  }) : raw = Map<String, dynamic>.unmodifiable({...fundamental, ...quote}),
       symbol = quote['ticker'] as String,
       name =
           fundamental['name'] as String? ??
           quote['name'] as String? ??
           quote['ticker'] as String,
       currency = quote['currency'] as String? ?? '',
       market = quote['market'] as String? ?? '',
       price = (quote['price'] as num).toDouble(),
       changePercent = (quote['change_pct'] as num? ?? 0).toDouble(),
       previousClose = (quote['previous_close'] as num?)?.toDouble(),
       volume = (quote['volume'] as num? ?? 0).toDouble(),
       spark = history,
       updatedAt = DateTime.tryParse('${quote['updated_at']}');
  MarketInstrument withHistory(List<double> history) =>
      MarketInstrument.fromJson(
        {
          ...raw,
          'ticker': symbol,
          'name': name,
          'currency': currency,
          'market': market,
          'price': price,
          'change_pct': changePercent,
          'previous_close': previousClose,
          'volume': volume,
          'updated_at': updatedAt?.toIso8601String(),
        },
        raw,
        history: history,
      );
  final Map<String, dynamic> raw;
  final String symbol, name, currency, market;
  final double price, changePercent, volume;
  final double? previousClose;
  final List<double> spark;
  double? get change => previousClose == null ? null : price - previousClose!;
  final DateTime? updatedAt;
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.instruments,
    required this.articles,
    this.topics = const {},
    this.screeners = const {},
    this.manifest = const {},
    this.screenerPayloads = const {},
  });
  final Map<String, dynamic> manifest, screenerPayloads;
  final List<MarketInstrument> instruments;
  final List<MarketArticle> articles;
  final Map<String, List<MarketArticle>> topics;
  final Map<String, List<MarketInstrument>> screeners;
  List<MarketInstrument> get gainers =>
      screeners['top_gainers'] ??
      (instruments.where((q) => q.changePercent > 0).toList()
        ..sort((a, b) => b.changePercent.compareTo(a.changePercent)));
  List<MarketInstrument> get losers =>
      screeners['top_losers'] ??
      (instruments.where((q) => q.changePercent < 0).toList()
        ..sort((a, b) => a.changePercent.compareTo(b.changePercent)));
  List<MarketInstrument> get mostActive =>
      screeners['most_active'] ??
      ([...instruments]..sort((a, b) => b.volume.compareTo(a.volume)));
  List<MarketInstrument> get trending {
    final counts = <String, int>{};
    for (final article in articles) {
      for (final ticker in article.tickers) {
        counts.update(ticker, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return [
      ...instruments,
    ]..sort((a, b) => (counts[b.symbol] ?? 0).compareTo(counts[a.symbol] ?? 0));
  }

  List<MarketArticle> get videos => articles.where((a) => a.isVideo).toList();
}

List<UiCandle> assetCandles(List<dynamic> rows) => rows.map((raw) {
  final row = Map<String, dynamic>.from(raw as Map);
  return UiCandle(
    time: DateTime.parse(row['date'] as String),
    open: (row['open'] as num).toDouble(),
    high: (row['high'] as num).toDouble(),
    low: (row['low'] as num).toDouble(),
    close: (row['close'] as num).toDouble(),
    volume: (row['volume'] as num? ?? 0).toDouble(),
  );
}).toList();
