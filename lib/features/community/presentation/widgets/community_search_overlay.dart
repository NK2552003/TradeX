import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/views/community_hashtag_page.dart';
import 'package:alphajournal/features/community/presentation/views/community_post_detail_view.dart';
import 'package:alphajournal/features/community/presentation/views/community_profile_view.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';

/// Twitter/X-style interactive Community search overlay rendered directly inside
/// the drawer/sheet — with recent search history, trending topics, suggested
/// traders, skeleton loading, and live filterable results (Traders, Topics, Posts).
class CommunitySearchOverlay extends StatefulWidget {
  const CommunitySearchOverlay({
    super.key,
    required this.repository,
    this.initialQuery = '',
    this.onApplyQuery,
    this.onOpenRef,
  });

  final CommunityRepository repository;
  final String initialQuery;
  final ValueChanged<String>? onApplyQuery;
  final ValueChanged<AppLinkRef>? onOpenRef;

  static Future<void> show(
    BuildContext context, {
    required CommunityRepository repository,
    String initialQuery = '',
    ValueChanged<String>? onApplyQuery,
    ValueChanged<AppLinkRef>? onOpenRef,
  }) => UiDrawer.show<void>(
    context,
    title: 'Search Community',
    width: 520,
    fromRight: true,
    scrollable: false,
    contentPadding: EdgeInsets.zero,
    child: CommunitySearchOverlay(
      repository: repository,
      initialQuery: initialQuery,
      onApplyQuery: onApplyQuery,
      onOpenRef: onOpenRef,
    ),
  );

  @override
  State<CommunitySearchOverlay> createState() => _CommunitySearchOverlayState();
}

class _CommunitySearchOverlayState extends State<CommunitySearchOverlay> {
  static const String _historyPrefKey = 'community_search_history_v1';
  static const List<String> _filterTabs = <String>[
    'All',
    'Posts',
    'Traders',
    'Topics',
  ];

  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _debounce;
  bool _searching = false;
  int _selectedFilter = 0;
  List<String> _recentSearches = <String>[];
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    _debouncedQuery = widget.initialQuery.trim();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_historyPrefKey) ?? const <String>[];
      if (mounted) {
        setState(() => _recentSearches = List<String>.of(saved));
      }
    } catch (_) {}
  }

  Future<void> _saveHistoryTerm(String term) async {
    final String clean = term.trim();
    if (clean.isEmpty) return;
    _recentSearches.removeWhere(
      (e) => e.toLowerCase() == clean.toLowerCase(),
    );
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 8) {
      _recentSearches = _recentSearches.sublist(0, 8);
    }
    if (mounted) setState(() {});
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyPrefKey, _recentSearches);
    } catch (_) {}
  }

  Future<void> _removeHistoryTerm(String term) async {
    setState(() => _recentSearches.remove(term));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyPrefKey, _recentSearches);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => _recentSearches.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyPrefKey);
    } catch (_) {}
  }

  void _onQueryChanged(String value) {
    final String trimmed = value.trim();
    _debounce?.cancel();
    if (trimmed.isEmpty) {
      setState(() {
        _debouncedQuery = '';
        _searching = false;
      });
      widget.onApplyQuery?.call('');
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _debouncedQuery = trimmed;
        _searching = false;
      });
    });
  }

  void _applyTerm(String term) {
    _ctrl.text = term;
    _ctrl.selection = TextSelection.collapsed(offset: term.length);
    _saveHistoryTerm(term);
    _onQueryChanged(term);
  }

  List<CommunityPost> get _allPublicPosts {
    final Map<String, CommunityPost> map = <String, CommunityPost>{};
    for (final p in <CommunityPost>[
      ...widget.repository.forYouPosts,
      ...widget.repository.followingPosts,
      ...widget.repository.signalPosts,
    ]) {
      if (p.isPublic) map.putIfAbsent(p.id, () => p);
    }
    return map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<({String label, int count})> get _trendingTopics {
    final Map<String, int> counts = <String, int>{};
    for (final p in _allPublicPosts) {
      for (final t in p.tickers) {
        final clean = t.trim().toUpperCase();
        if (clean.isNotEmpty) {
          counts.update('\$$clean', (v) => v + 1, ifAbsent: () => 1);
        }
      }
      for (final tag in p.tags) {
        final clean = tag.trim();
        if (clean.isNotEmpty) {
          counts.update('#$clean', (v) => v + 1, ifAbsent: () => 1);
        }
      }
    }
    final list = counts.entries
        .map((e) => (label: e.key, count: e.value))
        .toList()
      ..sort((a, b) => b.count.compareTo(a.count));
    return list.take(8).toList();
  }

  void _openPost(CommunityPost post) {
    _saveHistoryTerm(_debouncedQuery);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailView(
          post: post,
          repository: widget.repository,
          currentUser: widget.repository.currentAuthor,
          onOpenRef: widget.onOpenRef,
          onTagTap: _openTag,
        ),
      ),
    );
  }

  void _openTrader(CommunityAuthor author) {
    _saveHistoryTerm(author.displayHandle);
    CommunityProfileView.showOverlay(
      context,
      author: author,
      repository: widget.repository,
      isCurrentUser: author.id == widget.repository.currentAuthor.id,
      onPostTap: _openPost,
      onOpenRef: widget.onOpenRef,
    );
  }

  void _openTag(String tag) {
    _saveHistoryTerm(tag);
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.ui.colors.surface,
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 720,
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.86,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 8, 8),
                child: Row(
                  children: <Widget>[
                    Text(
                      tag,
                      style: ctx.uiText.heading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const UiDivider(spacing: 0),
              Expanded(
                child: CommunityHashtagPage(
                  tag: tag,
                  repository: widget.repository,
                  currentUser: widget.repository.currentAuthor,
                  onOpenRef: widget.onOpenRef,
                  onTagTap: _openTag,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool hasQuery = _debouncedQuery.isNotEmpty || _searching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Search Input Bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.sm),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.xs),
          ),
          child: UiInput.search(
            controller: _ctrl,
            hintText: 'Search traders, \$tickers, #tags, posts…',
            autofocus: true,
            onChanged: _onQueryChanged,
            onSubmitted: (String value) {
              final String clean = value.trim();
              if (clean.isEmpty) return;
              _saveHistoryTerm(clean);
              widget.onApplyQuery?.call(clean);
            },
            onClear: () {
              _ctrl.clear();
              _onQueryChanged('');
            },
          ),
        ),

        if (hasQuery)
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.xs),
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.xs),
            ),
            child: CommunityPillTabBar(
              tabs: _filterTabs,
              selectedIndex: _selectedFilter,
              expandTabs: true,
              onChanged: (int i) => setState(() => _selectedFilter = i),
            ),
          ),

        const UiDivider(spacing: 0),

        // Overlay Results / Initial Discovery / Skeleton
        Expanded(
          child: _searching
              ? _buildSearchSkeleton(theme)
              : (_debouncedQuery.isEmpty
                    ? _buildInitialDiscovery(theme)
                    : _buildSearchResults(theme)),
        ),
      ],
    );
  }

  Widget _buildSearchSkeleton(UiTheme theme) {
    return ListView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      children: <Widget>[
        UiSkeleton(
          width: 110,
          height: 12,
          borderRadius: BorderRadius.circular(6),
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < 4; i++) ...<Widget>[
          Row(
            children: <Widget>[
              const UiSkeleton(width: 38, height: 38, circle: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    UiSkeleton(
                      width: i.isEven ? 160 : 128,
                      height: 13,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(height: 6),
                    UiSkeleton(
                      width: double.infinity,
                      height: 11,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const UiDivider(spacing: 0),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _buildInitialDiscovery(UiTheme theme) {
    final topics = _trendingTopics;
    final traders = widget.repository.suggestedTraders
        .where((t) => t.id != widget.repository.currentAuthor.id)
        .take(5)
        .toList();

    return ListView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      children: <Widget>[
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Text(
                'RECENT SEARCHES',
                style: context.uiText.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: theme.colors.foregroundSubtle,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: context.radius(theme.radii.sm),
                onTap: _clearHistory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    'Clear all',
                    style: context.uiText.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final term in _recentSearches)
            InkWell(
              borderRadius: context.radius(theme.radii.md),
              onTap: () => _applyTerm(term),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: theme.colors.foregroundMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.body.copyWith(fontSize: 13.5),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _removeHistoryTerm(term),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          const UiDivider(spacing: 0),
          const SizedBox(height: 14),
        ],

        // Trending Topics & Tickers
        if (topics.isNotEmpty) ...<Widget>[
          Text(
            'TRENDING TOPICS & TICKERS',
            style: context.uiText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final t in topics)
                InkWell(
                  borderRadius: context.radius(theme.radii.pill),
                  onTap: () => _openTag(t.label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colors.surfaceMuted.withValues(alpha: 0.55),
                      borderRadius: context.radius(theme.radii.pill),
                      border: Border.all(color: theme.colors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          t.label,
                          style: context.uiText.caption.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colors.foreground,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${t.count}',
                          style: context.uiText.caption.copyWith(
                            fontSize: 11,
                            color: theme.colors.foregroundSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const UiDivider(spacing: 0),
          const SizedBox(height: 14),
        ],

        // Suggested Traders
        if (traders.isNotEmpty) ...<Widget>[
          Text(
            'TRADERS TO EXPLORE',
            style: context.uiText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 8),
          for (final trader in traders) _buildTraderTile(theme, trader),
        ],
      ],
    );
  }

  Widget _buildSearchResults(UiTheme theme) {
    final String q = _debouncedQuery.toLowerCase();
    final String cleanQ = q.replaceFirst(RegExp(r'^[#$@]'), '');

    final List<CommunityAuthor> matchedTraders = widget.repository
        .searchUsers(_debouncedQuery)
        .take(_selectedFilter == 2 ? 25 : 4)
        .toList();

    final List<({String label, int count})> matchedTopics = _trendingTopics
        .where((t) => t.label.toLowerCase().contains(cleanQ))
        .toList();

    final List<CommunityPost> matchedPosts = _allPublicPosts
        .where((p) {
          return p.body.toLowerCase().contains(q) ||
              p.author.displayName.toLowerCase().contains(q) ||
              p.author.handle.toLowerCase().contains(cleanQ) ||
              p.tickers.any((t) => t.toLowerCase().contains(cleanQ)) ||
              p.tags.any((t) => t.toLowerCase().contains(cleanQ));
        })
        .take(_selectedFilter == 1 ? 30 : 8)
        .toList();

    final bool showTraders =
        (_selectedFilter == 0 || _selectedFilter == 2) &&
        matchedTraders.isNotEmpty;
    final bool showTopics =
        (_selectedFilter == 0 || _selectedFilter == 3) &&
        matchedTopics.isNotEmpty;
    final bool showPosts =
        (_selectedFilter == 0 || _selectedFilter == 1) &&
        matchedPosts.isNotEmpty;

    if (!showTraders && !showTopics && !showPosts) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.search_off_rounded,
            title: 'No results for "$_debouncedQuery"',
            message:
                'Try another trader handle, \$TICKER, #hashtag, or keyword.',
          ),
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      children: <Widget>[
        if (showTopics) ...<Widget>[
          Text(
            'TOPICS & TICKERS',
            style: context.uiText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final t in matchedTopics)
                InkWell(
                  borderRadius: context.radius(theme.radii.pill),
                  onTap: () => _openTag(t.label),
                  child: UiBadge(
                    label: '${t.label} · ${t.count}',
                    variant: UiBadgeVariant.soft,
                    intent: UiIntent.primary,
                    size: UiSize.sm,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        if (showTraders) ...<Widget>[
          Text(
            'TRADERS',
            style: context.uiText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 6),
          for (final trader in matchedTraders) _buildTraderTile(theme, trader),
          const SizedBox(height: 12),
        ],

        if (showPosts) ...<Widget>[
          Text(
            'POSTS',
            style: context.uiText.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colors.foregroundSubtle,
            ),
          ),
          const SizedBox(height: 8),
          for (final post in matchedPosts) _buildPostResultCard(theme, post),
        ],

        if (widget.onApplyQuery != null) ...<Widget>[
          const SizedBox(height: 10),
          UiButton(
            label: 'Filter feed by "$_debouncedQuery"',
            leadingIcon: Icons.filter_list_rounded,
            variant: UiVariant.outline,
            expand: true,
            onPressed: () {
              _saveHistoryTerm(_debouncedQuery);
              widget.onApplyQuery!(_debouncedQuery);
              Navigator.of(context).pop();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildTraderTile(UiTheme theme, CommunityAuthor trader) {
    final Color verifiedColor = trader.verifiedColor(theme);
    return InkWell(
      borderRadius: context.radius(theme.radii.md),
      onTap: () => _openTrader(trader),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: <Widget>[
            UiAvatar(
              name: trader.displayName,
              imageUrl: trader.avatarUrl,
              size: UiSize.sm,
              verified: trader.verified,
              verifiedColor: verifiedColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          trader.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.bodyStrong.copyWith(
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (trader.verified) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: verifiedColor,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    trader.displayHandle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colors.foregroundSubtle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostResultCard(UiTheme theme, CommunityPost post) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: context.radius(theme.radii.md),
        onTap: () => _openPost(post),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colors.surfaceMuted.withValues(alpha: 0.35),
            borderRadius: context.radius(theme.radii.md),
            border: Border.all(color: theme.colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  UiAvatar(
                    name: post.author.displayName,
                    imageUrl: post.author.avatarUrl,
                    size: UiSize.xs,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${post.author.displayName} · ${post.author.displayHandle} · ${AppTokens.relativeTime(post.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                post.body.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  fontSize: 12.5,
                  color: theme.colors.foregroundMuted,
                  height: 1.38,
                ),
              ),
              if (post.tickers.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final t in post.tickers.take(4))
                      UiBadge(
                        label: '\$$t',
                        size: UiSize.xs,
                        variant: UiBadgeVariant.soft,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
