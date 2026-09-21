import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_moderation_list_page.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// Full Network & "Who to follow" page (accessible from sidebar 'Show more').
class CommunityFollowView extends StatefulWidget {
  const CommunityFollowView({
    super.key,
    required this.repository,
    this.onAuthorTap,
  });

  final CommunityRepository repository;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  @override
  State<CommunityFollowView> createState() => _CommunityFollowViewState();
}

class _CommunityFollowViewState extends State<CommunityFollowView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _leaderboardPeriod = '1M';

  static const List<String> _tabs = <String>[
    'Suggested',
    'Following',
    'Followers',
    'Leaderboard',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final double topInset = context.sp(theme.spacing.xs);
    final double barHeight = context.sz(44);
    final double clearance =
        topInset + barHeight + context.sp(theme.spacing.xs);

    return Column(
      children: <Widget>[
        // Top Search & Filter Bar
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(theme.spacing.xs),
          ),
          child: Row(
            children: [
              Expanded(
                child: UiSearchField(
                  value: _searchQuery,
                  hintText: 'Search traders by name, @handle or style...',
                  onChanged: (String q) => setState(() => _searchQuery = q),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.shield_outlined,
                tooltip: 'Muted & Blocked Accounts',
                size: UiSize.sm,
                variant: UiVariant.ghost,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CommunityModerationListPage(
                        repository: widget.repository,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // Floating Tab Bar Area
        Expanded(
          child: Stack(
            children: <Widget>[
              // Tab Views (scroll smoothly underneath the floating bar)
              TabBarView(
                controller: _tabController,
                physics: context.uiRes.isDesktop
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: <Widget>[
                  _CommunityKeepAliveTab(
                    child: _buildSuggestedTab(topPadding: clearance),
                  ),
                  _CommunityKeepAliveTab(
                    child: _buildFollowingTab(topPadding: clearance),
                  ),
                  _CommunityKeepAliveTab(
                    child: _buildFollowersTab(topPadding: clearance),
                  ),
                  _CommunityKeepAliveTab(
                    child: _buildLeaderboardTab(topPadding: clearance),
                  ),
                ],
              ),

              // Floating Top Sub-Tabs Bar - spans full width of network container
              Positioned(
                top: topInset,
                left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
                right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
                child: _buildFloatingBar(context, theme, isMobile),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Floating capsule bar with frosted glass, hairline border, soft glow indicator,
  /// matching the Feed top floating bar design.
  Widget _buildFloatingBar(BuildContext context, UiTheme theme, bool isMobile) {
    return Container(
      height: context.sz(44),
      decoration: BoxDecoration(
        borderRadius: context.radius(theme.radii.pill),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: context.radius(theme.radii.pill),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colors.surface.withValues(alpha: 0.88),
              borderRadius: context.radius(theme.radii.pill),
              border: Border.all(
                color: theme.colors.border.withValues(alpha: 0.7),
                width: theme.borders.hairline,
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: isMobile,
                    tabAlignment:
                        isMobile ? TabAlignment.start : TabAlignment.fill,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: context.sp(
                        isMobile ? theme.spacing.sm : theme.spacing.md,
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: context.radius(theme.radii.pill),
                    overlayColor:
                        WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.transparent;
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return theme.colors.primary.withValues(alpha: 0.08);
                      }
                      return null;
                    }),
                    indicator: BoxDecoration(
                      color: theme.colors.primary.withValues(alpha: 0.16),
                      borderRadius: context.radius(theme.radii.pill),
                      border: Border.all(
                        color: theme.colors.primary.withValues(alpha: 0.4),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colors.primary.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    dividerColor: Colors.transparent,
                    labelColor: theme.colors.primary,
                    unselectedLabelColor: theme.colors.foregroundMuted,
                    labelStyle: context.uiText.bodyStrong.copyWith(
                      fontSize: context.fs(isMobile ? 12.5 : 13.5),
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: context.uiText.body.copyWith(
                      fontSize: context.fs(isMobile ? 12.5 : 13.5),
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: _tabs.map((label) {
                      return Tab(
                        height: context.sz(34),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(label),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  height: context.sz(18),
                  width: theme.borders.hairline,
                  color: theme.colors.border.withValues(alpha: 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                ),
                UiIconButton(
                  icon: Icons.refresh_rounded,
                  size: UiSize.xs,
                  tooltip: 'Refresh Network',
                  onPressed: () => setState(() {}),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Suggested
  // ---------------------------------------------------------------------------

  Widget _buildSuggestedTab({required double topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.displayName.toLowerCase().contains(q) ||
          t.handle.toLowerCase().contains(q) ||
          (t.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();

    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Following
  // ---------------------------------------------------------------------------

  Widget _buildFollowingTab({required double topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders
        .where((t) => t.isFollowing)
        .toList();

    if (traders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding + context.sp(theme.spacing.xl),
            bottom: context.sp(theme.spacing.xl),
            left: context.sp(theme.spacing.xl),
            right: context.sp(theme.spacing.xl),
          ),
          child: UiEmptyState(
            icon: Icons.person_add_disabled_outlined,
            title: 'Not following anyone yet',
            message:
                'Browse the suggested traders tab to build your trading network.',
          ),
        ),
      );
    }

    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Followers
  // ---------------------------------------------------------------------------

  Widget _buildFollowersTab({required double topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders.reversed.toList();

    return _buildTraderList(traders, isMobile, theme, topPadding: topPadding);
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Leaderboard
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboardTab({required double topPadding}) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final entries = widget.repository.leaderboard;

    return Column(
      children: [
        SizedBox(height: topPadding + context.sp(theme.spacing.xs)),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ranked by Win-Rate',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiToggleGroup<String>(
                size: UiSize.xs,
                variant: UiToggleGroupVariant.segmented,
                value: _leaderboardPeriod,
                onChanged: (v) => setState(() => _leaderboardPeriod = v),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Responsive Trader List / Grid with Dynamic Card Heights
  // ---------------------------------------------------------------------------

  Widget _buildTraderList(
    List<CommunityAuthor> traders,
    bool isMobile,
    UiTheme theme, {
    required double topPadding,
  }) {
    if (traders.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(
            top: topPadding + context.sp(theme.spacing.xl),
            bottom: context.sp(theme.spacing.xl),
            left: context.sp(theme.spacing.xl),
            right: context.sp(theme.spacing.xl),
          ),
          child: UiEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No traders found',
            message: 'Try adjusting your search query or filters.',
          ),
        ),
      );
    }

    if (isMobile) {
      return ListView.separated(
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
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int crossAxisCount = constraints.maxWidth > 900
            ? 3
            : (constraints.maxWidth > 600 ? 2 : 1);

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

        final List<List<CommunityAuthor>> columns = List.generate(
          crossAxisCount,
          (_) => <CommunityAuthor>[],
        );
        for (int i = 0; i < traders.length; i++) {
          columns[i % crossAxisCount].add(traders[i]);
        }

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.sp(theme.spacing.md),
            topPadding + context.sp(theme.spacing.xs),
            context.sp(theme.spacing.md),
            context.sp(theme.spacing.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int c = 0; c < crossAxisCount; c++) ...[
                if (c > 0) SizedBox(width: context.sp(theme.spacing.sm)),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int r = 0; r < columns[c].length; r++) ...[
                        if (r > 0)
                          SizedBox(height: context.sp(theme.spacing.sm)),
                        CommunityTraderCard(
                          trader: columns[c][r],
                          onTap: () =>
                              widget.onAuthorTap?.call(columns[c][r]),
                          onFollow: () =>
                              widget.repository.toggleFollow(columns[c][r].id),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
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
