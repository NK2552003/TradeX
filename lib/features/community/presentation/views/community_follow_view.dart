import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_moderation_list_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';
import 'package:tradex/features/settings/presentation/widgets/settings_side_sheet.dart';

/// Full Network & "Who to follow" page (accessible from sidebar 'Show more').
class CommunityFollowView extends StatefulWidget {
  const CommunityFollowView({
    super.key,
    required this.repository,
    this.onAuthorTap,
    this.searchQuery,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final String? searchQuery;

  @override
  State<CommunityFollowView> createState() => _CommunityFollowViewState();
}

class _CommunityFollowViewState extends State<CommunityFollowView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _searchQuery = '';
  String _leaderboardPeriod = '1M';
  bool _refreshing = false;
  bool _loadingLeaderboard = false;

  String get _effectiveQuery => (widget.searchQuery?.trim().isNotEmpty ?? false)
      ? widget.searchQuery!.trim()
      : _searchQuery;

  List<String> get _tabLabels => <String>[
    'Suggested',
    'Following (${widget.repository.followingCount})',
    'Followers (${widget.repository.followersCount})',
    'Leaderboard',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this)
      ..addListener(_onDataChanged);
    widget.repository.addListener(_onDataChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadLeaderboard(_leaderboardPeriod);
      if (!widget.repository.hasLoadedFollows && !widget.repository.isLoading) {
        widget.repository.fetchFromSupabase();
      }
    });
  }

  Future<void> _loadLeaderboard(String period) async {
    setState(() => _loadingLeaderboard = true);
    try {
      await widget.repository.fetchLeaderboard(period: period);
    } finally {
      if (mounted) setState(() => _loadingLeaderboard = false);
    }
  }

  Future<void> _refreshNetwork() async {
    if (_refreshing || widget.repository.isLoading) return;
    setState(() => _refreshing = true);
    try {
      await widget.repository.fetchFromSupabase();
      await widget.repository.fetchLeaderboard(period: _leaderboardPeriod);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CommunityFollowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onDataChanged);
      widget.repository.addListener(_onDataChanged);
    }
  }

  Widget _networkState(Widget child) {
    if (widget.repository.isLoading && !widget.repository.hasLoadedFollows) {
      return UiSkeleton.settingsList(showHeader: false, rows: 6);
    }
    if (widget.repository.refreshError != null &&
        !widget.repository.isLoading) {
      return UiEmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Could not refresh your network',
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onActionPressed: _refreshNetwork,
      );
    }
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Full width top bar tab toggle across the centered panel
        _buildTopBar(context, theme, isMobile),
        if ((_refreshing || widget.repository.isLoading) &&
            widget.repository.hasLoadedFollows)
          Semantics(
            liveRegion: true,
            child: Text(
              'Refreshing network…',
              textAlign: TextAlign.center,
              style: context.uiText.caption,
            ),
          ),

        // Sub-Tab Content Views (trader cards centered at maxWidth 700px beneath the bar)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: context.uiRes.isDesktop
                ? const NeverScrollableScrollPhysics()
                : null,
            children: <Widget>[
              _CommunityKeepAliveTab(
                child: _networkState(_buildSuggestedTab()),
              ),
              _CommunityKeepAliveTab(
                child: _networkState(_buildFollowingTab()),
              ),
              _CommunityKeepAliveTab(
                child: _networkState(_buildFollowersTab()),
              ),
              _CommunityKeepAliveTab(child: _buildLeaderboardTab()),
            ],
          ),
        ),
      ],
    );
  }

  /// Top bar container holding the floating capsule pill bar,
  /// moved outside the scroll view so trader lists never scroll over it.
  Widget _buildTopBar(BuildContext context, UiTheme theme, bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        context.sp(theme.spacing.xs),
      ),
      child: _buildFloatingBar(context, theme, isMobile),
    );
  }

  Widget _buildFloatingBar(BuildContext context, UiTheme theme, bool isMobile) {
    return UiTabs(
      tabs: _tabLabels,
      selectedIndex: _tabController.index,
      onChanged: _tabController.animateTo,
      variant: UiTabsVariant.pill,
      scrollable: true,
      showPanel: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UiIconButton(
            icon: Icons.refresh_rounded,
            size: UiSize.sm,
            tooltip: _refreshing || widget.repository.isLoading
                ? 'Refreshing...'
                : 'Refresh Network',
            onPressed: _refreshing || widget.repository.isLoading
                ? null
                : _refreshNetwork,
          ),
          UiIconButton(
            icon: Icons.shield_outlined,
            size: UiSize.sm,
            tooltip: 'Muted & Blocked Accounts',
            onPressed: () {
              showSettingsSideSheet<void>(
                context,
                title: 'Muted & Blocked Accounts',
                subtitle: 'Review restricted and muted trader profiles',
                desktopWidthRatio: 0.44,
                maxWidth: 620,
                minDesktopWidth: 460,
                child: CommunityModerationListPage(
                  repository: widget.repository,
                  isEmbedded: true,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Suggested
  // ---------------------------------------------------------------------------

  Widget _buildSuggestedTab({double topPadding = 0}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders.where((t) {
      if (t.id == widget.repository.currentAuthor.id) return false;
      if (_effectiveQuery.isEmpty) return true;
      final q = _effectiveQuery.toLowerCase();
      return t.displayName.toLowerCase().contains(q) ||
          t.handle.toLowerCase().contains(q) ||
          (t.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();

    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Following
  // ---------------------------------------------------------------------------

  Widget _buildFollowingTab({double topPadding = 0}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.allKnownAuthors.where((t) {
      final isF =
          t.isFollowing || widget.repository.followedAuthorIds.contains(t.id);
      if (!isF) return false;
      if (_effectiveQuery.isEmpty) return true;
      final q = _effectiveQuery.toLowerCase();
      return t.displayName.toLowerCase().contains(q) ||
          t.handle.toLowerCase().contains(q) ||
          (t.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (traders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.person_add_disabled_outlined,
            title: _effectiveQuery.isNotEmpty
                ? 'No matching traders'
                : 'Not following anyone yet',
            message: _effectiveQuery.isNotEmpty
                ? 'Try another name, handle, or trading style.'
                : 'Browse suggested traders to build your trading network.',
            actionLabel: _effectiveQuery.isEmpty ? 'Browse traders' : null,
            onActionPressed: _effectiveQuery.isEmpty
                ? () => _tabController.animateTo(0)
                : null,
          ),
        ),
      );
    }

    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Followers
  // ---------------------------------------------------------------------------

  Widget _buildFollowersTab({double topPadding = 0}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.allKnownAuthors.where((t) {
      if (!widget.repository.followerAuthorIds.contains(t.id)) return false;
      if (_effectiveQuery.isEmpty) return true;
      final q = _effectiveQuery.toLowerCase();
      return t.displayName.toLowerCase().contains(q) ||
          t.handle.toLowerCase().contains(q) ||
          (t.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();

    if (traders.isEmpty) {
      return UiEmptyState(
        icon: Icons.people_outline_rounded,
        title: _effectiveQuery.isNotEmpty
            ? 'No matching traders'
            : 'No followers yet',
        message: _effectiveQuery.isNotEmpty
            ? 'Try another name, handle, or trading style.'
            : 'People who follow your profile will appear here.',
      );
    }
    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Leaderboard
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboardTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final rawEntries = widget.repository.leaderboardForPeriod(
      _leaderboardPeriod,
    );
    final query = _effectiveQuery.toLowerCase();
    final entries = query.isEmpty
        ? rawEntries
        : rawEntries.where((entry) {
            final t = entry.key;
            return t.displayName.toLowerCase().contains(query) ||
                t.handle.toLowerCase().contains(query) ||
                (t.tradingStyle?.toLowerCase().contains(query) ?? false);
          }).toList();

    final Widget content = Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Ranked by Win-Rate · $_leaderboardPeriod',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiToggleGroup<String>(
                size: UiSize.xs,
                variant: UiToggleGroupVariant.segmented,
                value: _leaderboardPeriod,
                onChanged: (v) {
                  setState(() => _leaderboardPeriod = v);
                  _loadLeaderboard(v);
                },
                options: const [
                  UiToggleOption(value: '1W', label: '1W'),
                  UiToggleOption(value: '1M', label: '1M'),
                  UiToggleOption(value: '3M', label: '3M'),
                  UiToggleOption(value: 'ALL', label: 'All'),
                ],
              ),
            ],
          ),
        ),
        const UiDivider(),
        if (_loadingLeaderboard && entries.isEmpty)
          Expanded(child: UiSkeleton.settingsList(showHeader: false, rows: 6))
        else if (entries.isEmpty)
          Expanded(
            child: Center(
              child: UiEmptyState(
                icon: Icons.emoji_events_outlined,
                title: query.isNotEmpty
                    ? 'No matching traders'
                    : 'No ranked traders yet',
                message: query.isNotEmpty
                    ? 'Try another name, handle, or trading style.'
                    : 'Public win-rates and verified setups for this timeframe will appear here.',
                actionLabel: query.isEmpty ? 'Refresh' : null,
                onActionPressed: query.isEmpty ? _refreshNetwork : null,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.all(
                context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
              ),
              itemCount: entries.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: context.sp(theme.spacing.xs)),
              itemBuilder: (BuildContext context, int index) {
                final rank = index + 1;
                final trader = entries[index].key;
                final winRate = entries[index].value;
                final bool isSelf =
                    trader.id.isNotEmpty &&
                    trader.id == widget.repository.currentAuthor.id;

                return UiCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.md),
                    vertical: context.sp(theme.spacing.sm),
                  ),
                  child: CommunityTraderRow(
                    trader: trader,
                    rank: rank,
                    winRate: winRate,
                    showBio: !isMobile,
                    onTap: () => widget.onAuthorTap?.call(trader),
                    onFollow: isSelf
                        ? null
                        : () => widget.repository.toggleFollow(trader.id),
                  ),
                );
              },
            ),
          ),
      ],
    );

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: content,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Responsive Trader List / Grid with Dynamic Card Heights
  // ---------------------------------------------------------------------------

  Widget _buildTraderList(
    List<CommunityAuthor> traders,
    bool isMobile,
    UiTheme theme, {
    double topPadding = 0,
  }) {
    if (traders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No traders found',
            message: 'Try adjusting your search query or filters.',
          ),
        ),
      );
    }

    Widget content;
    if (isMobile) {
      content = ListView.separated(
        padding: EdgeInsets.fromLTRB(
          context.sp(theme.spacing.sm),
          topPadding + context.sp(theme.spacing.xs),
          context.sp(theme.spacing.sm),
          context.sp(theme.spacing.md),
        ),
        itemCount: traders.length,
        separatorBuilder: (_, _) => Padding(
          padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xs)),
          child: UiDivider(),
        ),
        itemBuilder: (BuildContext context, int index) {
          final trader = traders[index];
          return CommunityTraderRow(
            trader: trader,
            onTap: () => widget.onAuthorTap?.call(trader),
            onFollow: () => widget.repository.toggleFollow(trader.id),
          );
        },
      );
    } else {
      content = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;

          if (crossAxisCount == 1) {
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                context.sp(theme.spacing.md),
                topPadding + context.sp(theme.spacing.xs),
                context.sp(theme.spacing.md),
                context.sp(theme.spacing.md),
              ),
              itemCount: traders.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: context.sp(theme.spacing.sm)),
              itemBuilder: (BuildContext context, int index) {
                final trader = traders[index];
                return CommunityTraderCard(
                  trader: trader,
                  onTap: () => widget.onAuthorTap?.call(trader),
                  onFollow: () => widget.repository.toggleFollow(trader.id),
                );
              },
            );
          }

          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              context.sp(theme.spacing.md),
              topPadding + context.sp(theme.spacing.xs),
              context.sp(theme.spacing.md),
              context.sp(theme.spacing.md),
            ),
            itemCount: (traders.length + 1) ~/ 2,
            itemBuilder: (BuildContext context, int rowIndex) {
              final first = traders[rowIndex * 2];
              final secondIndex = rowIndex * 2 + 1;
              return Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: CommunityTraderCard(
                          trader: first,
                          onTap: () => widget.onAuthorTap?.call(first),
                          onFollow: () =>
                              widget.repository.toggleFollow(first.id),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      Expanded(
                        child: secondIndex < traders.length
                            ? CommunityTraderCard(
                                trader: traders[secondIndex],
                                onTap: () => widget.onAuthorTap?.call(
                                  traders[secondIndex],
                                ),
                                onFollow: () => widget.repository.toggleFollow(
                                  traders[secondIndex].id,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(700)),
        child: content,
      ),
    );
  }
}

/// Preserves tab scroll state across switches for optimal performance.
class _CommunityKeepAliveTab extends StatefulWidget {
  const _CommunityKeepAliveTab({required this.child});
  final Widget child;

  @override
  State<_CommunityKeepAliveTab> createState() => _CommunityKeepAliveTabState();
}

class _CommunityKeepAliveTabState extends State<_CommunityKeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
