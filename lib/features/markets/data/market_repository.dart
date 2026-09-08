import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

double? marketNumber(Object? value) {
  final number = value is num ? value.toDouble() : double.tryParse('$value');
  return number != null && number.isFinite ? number : null;
}

String marketValue(num? value, {int decimals = 2}) {
  if (value == null || !value.isFinite) return '—';
  if (value.abs() >= 1e12) return '${(value / 1e12).toStringAsFixed(2)}T';
  if (value.abs() >= 1e9) return '${(value / 1e9).toStringAsFixed(2)}B';
  if (value.abs() >= 1e6) return '${(value / 1e6).toStringAsFixed(2)}M';
  return value.toStringAsFixed(decimals);
}

class MarketInstrument {
  MarketInstrument(this.quote, this.fundamentals);
  final Map<String, dynamic> quote;
  final Map<String, dynamic> fundamentals;
  String get symbol => quote['ticker'] as String;
  String get name => fundamentals['name'] as String? ?? symbol;
  String get market => quote['market'] as String? ?? 'US';
  String get currency => quote['currency'] as String? ?? 'USD';
  String get exchange => quote['exchange'] as String? ?? '—';
  String get sector => fundamentals['sector'] as String? ?? 'Unclassified';
  String get industry => fundamentals['industry'] as String? ?? 'Unclassified';

  double? get price => marketNumber(quote['price']);
  double? get change => marketNumber(quote['change_pct']);
  bool get positive => (change ?? 0) >= 0;
  bool get demo => quote['source'] == 'demo';
  bool get demoFundamentals => fundamentals['source'] == 'demo';
  DateTime? get asOf =>
      DateTime.tryParse('${quote['price_as_of'] ?? quote['updated_at']}');
  String get priceLabel =>
      '${currency == 'INR' ? '₹' : '\$'}${marketValue(price)}';
  String get changeLabel => change == null
      ? '—'
      : '${positive ? '+' : ''}${change!.toStringAsFixed(2)}%';
}

class MarketBar {
  const MarketBar(
    this.time,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
  );
  final DateTime time;
  final double open, high, low, close, volume;

  static MarketBar? parse(Map<String, dynamic> row) {
    final time = DateTime.tryParse('${row['date']}');
    final values = [
      for (final key in ['open', 'high', 'low', 'close'])
        marketNumber(row[key]),
    ];
    if (time == null || values.any((v) => v == null)) return null;
    if (values[1]! < values[2]! ||
        values[1]! < values[0]! ||
        values[1]! < values[3]! ||
        values[2]! > values[0]! ||
        values[2]! > values[3]!) {
      return null;
    }
    return MarketBar(
      time,
      values[0]!,
      values[1]!,
      values[2]!,
      values[3]!,
      marketNumber(row['volume']) ?? 0,
    );
  }
}

class MarketStory {
  MarketStory(this.data);
  final Map<String, dynamic> data;
  String get title => data['title'] as String? ?? 'Untitled story';
  String get summary => data['summary'] as String? ?? '';
  String get publisher => data['publisher'] as String? ?? 'Unknown publisher';
  String get url => data['link'] as String? ?? '';
  String? get thumbnailUrl => data['thumbnail_url'] as String?;
  String get contentType => data['content_type'] as String? ?? 'STORY';

  String get id => url.isNotEmpty ? url : '$publisher:$title';
  String get market => data['market'] as String? ?? 'US';
  bool get demo => data['source'] == 'demo';
  DateTime? get publishedAt => DateTime.tryParse('${data['published_at']}');
  List<String> get symbols => <String>{
    if (data['ticker'] is String) data['ticker'] as String,
    ...((data['related_tickers'] as List?) ?? []).whereType<String>(),
  }.toList();
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.instruments,
    required this.news,
    this.fallback = false,
  });
  final List<MarketInstrument> instruments;
  final List<MarketStory> news;
  final bool fallback;
}

/// Implement these two methods to replace the JSON prototype with your API.
abstract class MarketRepository {
  Future<MarketSnapshot> load();
  Future<List<MarketBar>> history(String symbol);
}

class JsonMarketRepository implements MarketRepository {
  JsonMarketRepository({
    this.baseUrl = const String.fromEnvironment('MARKET_DATA_BASE_URL'),
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final http.Client _client;
  bool _assetMode = true;
  final Map<String, String> _quoteSources = {};

  Future<dynamic> _asset(String path) async =>
      jsonDecode(await rootBundle.loadString('assets/market/$path'));
  Future<dynamic> _remote(String path) async {
    final response = await _client
        .get(Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Market endpoint: ${response.statusCode}');
    }
    return jsonDecode(response.body);
  }

  MarketSnapshot _parse(List<dynamic> payload, {required bool fallback}) {
    final quotes = Map<String, dynamic>.from(payload[0] as Map);
    final fundamentals = Map<String, dynamic>.from(payload[1] as Map);
    final instruments = <MarketInstrument>[];
    for (final entry in quotes.entries) {
      if (entry.value is! Map) continue;
      final quote = Map<String, dynamic>.from(entry.value as Map)
        ..['ticker'] = entry.key;
      if (marketNumber(quote['price']) == null) continue;
      instruments.add(
        MarketInstrument(
          quote,
          Map<String, dynamic>.from(fundamentals[entry.key] as Map? ?? {}),
        ),
      );
    }
    if (instruments.isEmpty) {
      throw const FormatException('No valid quotes in snapshot');
    }
    _quoteSources
      ..clear()
      ..addEntries(
        instruments.map((q) => MapEntry(q.symbol, q.demo ? 'demo' : 'yahoo')),
      );
    final deduped = <String, MarketStory>{};
    for (final row in payload[2] as List) {
      if (row is! Map || row['title'] is! String) continue;
      final story = MarketStory(Map<String, dynamic>.from(row));
      deduped[story.id] = story;
    }
    final news = deduped.values.toList()
      ..sort(
        (a, b) => (b.publishedAt ?? DateTime(1970)).compareTo(
          a.publishedAt ?? DateTime(1970),
        ),
      );
    return MarketSnapshot(
      instruments: instruments,
      news: news,
      fallback: fallback,
    );
  }

  @override
  Future<MarketSnapshot> load() async {
    if (baseUrl.isNotEmpty) {
      try {
        final payload = await Future.wait(
          ['quotes.json', 'fundamentals.json', 'news.json'].map(_remote),
        );
        final snapshot = _parse(payload, fallback: false);
        _assetMode = false;
        return snapshot;
      } catch (_) {
        /* A complete bundled snapshot avoids mixing prices and history. */
      }
    }
    _assetMode = true;
    return _parse(
      await Future.wait(
        ['quotes.json', 'fundamentals.json', 'news.json'].map(_asset),
      ),
      fallback: baseUrl.isNotEmpty,
    );
  }

  @override
  Future<List<MarketBar>> history(String symbol) async {
    final path = 'history/${Uri.encodeComponent(symbol)}.json';
    final raw = await (_assetMode ? _asset(path) : _remote(path));
    if (raw['source'] != null && raw['source'] != _quoteSources[symbol]) {
      return [];
    }
    final rows = <DateTime, MarketBar>{};
    for (final row in raw['data'] as List? ?? []) {
      if (row is! Map) continue;
      final bar = MarketBar.parse(Map<String, dynamic>.from(row));
      if (bar != null) rows[bar.time] = bar;
    }
    return rows.values.toList()..sort((a, b) => a.time.compareTo(b.time));
  }
}

/// Device-local preview preferences. The backend can replace this store without
/// changing the screens. Notes continue using the existing notes repository.
class MarketWorkspaceStore extends ChangeNotifier {
  MarketWorkspaceStore({MarketRepository? repository})
    : repository = repository ?? JsonMarketRepository();
  static final instance = MarketWorkspaceStore();
  final MarketRepository repository;
  MarketSnapshot? snapshot;
  bool loading = false;
  String? error;
  String? persistenceError;
  Map<String, List<String>> watchlists = {
    'Focus list': ['AAPL', 'NVDA', 'RELIANCE.NS', 'INFY.NS'],
    'US technology': ['AAPL', 'MSFT', 'NVDA', 'GOOGL'],
    'India leaders': ['RELIANCE.NS', 'HDFCBANK.NS', 'ICICIBANK.NS'],
  };
  String activeList = 'Focus list';
  Set<String> bookmarks = {};
  final List<Map<String, dynamic>> alerts = [];
  Future<void>? _initialization;
  Future<void> _pendingSave = Future.value();

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('tradex.market.workspace.v1');
      if (raw != null) {
        final state = jsonDecode(raw) as Map;
        watchlists = (state['watchlists'] as Map).map(
          (k, v) => MapEntry('$k', List<String>.from(v as List)),
        );
        if (watchlists.isEmpty) watchlists = {'Focus list': []};
        activeList = watchlists.containsKey(state['activeList'])
            ? state['activeList'] as String
            : watchlists.keys.first;
        bookmarks = Set<String>.from(state['bookmarks'] as List? ?? []);
        alerts.addAll(
          (state['alerts'] as List? ?? []).map(
            (v) => Map<String, dynamic>.from(v as Map),
          ),
        );
      }
    } catch (_) {
      persistenceError = 'Local preferences could not be restored.';
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      snapshot = await repository.load();
    } catch (_) {
      error = 'Market data could not be loaded. Please retry.';
    }
    loading = false;
    notifyListeners();
  }

  List<String> get watched => watchlists[activeList] ?? [];
  void selectList(String name) {
    if (watchlists.containsKey(name)) {
      activeList = name;
      _save();
    }
  }

  bool createList(String name) {
    name = name.trim();
    if (name.isEmpty ||
        name.length > 40 ||
        watchlists.keys.any((k) => k.toLowerCase() == name.toLowerCase())) {
      return false;
    }
    watchlists[name] = [];
    activeList = name;
    _save();
    return true;
  }

  bool renameList(String name) {
    name = name.trim();
    if (name.isEmpty ||
        name.length > 40 ||
        watchlists.keys.any((k) => k.toLowerCase() == name.toLowerCase())) {
      return false;
    }
    final symbols = watchlists.remove(activeList)!;
    watchlists[name] = symbols;
    activeList = name;
    _save();
    return true;
  }

  void deleteList() {
    watchlists.remove(activeList);
    if (watchlists.isEmpty) watchlists['Focus list'] = [];
    activeList = watchlists.keys.first;
    _save();
  }

  void toggleSymbol(String symbol) {
    final list = watchlists[activeList]!;
    list.contains(symbol) ? list.remove(symbol) : list.add(symbol);
    _save();
  }

  void moveSymbol(String symbol, int delta) {
    final list = watchlists[activeList]!;
    final index = list.indexOf(symbol);
    if (index < 0 || index + delta < 0 || index + delta >= list.length) return;
    list.insert(index + delta, list.removeAt(index));
    _save();
  }

  void toggleBookmark(String id) {
    bookmarks.contains(id) ? bookmarks.remove(id) : bookmarks.add(id);
    _save();
  }

  void addAlert(String symbol, double target, bool above) {
    alerts.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'symbol': symbol,
      'target': target,
      'above': above,
    });
    _save();
  }

  void removeAlert(String id) {
    alerts.removeWhere((a) => a['id'] == id);
    _save();
  }

  Future<void> flush() => _pendingSave;

  void _save() {
    notifyListeners();
    final encoded = jsonEncode({
      'watchlists': watchlists,
      'activeList': activeList,
      'bookmarks': bookmarks.toList(),
      'alerts': alerts,
    });
    _pendingSave = _pendingSave.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString('tradex.market.workspace.v1', encoded)) {
          throw StateError('Write failed');
        }
        persistenceError = null;
      } catch (_) {
        persistenceError =
            'Changes are in memory; local storage is unavailable.';
      }
      notifyListeners();
    });
  }
}
