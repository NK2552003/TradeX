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

    return Column(
      children: <Widget>[
        // Top Search & Filter Bar
        Padding(
          padding: EdgeInsets.all(
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
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


        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: theme.colors.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colors.border.withValues(alpha: 0.6),
                width: theme.borders.hairline,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: context.uiText.bodyStrong,
            unselectedLabelStyle: context.uiText.body.copyWith(
              color: theme.colors.foregroundMuted,
            ),
            labelColor: theme.colors.primary,
            unselectedLabelColor: theme.colors.foregroundMuted,
            indicatorColor: theme.colors.primary,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              _buildSuggestedTab(),
              _buildFollowingTab(),
              _buildFollowersTab(),
              _buildLeaderboardTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: Suggested
  // ---------------------------------------------------------------------------

  Widget _buildSuggestedTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders.where((t) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return t.displayName.toLowerCase().contains(q) ||
          t.handle.toLowerCase().contains(q) ||
          (t.tradingStyle?.toLowerCase().contains(q) ?? false);
    }).toList();

    return _buildTraderList(traders, isMobile, theme);
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Following
  // ---------------------------------------------------------------------------

  Widget _buildFollowingTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders
        .where((t) => t.isFollowing)
        .toList();

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

    return _buildTraderList(traders, isMobile, theme);
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Followers
  // ---------------------------------------------------------------------------

  Widget _buildFollowersTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final traders = widget.repository.suggestedTraders.reversed.toList();

    return _buildTraderList(traders, isMobile, theme);
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Leaderboard
  // ---------------------------------------------------------------------------

  Widget _buildLeaderboardTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final entries = widget.repository.leaderboard;

    return Column(
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
  }


  // ---------------------------------------------------------------------------
  // Responsive Trader List / Grid
  // ---------------------------------------------------------------------------

  Widget _buildTraderList(
    List<CommunityAuthor> traders,
    bool isMobile,
    UiTheme theme,
  ) {
    if (isMobile) {
      return ListView.separated(
        padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
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

        return GridView.builder(
          padding: EdgeInsets.all(context.sp(theme.spacing.md)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: context.sp(theme.spacing.sm),
            crossAxisSpacing: context.sp(theme.spacing.sm),
            mainAxisExtent: 180,
          ),
          itemCount: traders.length,
          itemBuilder: (BuildContext context, int index) {
            final trader = traders[index];
            return CommunityTraderCard(
              trader: trader,
              onTap: () => widget.onAuthorTap?.call(trader),
              onFollow: () => widget.repository.toggleFollow(trader.id),
            );
          },
        );
      },
    );
  }
}
