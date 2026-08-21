import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/demo_data_source.dart';

/// Global search across everything the account can reach.
///
/// [kinds] is an allow-list, not a user filter: the caller passes the kinds the
/// signed-in role can actually open, so a partner never gets a trade row that
/// leads nowhere. Narrowing by chip happens in the page, over the rows this
/// returns, so the per-kind counts beside the chips stay honest.
abstract class SearchRepository {
  Future<List<AppSearchResult>> search(
    String query, {
    Set<AppSearchKind> kinds,
  });

  /// Rows to show before anything is typed — a spread across the allowed kinds
  /// rather than a single kind, so the surface advertises what it can find.
  Future<List<AppSearchResult>> getSuggested({Set<AppSearchKind> kinds});

  Future<List<String>> getRecent();
  Future<void> addRecent(String query);
  Future<void> removeRecent(String query);
  Future<void> clearRecent();
}

class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl({DemoDataSource? source})
    : _source = source ?? DemoDataSource.instance;

  final DemoDataSource _source;

  /// Most recent first. The backend moves this to the account, which is why the
  /// shell keeps one repository alive rather than one per page mount.
  final List<String> _recent = <String>[];

  static const int _recentLimit = 8;

  List<AppSearchResult> get _index => _source.searchIndex();

  Iterable<AppSearchResult> _allowed(Set<AppSearchKind> kinds) => kinds.isEmpty
      ? _index
      : _index.where((AppSearchResult r) => kinds.contains(r.kind));

  @override
  Future<List<AppSearchResult>> search(
    String query, {
    Set<AppSearchKind> kinds = const <AppSearchKind>{},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final String needle = query.trim().toLowerCase();
    final Iterable<AppSearchResult> rows = _allowed(kinds);
    if (needle.isEmpty) return rows.toList(growable: false);

    final List<AppSearchResult> matches = rows
        .where((AppSearchResult r) => _matches(r, needle))
        .toList();
    // Prefix hits first, then the shortest title — a search for "AAP" should
    // land on the instrument before a note that happens to mention it.
    matches.sort((AppSearchResult a, AppSearchResult b) {
      final bool aStarts = a.title.toLowerCase().startsWith(needle);
      final bool bStarts = b.title.toLowerCase().startsWith(needle);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.title.length.compareTo(b.title.length);
    });
    return matches;
  }

  bool _matches(AppSearchResult row, String needle) =>
      row.title.toLowerCase().contains(needle) ||
      (row.subtitle ?? '').toLowerCase().contains(needle) ||
      (row.meta ?? '').toLowerCase().contains(needle);

  @override
  Future<List<AppSearchResult>> getSuggested({
    Set<AppSearchKind> kinds = const <AppSearchKind>{},
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 140));
    final Set<AppSearchKind> wanted = kinds.isEmpty
        ? AppSearchKind.values.toSet()
        : kinds;
    return <AppSearchResult>[
      for (final AppSearchKind kind in AppSearchKind.values)
        if (wanted.contains(kind))
          ..._index.where((AppSearchResult r) => r.kind == kind).take(2),
    ];
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
    if (_recent.length > _recentLimit) _recent.removeLast();
  }

  @override
  Future<void> removeRecent(String query) async => _recent.removeWhere(
    (String q) => q.toLowerCase() == query.trim().toLowerCase(),
  );

  @override
  Future<void> clearRecent() async => _recent.clear();
}
