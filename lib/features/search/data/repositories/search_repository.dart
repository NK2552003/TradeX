import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Human label for a search result kind, used by filter chips.
String appSearchKindLabel(AppSearchKind kind) => switch (kind) {
  AppSearchKind.trade => 'Trades',
  AppSearchKind.strategy => 'Strategies',
  AppSearchKind.ticker => 'Instruments',
  AppSearchKind.trader => 'Traders',
  AppSearchKind.post => 'Posts',
  AppSearchKind.note => 'Notes',
};

abstract class SearchRepository {
  Future<List<AppSearchResult>> search(
    String query, {
    Set<AppSearchKind> kinds,
  });
  Future<List<AppSearchResult>> getSuggested();
  Future<List<String>> getRecent();
  Future<void> addRecent(String query);
  Future<void> clearRecent();
}

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance;

  final DemoDataSource _source;
  final List<String> _recent = <String>[];

  List<AppSearchResult> get _index => _source.searchIndex();

  @override
  Future<List<AppSearchResult>> search(
    String query, {
    Set<AppSearchKind> kinds = const <AppSearchKind>{},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final String needle = query.trim().toLowerCase();
    Iterable<AppSearchResult> rows = _index;
    if (kinds.isNotEmpty) {
      rows = rows.where((AppSearchResult r) => kinds.contains(r.kind));
    }
    if (needle.isEmpty) {
      return rows.take(12).toList(growable: false);
    }
    final List<AppSearchResult> matches = rows
        .where(
          (AppSearchResult r) =>
              r.title.toLowerCase().contains(needle) ||
              (r.subtitle ?? '').toLowerCase().contains(needle) ||
              (r.meta ?? '').toLowerCase().contains(needle),
        )
        .toList();
    matches.sort((AppSearchResult a, AppSearchResult b) {
      final bool aStarts = a.title.toLowerCase().startsWith(needle);
      final bool bStarts = b.title.toLowerCase().startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.title.length.compareTo(b.title.length);
    });
    return matches;
  }

  @override
  Future<List<AppSearchResult>> getSuggested() async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    return _index
        .where((AppSearchResult r) => r.kind == AppSearchKind.ticker)
        .take(6)
        .toList(growable: false);
  }

  @override
  Future<List<String>> getRecent() async => List<String>.from(_recent);

  @override
  Future<void> addRecent(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _recent
      ..removeWhere((String q) => q.toLowerCase() == trimmed.toLowerCase())
      ..insert(0, trimmed);
    if (_recent.length > 8) _recent.removeLast();
  }

  @override
  Future<void> clearRecent() async => _recent.clear();
}
