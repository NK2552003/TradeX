import 'package:tradex/features/market_data/models/market_snapshot.dart';
import 'package:tradex/features/market_data/presentation/market_news_widgets.dart';
import 'package:flutter/material.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/market_data/presentation/market_instrument_view.dart'
    show marketFieldLabel;
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_hashtag_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';
import 'package:tradex/features/strategies/data/strategies_repository.dart';
import 'package:tradex/features/notes/data/notes_repository.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Explore & News view — trending market topics, market wire headlines, and category filters.
class CommunityExploreView extends StatefulWidget {
  const CommunityExploreView({
    super.key,
    required this.repository,
    this.onPostTap,
    this.onAuthorTap,
    this.onOpenRef,
    this.onTagTap,
    this.searchQuery,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;
  final String? searchQuery;

  @override
  State<CommunityExploreView> createState() => _CommunityExploreViewState();
}

class _CommunityExploreViewState extends State<CommunityExploreView> {
  final String _searchQuery = '';
  String _selectedCategory = 'All';

  String get _effectiveQuery => (widget.searchQuery?.trim().isNotEmpty ?? false)
      ? widget.searchQuery!.trim()
      : _searchQuery;

  List<String> get _categories => [
    'All',
    'Playbooks & Research',
    ...widget.repository.newsByCategory.keys,
  ];

  List<AppStrategy> _publicStrategies = const <AppStrategy>[];
  List<AppNote> _publicNotes = const <AppNote>[];
  List<AppTrade> _publicEntries = const <AppTrade>[];
  bool _loadingPublicRecords = true;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onDataChanged);
    _loadPublicRecords();
  }

  Future<void> _refresh() async {
    try {
      await Future.wait([
        widget.repository.fetchFromSupabase(),
        _loadPublicRecords(),
      ]);
    } catch (e) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Refresh failed',
          message: '$e',
        );
      }
      return;
    }
    if (mounted && widget.repository.refreshError != null) {
      UiToast.error(
        context,
        title: 'Refresh failed',
        message: widget.repository.refreshError!,
      );
    }
  }

  Future<void> _loadPublicRecords() async {
    try {
      final strategies = await StrategiesRepositoryScope.repository
          .fetchPublicStrategies();
      final notes = await NotesRepositoryScope.repository.fetchPublicNotes();
      final entries = await JournalRepositoryScope.repository
          .fetchPublicEntries();
      if (mounted) {
        setState(() {
          _publicStrategies = strategies;
          _publicNotes = notes;
          _publicEntries = entries;
          _loadingPublicRecords = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPublicRecords = false);
    }
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    final filteredPosts = widget.repository.forYouPosts.where((p) {
      if (_effectiveQuery.isNotEmpty) {
        final q = _effectiveQuery.toLowerCase();
        if (!p.body.toLowerCase().contains(q) &&
            !p.tickers.any((t) => t.toLowerCase().contains(q)) &&
            !p.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      if (_selectedCategory != 'All') {
        final cat = _selectedCategory.toLowerCase();
        return p.tags.any((t) => t.toLowerCase().contains(cat)) ||
            p.body.toLowerCase().contains(cat);
      }
      return true;
    }).toList();

    final groups = widget.repository.newsByCategory;
    final wire = <String, List<CommunityNewsItem>>{
      for (final entry in groups.entries)
        if (_selectedCategory == 'All' || _selectedCategory == entry.key)
          entry.key: entry.value
              .where(
                (item) =>
                    _effectiveQuery.isEmpty ||
                    '${item.headline} ${item.summary} ${item.relatedTickers.join(' ')}'
                        .toLowerCase()
                        .contains(_effectiveQuery.toLowerCase()),
              )
              .toList(),
    };
    return RefreshIndicator(
      onRefresh: _refresh,
      child: UiLazyList(
        key: ValueKey('$_selectedCategory/$_effectiveQuery'),
      maxWidth: context.sz(700),
      padding: EdgeInsets.all(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      itemCount: filteredPosts.length,
      headerBuilder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UiCard(
            variant: UiCardVariant.subtle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explore the market', style: context.uiText.title),
                UiGap.v(theme.spacing.xs),
                Text(
                  'Discover public research, active discussions and the latest market wire.',
                  style: context.uiText.body.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                UiGap.v(theme.spacing.sm),
                Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  children: [
                    UiBadge(
                      label: '${filteredPosts.length} public posts',
                      intent: UiIntent.primary,
                      variant: UiBadgeVariant.soft,
                    ),
                    UiBadge(
                      label: '${widget.repository.news.length} headlines',
                      intent: UiIntent.info,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ],
            ),
          ),
          UiGap.v(theme.spacing.md),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              for (final cat in _categories)
                UiBadge(
                  label: marketFieldLabel(cat),
                  intent: _selectedCategory == cat
                      ? UiIntent.primary
                      : UiIntent.neutral,
                  variant: _selectedCategory == cat
                      ? UiBadgeVariant.solid
                      : UiBadgeVariant.soft,
                  onTap: () => setState(() => _selectedCategory = cat),
                ),
            ],
          ),
          UiGap.v(theme.spacing.md),
          if (_selectedCategory == 'All' ||
              _selectedCategory == 'Playbooks & Research') ...[
            _buildPublicRecordsSection(context, theme),
            UiGap.v(theme.spacing.md),
          ],
          UiCard(
            title: 'Trending in Markets',
            child: Column(
              children: [
                for (final trend in widget.repository.trending.take(6))
                  _trendRow(context, trend),
              ],
            ),
          ),
          UiGap.v(theme.spacing.md),
          Text('Market Wire', style: context.uiText.heading),
          UiGap.v(theme.spacing.sm),
          if (wire.isEmpty)
            UiCallout(
              title:
                  widget.repository.marketDataError ?? 'Market news is loading',
              message:
                  'Category headlines will appear when the market snapshot is ready.',
              intent: UiIntent.info,
            ),
          for (final entry in wire.entries.where(
            (e) => e.value.isNotEmpty,
          )) ...[
            UiDeferred(
              estimatedHeight: 380,
              builder: (_) => UiCard(
                key: ValueKey('wire-category-${entry.key}'),
                title: marketFieldLabel(entry.key),
                trailing: UiButton(
                  label: 'View all',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  onPressed: () => _viewAll(entry.key, entry.value),
                ),
                child: _newsItem(context, entry.value.first),
              ),
            ),
            UiGap.v(theme.spacing.md),
          ],
          if (wire.isNotEmpty && wire.values.every((rows) => rows.isEmpty))
            const UiEmptyState(title: 'No matching headlines'),
          Text(
            'Explore Posts (${filteredPosts.length})',
            style: context.uiText.heading,
          ),
          UiGap.v(theme.spacing.sm),
          if (filteredPosts.isEmpty)
            const CommunityEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching posts found',
              message:
                  'Try exploring other categories or clearing your search.',
            ),
        ],
      ),
      itemBuilder: (_, index) {
        final post = filteredPosts[index];
        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: CommunityPostCard(
            key: ValueKey(post.id),
            post: post,
            variant: CommunityPostCardVariant.boxed,
            onTap: () => widget.onPostTap?.call(post),
            onLike: () => widget.repository.toggleLike(post.id),
            onRepost: () => widget.repository.toggleRepost(post.id),
            onBookmark: () => widget.repository.toggleBookmark(post.id),
            onAuthorTap: widget.onAuthorTap,
            onOpenRef: widget.onOpenRef,
            onTagTap: widget.onTagTap,
          ),
        );
      },
      ),
    );
  }

  Widget _buildPublicRecordsSection(BuildContext context, UiTheme theme) {
    if (_loadingPublicRecords) {
      return const UiSkeleton(height: 120);
    }
    if (_publicStrategies.isEmpty &&
        _publicNotes.isEmpty &&
        _publicEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    return UiCard(
      title: 'Community Playbooks, Research & Trade Logs',
      subtitle:
          'Public trading systems, research notes, and trade logs shared by community traders',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final entry in _publicEntries.take(3)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.journal,
                      id: entry.id,
                      title: entry.displayTitle,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      entry.outcome == AppOutcome.win
                          ? Icons.trending_up_rounded
                          : (entry.outcome == AppOutcome.loss
                                ? Icons.trending_down_rounded
                                : Icons.schedule_rounded),
                      color: entry.outcome == AppOutcome.win
                          ? theme.colors.success
                          : (entry.outcome == AppOutcome.loss
                                ? theme.colors.danger
                                : theme.colors.warning),
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            entry.displayTitle,
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              UiBadge(
                                label: entry.side.name.toUpperCase(),
                                intent: entry.side == AppSide.long
                                    ? UiIntent.success
                                    : UiIntent.danger,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              UiBadge(
                                label: entry.outcome.name.toUpperCase(),
                                intent: entry.outcome == AppOutcome.win
                                    ? UiIntent.success
                                    : (entry.outcome == AppOutcome.loss
                                          ? UiIntent.danger
                                          : UiIntent.warning),
                                variant: UiBadgeVariant.soft,
                              ),
                              if (entry.pnl != 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${entry.pnl >= 0 ? '+' : ''}₹${entry.pnl.toStringAsFixed(2)}',
                                  style: context.uiText.caption.copyWith(
                                    color: entry.pnl >= 0
                                        ? theme.colors.success
                                        : theme.colors.danger,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final strategy in _publicStrategies.take(4)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.strategy,
                      id: strategy.id,
                      title: strategy.name,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.psychology_outlined,
                      color: theme.colors.primary,
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            strategy.name.isNotEmpty
                                ? strategy.name
                                : 'Untitled Playbook',
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              const UiBadge(
                                label: 'Strategy',
                                intent: UiIntent.primary,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              if (strategy.winRate > 0)
                                Text(
                                  'Win: ${strategy.winRate.toStringAsFixed(1)}%',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.success,
                                  ),
                                ),
                              if (strategy.avgR != 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Avg R: ${strategy.avgR > 0 ? '+' : ''}${strategy.avgR.toStringAsFixed(2)}R',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
          for (final note in _publicNotes.take(4)) ...[
            Padding(
              padding: EdgeInsets.symmetric(
                vertical: context.sp(theme.spacing.xs),
              ),
              child: UiCard(
                variant: UiCardVariant.outlined,
                onTap: () {
                  widget.onOpenRef?.call(
                    AppLinkRef(
                      kind: AppLinkKind.note,
                      id: note.id,
                      title: note.title,
                      isPublicContext: true,
                    ),
                  );
                },
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.article_outlined,
                      color: theme.colors.secondary,
                      size: context.sz(24),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            note.title.isNotEmpty
                                ? note.title
                                : 'Untitled Research Note',
                            style: context.uiText.bodyStrong,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              UiBadge(
                                label: note.noteType.label,
                                intent: UiIntent.info,
                                variant: UiBadgeVariant.soft,
                              ),
                              const SizedBox(width: 6),
                              if (note.wordCount > 0)
                                Text(
                                  '${note.wordCount} words',
                                  style: context.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const UiBadge(
                      label: 'Public',
                      intent: UiIntent.success,
                      variant: UiBadgeVariant.soft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _viewAll(String category, List<CommunityNewsItem> items) {
    _openExplorePanel(
      title: marketFieldLabel(category),
      page: CommunityMarketWirePage(
        category: category,
        items: items,
        snapshot: widget.repository.marketSnapshot,
      ),
    );
  }

  void _openExplorePanel({required String title, required Widget page}) {
    if (context.uiRes.isDesktop) {
      showSettingsSideSheet<void>(
        context,
        title: title,
        desktopWidthRatio: 0.48,
        minDesktopWidth: 540,
        maxWidth: 760,
        child: LayoutBuilder(
          builder: (panelContext, constraints) => MediaQuery(
            data: MediaQuery.of(
              panelContext,
            ).copyWith(size: Size(constraints.maxWidth, constraints.maxHeight)),
            child: page,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  void _openTopic(String topic) => _openExplorePanel(
    title: topic,
    page: CommunityHashtagPage(
      tag: topic,
      repository: widget.repository,
      currentUser: widget.repository.currentAuthor,
      onPostTap: widget.onPostTap,
      onAuthorTap: widget.onAuthorTap,
      onOpenRef: widget.onOpenRef,
      onTagTap: widget.onTagTap,
    ),
  );

  Widget _trendRow(BuildContext context, CommunityTrendItem item) {
    final UiTheme theme = context.ui;

    return InkWell(
      onTap: () {
        _openTopic(item.topic);
      },
      borderRadius: context.radius(theme.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xxs)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.category,
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                      fontSize: context.fs(11),
                    ),
                  ),
                  Text(
                    item.topic,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.postCount != null)
                    Text(
                      item.postCount!,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundSubtle,
                        fontSize: context.fs(11),
                      ),
                    ),
                ],
              ),
            ),
            UiIconButton(
              icon: Icons.arrow_forward_ios_rounded,
              size: UiSize.xs,
              tooltip: 'Explore topic',
              onPressed: () => _openTopic(item.topic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newsItem(BuildContext context, CommunityNewsItem item) =>
      MarketNewsCard(
        article: communityMarketArticle(item),
        snapshot:
            widget.repository.marketSnapshot ??
            const MarketSnapshot(instruments: [], articles: []),
        row: true,
        onTap: () => CommunityArticleSheet.show(
          context,
          article: item,
          snapshot: widget.repository.marketSnapshot,
        ),
      );
}

/// A category-specific feed: only visible rows are built, with automatic batches.
class CommunityMarketWirePage extends StatelessWidget {
  const CommunityMarketWirePage({
    super.key,
    required this.category,
    required this.items,
    this.snapshot,
  });
  final String category;
  final List<CommunityNewsItem> items;
  final MarketSnapshot? snapshot;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
            child: Row(
              children: [
                UiIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Back to Explore',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                UiGap.h(context.ui.spacing.sm),
                Expanded(
                  child: Text(
                    marketFieldLabel(category),
                    style: context.uiText.heading,
                  ),
                ),
                UiBadge(label: '${items.length} articles'),
              ],
            ),
          ),
          Expanded(
            child: UiLazyList(
              itemCount: items.length,
              maxWidth: context.sz(900),
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              itemBuilder: (_, index) => MarketNewsCard(
                article: communityMarketArticle(items[index]),
                snapshot:
                    snapshot ??
                    const MarketSnapshot(instruments: [], articles: []),
                row: true,
                onTap: () => CommunityArticleSheet.show(
                  context,
                  article: items[index],
                  snapshot: snapshot,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
