import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
    final bool isMobile = context.uiRes.isMobile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Full width top bar tab toggle across the centered panel
        _buildTopBar(context, theme, isMobile),

        // Sub-Tab Content Views (trader cards centered at maxWidth 700px beneath the bar)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: context.uiRes.isDesktop
                ? const NeverScrollableScrollPhysics()
                : null,
            children: <Widget>[
              _CommunityKeepAliveTab(child: _buildSuggestedTab()),
              _CommunityKeepAliveTab(child: _buildFollowingTab()),
              _CommunityKeepAliveTab(child: _buildFollowersTab()),
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
                    tabAlignment: isMobile
                        ? TabAlignment.start
                        : TabAlignment.fill,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.symmetric(
                      horizontal: context.sp(
                        isMobile ? theme.spacing.sm : theme.spacing.md,
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    splashBorderRadius: context.radius(theme.radii.pill),
                    overlayColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
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
                    tabs: _tabLabels.map((label) {
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
                UiIconButton(
                  icon: Icons.shield_outlined,
                  size: UiSize.xs,
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
          ),
        ),
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
      final isF = t.isFollowing || widget.repository.followedAuthorIds.contains(t.id);
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
      return const UiEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No followers yet',
        message: 'People who follow your profile will appear here.',
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
    final entries = widget.repository.leaderboard;

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
