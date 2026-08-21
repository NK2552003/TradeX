import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/search/data/repositories/search_repository.dart';

/// Global search surface behind the header field and the ⌘K affordance.
///
/// The page knows how to find things; it does not know where they live. The
/// shell passes the kinds this role can open along with the label of the
/// surface behind each one, so a partner searching the desk never sees a trade
/// row that leads nowhere and every hit can name its destination.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    this.repository,
    this.initialQuery,
    this.destinations = const <AppSearchKind, String>{},
    this.onOpen,
  });

  final SearchRepository? repository;

  /// Query to run on arrival, for a hand-off from the header field or a tapped
  /// `$TICKER`.
  final String? initialQuery;

  /// Kind to the label of the surface that opens it. A kind missing from the
  /// map is never searched, so results and navigation always agree.
  final Map<AppSearchKind, String> destinations;

  /// Asks the shell to open a hit.
  final ValueChanged<AppSearchResult>? onOpen;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late final SearchRepository _repo =
      widget.repository ?? SearchRepositoryImpl();
  late final TextEditingController _field = TextEditingController(
    text: widget.initialQuery ?? '',
  );

  /// Typing runs the query, so a keystroke does not become a request.
  Timer? _debounce;
  static const Duration _debounceDelay = Duration(milliseconds: 240);

  List<AppSearchResult> _results = const <AppSearchResult>[];
  List<AppSearchResult> _suggested = const <AppSearchResult>[];
  List<String> _recent = const <String>[];

  /// Chips the reader has narrowed to. Empty means "everything this role can
  /// reach", which is the honest default rather than a hidden preference.
  Set<AppSearchKind> _kinds = const <AppSearchKind>{};

  String _query = '';
  bool _loading = true;
  bool _searching = false;

  /// Kinds worth searching for this role, in the order the design system
  /// declares them so the chips never reshuffle between roles.
  Set<AppSearchKind> get _reachable => <AppSearchKind>{
    for (final AppSearchKind kind in AppSearchKind.values)
      if (widget.destinations.containsKey(kind)) kind,
  };

  @override
  void initState() {
    super.initState();
    _query = (widget.initialQuery ?? '').trim();
    _bootstrap();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _repo.getSuggested(kinds: _reachable),
      _repo.getRecent(),
    ]);
    if (!mounted) return;
    setState(() {
      _suggested = results[0]! as List<AppSearchResult>;
      _recent = results[1]! as List<String>;
      _loading = false;
    });
    if (_query.isNotEmpty) await _run(_query);
  }

  /// Runs the query the field currently holds. Late responses are dropped by
  /// comparing the query back, so a slow request cannot overwrite a newer one.
  Future<void> _run(String query) async {
    setState(() => _searching = true);
    final List<AppSearchResult> rows = await _repo.search(
      query,
      kinds: _reachable,
    );
    if (!mounted || query.trim() != _query) return;
    setState(() {
      _results = rows;
      _searching = false;
    });
  }

  void _onChanged(String value) {
    final String next = value.trim();
    setState(() => _query = next);
    _debounce?.cancel();
    if (next.isEmpty) {
      setState(() {
        _results = const <AppSearchResult>[];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(_debounceDelay, () => _run(next));
  }

  /// Committing a query is what makes it recent — a half-typed word is not a
  /// search the reader meant to keep.
  Future<void> _submit(String value) async {
    final String next = value.trim();
    if (next.isEmpty) return;
    _debounce?.cancel();
    await _repo.addRecent(next);
    final List<String> recent = await _repo.getRecent();
    if (!mounted) return;
    setState(() {
      _query = next;
      _recent = recent;
    });
    await _run(next);
  }

  Future<void> _useRecent(String query) async {
    _field.text = query;
    _field.selection = TextSelection.collapsed(offset: query.length);
    setState(() => _query = query);
    await _submit(query);
  }

  Future<void> _forgetRecent(String query) async {
    await _repo.removeRecent(query);
    final List<String> recent = await _repo.getRecent();
    if (!mounted) return;
    setState(() => _recent = recent);
  }

  Future<void> _clearRecent() async {
    await _repo.clearRecent();
    if (!mounted) return;
    setState(() => _recent = const <String>[]);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _field.clear();
    setState(() {
      _query = '';
      _results = const <AppSearchResult>[];
      _searching = false;
    });
  }

  Future<void> _open(AppSearchResult result) async {
    // Following a hit is the strongest signal the query was useful, so it is
    // kept even when the reader never pressed enter.
    if (_query.isNotEmpty) await _repo.addRecent(_query);
    if (!mounted) return;
    widget.onOpen?.call(result);
  }

  void _toggleKind(AppSearchKind kind) => setState(() {
    final Set<AppSearchKind> next = <AppSearchKind>{..._kinds};
    if (!next.remove(kind)) next.add(kind);
    _kinds = next;
  });

  /// The rows on screen: what the query returned, narrowed by the chips.
  List<AppSearchResult> get _visible {
    final List<AppSearchResult> rows = _query.isEmpty ? _suggested : _results;
    if (_kinds.isEmpty) return rows;
    return rows
        .where((AppSearchResult r) => _kinds.contains(r.kind))
        .toList(growable: false);
  }

  /// Hits per kind for the query, before the chips narrow anything — the chips
  /// have to be able to tell you what selecting them would show.
  Map<AppSearchKind, int> get _counts {
    final List<AppSearchResult> rows = _query.isEmpty ? _suggested : _results;
    final Map<AppSearchKind, int> tally = <AppSearchKind, int>{};
    for (final AppSearchResult r in rows) {
      tally[r.kind] = (tally[r.kind] ?? 0) + 1;
    }
    return tally;
  }

  Map<AppSearchKind, List<AppSearchResult>> get _grouped {
    final Map<AppSearchKind, List<AppSearchResult>> groups =
        <AppSearchKind, List<AppSearchResult>>{};
    for (final AppSearchResult r in _visible) {
      groups.putIfAbsent(r.kind, () => <AppSearchResult>[]).add(r);
    }
    return groups;
  }

  String get _subtitle {
    if (_loading) return 'Opening the index…';
    if (widget.destinations.isEmpty) {
      return 'Nothing is searchable from this workspace yet';
    }
    if (_query.isEmpty) {
      final String kinds = _reachable
          .map(appSearchKindLabel)
          .map((String label) => label.toLowerCase())
          .join(', ');
      return 'Search across $kinds';
    }
    if (_searching) return 'Searching for “$_query”…';
    final int total = _visible.length;
    final String scope = _kinds.isEmpty
        ? ''
        : ' in ${_kinds.map(appSearchKindLabel).join(', ').toLowerCase()}';
    return '${total == 0 ? 'No' : total} '
        '${total == 1 ? 'match' : 'matches'} for “$_query”$scope';
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return AppPageBlock(
      title: 'Search',
      subtitle: _subtitle,
      actions: <Widget>[
        if (_query.isNotEmpty)
          UiButton(
            label: 'Clear',
            leadingIcon: Icons.close_rounded,
            variant: UiVariant.outline,
            intent: UiIntent.neutral,
            size: UiSize.sm,
            hideLabelOnMobile: true,
            onPressed: _clearQuery,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFadeIn(child: _searchBar()),
          if (_reachable.length > 1) ...<Widget>[
            UiGap.v(theme.spacing.md),
            AppFadeIn(delay: AppMotion.step, child: _kindChips()),
          ],
          UiGap.v(theme.spacing.lg),
          AppFadeIn(
            delay: AppMotion.step * 2,
            child: AppDashboardLayoutBlock(
              main: <Widget>[_resultsCard()],
              side: <Widget>[_recentCard(), _destinationsCard()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => UiInput.search(
    controller: _field,
    hintText: 'Instruments, trades, notes, playbooks, people',
    loading: _searching,
    autofocus: !context.uiRes.isMobile,
    enabled: widget.destinations.isNotEmpty,
    onChanged: _onChanged,
    onSubmitted: _submit,
    onClear: _clearQuery,
    semanticLabel: 'Search everything',
  );

  Widget _kindChips() {
    final Map<AppSearchKind, int> counts = _counts;
    return Wrap(
      spacing: context.sp(context.ui.spacing.xs),
      runSpacing: context.sp(context.ui.spacing.xs),
      children: <Widget>[
        for (final AppSearchKind kind in _reachable)
          UiBadge(
            label: appSearchKindLabel(kind),
            icon: appSearchKindIcon(kind),
            size: UiSize.md,
            filled: _kinds.contains(kind),
            intent: _kinds.contains(kind) ? UiIntent.primary : UiIntent.neutral,
            trailingIcon: _kinds.contains(kind) ? Icons.check_rounded : null,
            tooltip: 'Opens in ${widget.destinations[kind]}',
            onTap: counts[kind] == null && !_kinds.contains(kind)
                ? null
                : () => _toggleKind(kind),
          ),
        if (_kinds.isNotEmpty)
          UiButton(
            label: 'All kinds',
            leadingIcon: Icons.filter_alt_off_outlined,
            variant: UiVariant.ghost,
            intent: UiIntent.neutral,
            size: UiSize.xs,
            onPressed: () => setState(() => _kinds = const <AppSearchKind>{}),
          ),
      ],
    );
  }

  Widget _resultsCard() {
    if (widget.destinations.isEmpty) {
      return UiCard(
        title: 'Search',
        child: UiEmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing to search here',
          message:
              'This workspace has no searchable surfaces yet. Switch roles or '
              'open a workspace with trades, playbooks or people.',
        ),
      );
    }

    final Map<AppSearchKind, List<AppSearchResult>> groups = _grouped;
    return UiCard(
      title: _query.isEmpty ? 'Start here' : 'Results',
      subtitle: _query.isEmpty
          ? 'A sample of everything this workspace can find'
          : 'Grouped by kind · newest index',
      child: UiAsyncView(
        loading: _loading || (_searching && _results.isEmpty),
        loadingMessage: 'Searching…',
        isEmpty: groups.isEmpty,
        emptyTitle: _query.isEmpty ? 'The index is empty' : 'No matches',
        emptyMessage: _query.isEmpty
            ? 'Nothing has been logged yet, so there is nothing to find.'
            : _kinds.isEmpty
            ? 'Try a ticker, a tag, a playbook name or a trader handle.'
            : 'Nothing of that kind matches “$_query”.',
        emptyIcon: Icons.search_off_rounded,
        emptyAction: _kinds.isEmpty
            ? null
            : UiButton(
                label: 'Search all kinds',
                leadingIcon: Icons.filter_alt_off_outlined,
                variant: UiVariant.outline,
                onPressed: () =>
                    setState(() => _kinds = const <AppSearchKind>{}),
              ),
        builder: (BuildContext ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final MapEntry<AppSearchKind, List<AppSearchResult>> group
                in groups.entries)
              ..._group(group.key, group.value),
          ],
        ),
      ),
    );
  }

  List<Widget> _group(AppSearchKind kind, List<AppSearchResult> rows) {
    final UiTheme theme = context.ui;
    final String? destination = widget.destinations[kind];
    return <Widget>[
      Padding(
        padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
        child: Row(
          children: <Widget>[
            Icon(
              appSearchKindIcon(kind),
              size: context.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundMuted,
            ),
            UiGap.h(theme.spacing.xs),
            Text(
              appSearchKindLabel(kind),
              style: context.uiText.label.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
            UiGap.h(theme.spacing.xs),
            UiBadge.count(rows.length, size: UiSize.xs),
            const Spacer(),
            if (destination != null)
              Text(
                'Opens in $destination',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                ),
              ),
          ],
        ),
      ),
      for (int i = 0; i < rows.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: AppFadeIn(
            delay: AppMotion.step * (i < 6 ? i : 6),
            child: AppSearchResultTile(
              result: rows[i],
              onTap: () => _open(rows[i]),
            ),
          ),
        ),
      UiGap.v(theme.spacing.md),
    ];
  }

  Widget _recentCard() => UiCard(
    title: 'Recent searches',
    subtitle: _recent.isEmpty ? 'Nothing yet' : '${_recent.length} kept',
    actions: <Widget>[
      if (_recent.isNotEmpty)
        UiButton(
          label: 'Clear',
          variant: UiVariant.ghost,
          intent: UiIntent.neutral,
          size: UiSize.xs,
          onPressed: _clearRecent,
        ),
    ],
    child: _recent.isEmpty
        ? UiCallout(
            title: 'Your searches stay on this device',
            message:
                'Press enter on a query and it lands here for one tap next time.',
            icon: Icons.history_rounded,
            intent: UiIntent.info,
          )
        : Wrap(
            spacing: context.sp(context.ui.spacing.xs),
            runSpacing: context.sp(context.ui.spacing.xs),
            children: <Widget>[
              for (final String query in _recent)
                UiBadge(
                  label: query,
                  icon: Icons.history_rounded,
                  maxWidth: context.sz(220),
                  onTap: () => _useRecent(query),
                  onRemove: () => _forgetRecent(query),
                ),
            ],
          ),
  );

  /// Spells out where each kind of hit goes for this role, so the reader can
  /// predict a tap before making it.
  Widget _destinationsCard() {
    final UiTheme theme = context.ui;
    return UiCard(
      title: 'Where results open',
      subtitle: 'Follows the sidebar you have',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final AppSearchKind kind in _reachable)
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
              child: Row(
                children: <Widget>[
                  Icon(
                    appSearchKindIcon(kind),
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.primary,
                  ),
                  UiGap.h(theme.spacing.sm),
                  Expanded(
                    child: Text(
                      appSearchKindLabel(kind),
                      style: context.uiText.body,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundSubtle,
                  ),
                  UiGap.h(theme.spacing.sm),
                  Text(
                    widget.destinations[kind]!,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
