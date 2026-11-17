/// A live or cached market benchmark shown in the Overview index cards.
class MarketIndexItem {
  const MarketIndexItem({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.spark,
    this.isLive = false,
    this.timestamp,
    this.source = 'Latest available',
  });

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final List<double> spark;
  final bool isLive;
  final DateTime? timestamp;
  final String source;

  bool get hasQuote => price.isFinite && price > 0;
  bool get isPositive => changePercent >= 0;

  MarketIndexItem copyWith({
    String? symbol,
    String? name,
    double? price,
    double? changePercent,
    List<double>? spark,
    bool? isLive,
    DateTime? timestamp,
    String? source,
  }) => MarketIndexItem(
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    price: price ?? this.price,
    changePercent: changePercent ?? this.changePercent,
    spark: spark ?? this.spark,
    isLive: isLive ?? this.isLive,
    timestamp: timestamp ?? this.timestamp,
    source: source ?? this.source,
  );
}
