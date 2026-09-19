import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// The central Home Feed view of the community platform, modeled on Twitter/X.
class CommunityFeedView extends StatefulWidget {
  const CommunityFeedView({
    super.key,
    required this.repository,
    required this.currentUser,
    this.onPostTap,
    this.onAuthorTap,
    this.onCompose,
  });

  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;

  /// Called when the compact mobile compose trigger is tapped.
  /// On desktop/tablet the full [CommunityComposerCard] is rendered inline
  /// instead; this callback is only invoked from the mobile compact row.
  final VoidCallback? onCompose;

  @override
  State<CommunityFeedView> createState() => _CommunityFeedViewState();
}

class _CommunityFeedViewState extends State<CommunityFeedView>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  late final ScrollController _forYouScrollController = ScrollController();
  int _newPostsCount = 0;

  static const List<String> _subTabs = <String>[
    'For you',
    'Following',
    'Signals & Setups',
    'Market News',
    'Crypto',
    'Equities',
  ];

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: _subTabs.length, vsync: this);
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _forYouScrollController.dispose();
    _subTabController.dispose();
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
        // Sticky Top Sub-Tabs Bar
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
          child: Row(
            children: <Widget>[
              Expanded(
                child: TabBar(
                  controller: _subTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelStyle: context.uiText.bodyStrong.copyWith(
                    fontSize: context.fs(isMobile ? 13 : 14),
                  ),
                  unselectedLabelStyle: context.uiText.body.copyWith(
                    fontSize: context.fs(isMobile ? 13 : 14),
                    color: theme.colors.foregroundMuted,
                  ),
                  labelColor: theme.colors.primary,
                  unselectedLabelColor: theme.colors.foregroundMuted,
                  indicatorColor: theme.colors.primary,
                  indicatorWeight: 2,
                  dividerColor: Colors.transparent,
                  tabs: _subTabs.map((label) => Tab(text: label)).toList(),
                ),
              ),
              UiIconButton(
                icon: Icons.add_rounded,
                size: UiSize.xs,
                tooltip: 'Customize Feed Tabs',
                onPressed: () {
                  CommunityFeedCustomizerDialog.show(
                    context,
                    repository: widget.repository,
                  );
                },
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
            ],
          ),
        ),

        // Sub-Tab Content Views
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: <Widget>[
              // Tab 0: For you
              _buildForYouTab(),
              // Tab 1: Following
              _buildFollowingTab(),
              // Tab 2: Signals & Setups
              _buildSignalsTab(),
              // Tab 3: Market News
              _buildNewsTab(),
              // Tab 4: Crypto
              _buildCryptoTab(),
              // Tab 5: Equities
              _buildEquitiesTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0: For you
  // ---------------------------------------------------------------------------

  Widget _buildForYouTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = widget.repository.forYouPosts;

    // On mobile, replace the full composer card with a lightweight compact
    // trigger row — the actual compose sheet opens via the FAB or the tap.
    final Widget composeHeader = isMobile
        ? _buildCompactComposeTrigger(theme)
        : Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.sm),
            ),
            child: CommunityComposerCard(
              author: widget.currentUser,
              repository: widget.repository,
            ),
          );

    final Widget feedList = CommunityFeedList(
      controller: _forYouScrollController,
      posts: posts,
      header: composeHeader,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onRefresh: () async => setState(() {}),
    );

    return Stack(
      children: <Widget>[
        feedList,
        if (_newPostsCount > 0)
          Positioned(
            top: context.sp(theme.spacing.sm),
            left: 0,
            right: 0,
            child: CommunityNewPostsPill(
              count: _newPostsCount,
              onTap: () {
                _forYouScrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                );
                setState(() => _newPostsCount = 0);
              },
            ),
          ),
      ],
    );
  }

  /// Compact mobile compose trigger — avatar + placeholder text.
  /// Tapping opens the bottom-sheet composer via [widget.onCompose].
  Widget _buildCompactComposeTrigger(UiTheme theme) {
    return InkWell(
      onTap: widget.onCompose,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.md),
          vertical: context.sp(theme.spacing.sm),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colors.border.withValues(alpha: 0.5),
              width: theme.borders.hairline,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            UiAvatar(
              name: widget.currentUser.displayName,
              imageUrl: widget.currentUser.avatarUrl,
              size: UiSize.sm,
            ),
            SizedBox(width: context.sp(theme.spacing.sm)),
            Expanded(
              child: Text(
                "What's your trade thesis today?",
                style: context.uiText.body.copyWith(
                  color: theme.colors.foregroundSubtle,
                ),
              ),
            ),
            UiButton(
              label: 'Post',
              variant: UiVariant.primary,
              size: UiSize.xs,
              expandOnMobile: false,
              onPressed: widget.onCompose,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Following
  // ---------------------------------------------------------------------------

  Widget _buildFollowingTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = widget.repository.followingPosts;

    return CommunityFeedList(
      posts: posts,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onRefresh: () async => setState(() {}),
      emptyState: Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.person_add_outlined,
            title: 'No posts yet',
            message:
                'Follow other traders to see their setups and execution notes here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Signals & Setups
  // ---------------------------------------------------------------------------

  Widget _buildSignalsTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = widget.repository.signalPosts;

    return CommunityFeedList(
      posts: posts,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onRefresh: () async => setState(() {}),
      emptyState: Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.candlestick_chart_rounded,
            title: 'No trade signals found',
            message:
                'Published trades with entry, exit and stop levels will appear here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Market News
  // ---------------------------------------------------------------------------

  Widget _buildNewsTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final news = widget.repository.news;

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        vertical: context.sp(theme.spacing.sm),
      ),
      itemCount: news.length,
      itemBuilder: (BuildContext context, int index) {
        final item = news[index];
        final sentimentIntent = item.sentimentScore > 0.3
            ? UiIntent.success
            : (item.sentimentScore < -0.2 ? UiIntent.danger : UiIntent.info);

        return Padding(
          padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
          child: UiCard(
            padding: EdgeInsets.all(context.sp(theme.spacing.md)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    UiBadge(
                      label: item.category,
                      intent: sentimentIntent,
                      variant: UiBadgeVariant.solid,
                      size: UiSize.xs,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(
                      child: Text(
                        '${item.source} · ${AppTokens.relativeTime(item.publishedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundSubtle,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  item.headline,
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.summary != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.xs)),
                  Text(
                    item.summary!,
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                      height: 1.4,
                    ),
                  ),
                ],
                if (item.relatedTickers.isNotEmpty) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    children: item.relatedTickers.map((t) {
                      return UiBadge(
                        label: '\$$t',
                        intent: UiIntent.primary,
                        variant: UiBadgeVariant.soft,
                        size: UiSize.xs,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Crypto
  // ---------------------------------------------------------------------------

  Widget _buildCryptoTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final cryptoTickers = <String>{'BTC', 'ETH', 'SOL', 'DOGE', 'USDINR'};
    final posts = widget.repository.forYouPosts.where((p) {
      return p.tickers.any((t) => cryptoTickers.contains(t.toUpperCase())) ||
          p.tags.any((tag) => tag.toLowerCase().contains('crypto'));
    }).toList();

    return CommunityFeedList(
      posts: posts,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onRefresh: () async => setState(() {}),
      emptyState: Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.currency_bitcoin_rounded,
            title: 'No crypto setups found',
            message:
                'Posts referencing \$BTC, \$ETH, or crypto setups will appear here.',
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5: Equities
  // ---------------------------------------------------------------------------

  Widget _buildEquitiesTab() {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final posts = widget.repository.forYouPosts.where((p) {
      return p.tickers.any(
        (t) => !{'BTC', 'ETH', 'SOL', 'DOGE'}.contains(t.toUpperCase()),
      );
    }).toList();

    return CommunityFeedList(
      posts: posts,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      onPostTap: widget.onPostTap,
      onLike: (id) => widget.repository.toggleLike(id),
      onRepost: (id) => widget.repository.toggleRepost(id),
      onBookmark: (id) => widget.repository.toggleBookmark(id),
      onAuthorTap: widget.onAuthorTap,
      onRefresh: () async => setState(() {}),
      emptyState: Center(
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
          child: UiEmptyState(
            icon: Icons.show_chart_rounded,
            title: 'No equities setups found',
            message: 'Posts tagged with equity tickers will appear here.',
          ),
        ),
      ),
    );
  }
}
