import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/data/session_trader.dart';
import 'package:tradex/features/auth/models/user_profile_model.dart';
import 'package:tradex/features/community/data/repositories/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/post_composer_sheet.dart';
import 'package:tradex/features/settings/data/repositories/profile_settings_repository.dart';
import 'package:tradex/features/strategies/data/repositories/strategy_repository.dart';
import 'package:tradex/features/watchlists/data/repositories/watchlist_repository.dart';

/// Top-level community surfaces.
enum _CommunityView { feed, leaderboard, people }

/// Which side of the social graph the people view is showing.
enum _PeopleTab { suggested, following, followers }

String _peopleTabLabel(_PeopleTab tab) => switch (tab) {
  _PeopleTab.suggested => 'Discover',
  _PeopleTab.following => 'Following',
  _PeopleTab.followers => 'Followers',
};

/// The social hub: a scoped feed with composer and post detail, a leaderboard,
/// and the follower graph. Every row comes from [CommunityRepository]; the
/// signed-in identity comes from [ProfileSettingsRepository] so nothing about
/// the current user is hardcoded in the view.
class CommunityPage extends StatefulWidget {
  const CommunityPage({
    super.key,
    this.repository,
    this.profileRepository,
    this.strategyRepository,
    this.watchlistRepository,
    this.onOpenSymbol,
    this.onMessageTrader,
  });

  final CommunityRepository? repository;
  final ProfileSettingsRepository? profileRepository;
  final StrategyRepository? strategyRepository;
  final WatchlistRepository? watchlistRepository;

  /// Opens the market view for a tapped `$TICKER`.
  final ValueChanged<String>? onOpenSymbol;

  /// Starts a DM with a trader — wired to the messages surface by the shell.
  final ValueChanged<AppTrader>? onMessageTrader;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late final CommunityRepository _repo =
      widget.repository ?? CommunityRepositoryImpl();
  late final ProfileSettingsRepository _profiles =
      widget.profileRepository ?? ProfileSettingsRepositoryImpl();
  late final StrategyRepository _strategies =
      widget.strategyRepository ?? StrategyRepositoryImpl();
  late final WatchlistRepository _markets =
      widget.watchlistRepository ?? WatchlistRepositoryImpl();

  AppTrader? _me;
  List<AppPost> _posts = const <AppPost>[];
  List<AppTrader> _suggested = const <AppTrader>[];
  List<AppTrader> _following = const <AppTrader>[];
  List<AppTrader> _followers = const <AppTrader>[];
  List<MapEntry<AppTrader, double>> _leaderboard =
      const <MapEntry<AppTrader, double>>[];
  List<TrendingTopic> _trending = const <TrendingTopic>[];
  List<String> _symbols = const <String>[];
  List<String> _playbooks = const <String>[];

  AppPost? _openPost;
  AppTrader? _selectedTrader;
  List<AppPost> _traderPosts = const <AppPost>[];
  List<AppComment> _comments = const <AppComment>[];
  String _commentDraft = '';
  bool _sendingComment = false;

  CommunityFeedScope _scope = CommunityFeedScope.forYou;
  _CommunityView _view = _CommunityView.feed;
  _PeopleTab _peopleTab = _PeopleTab.suggested;
  String _period = 'Week';
  String _search = '';
  bool _loading = true;
  bool _loadingFeed = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _profiles.getProfile(),
      _repo.getSuggestedTraders(),
      _repo.getFollowing(),
      _repo.getFollowers(),
      _repo.getTrending(),
      _repo.getLeaderboard(_period),
      _markets.getAvailableSymbols(),
      _strategies.getStrategies(),
    ]);
    if (!mounted) return;
    setState(() {
      _me = appTraderFromProfile(results[0]! as UserProfileModel);
      _suggested = results[1]! as List<AppTrader>;
      _following = results[2]! as List<AppTrader>;
      _followers = results[3]! as List<AppTrader>;
      _trending = results[4]! as List<TrendingTopic>;
      _leaderboard = results[5]! as List<MapEntry<AppTrader, double>>;
      _symbols = results[6]! as List<String>;
      _playbooks = (results[7]! as List<AppStrategy>)
          .map((AppStrategy s) => s.name)
          .toList(growable: false);
    });
    await _loadFeed();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadFeed() async {
    setState(() => _loadingFeed = true);
    final List<AppPost> posts = await _repo.getFeed(
      _scope,
      query: _search.isEmpty ? null : _search,
    );
    if (!mounted) return;
    setState(() {
      _posts = posts;
      _loadingFeed = false;
    });
  }

  void _setScope(CommunityFeedScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _openPost = null;
    });
    _loadFeed();
  }

  void _setSearch(String value) {
    setState(() => _search = value);
    _loadFeed();
  }

  Future<void> _openDetail(AppPost post) async {
    setState(() {
      _openPost = post;
      _comments = const <AppComment>[];
      _commentDraft = '';
    });
    final List<AppComment> comments = await _repo.getComments(post.id);
    if (!mounted || _openPost?.id != post.id) return;
    setState(() => _comments = comments);
  }

  /// Replaces a post in every list that may be showing it.
  void _replace(AppPost post) => setState(() {
    _posts = _posts
        .map((AppPost p) => p.id == post.id ? post : p)
        .toList(growable: false);
    if (_openPost?.id == post.id) _openPost = post;
  });

  Future<void> _toggleLike(AppPost post) async {
    final AppPost updated = await _repo.toggleLike(post.id);
    if (!mounted) return;
    _replace(updated);
  }

  Future<void> _toggleSave(AppPost post) async {
    final AppPost updated = await _repo.toggleSave(post.id);
    if (!mounted) return;
    _replace(updated);
    UiToast.show(
      context,
      title: updated.saved ? 'Saved' : 'Removed from saved',
      message: updated.saved
          ? 'Find it under the Saved scope.'
          : 'The post is no longer bookmarked.',
      intent: updated.saved ? UiIntent.success : UiIntent.neutral,
    );
    if (_scope == CommunityFeedScope.saved) await _loadFeed();
  }

  Future<void> _compose() async {
    final AppTrader? me = _me;
    if (me == null) return;
    final AppPost? draft = await showPostComposerSheet(
      context,
      me: me,
      symbols: _symbols,
      playbooks: _playbooks,
    );
    if (draft == null || !mounted) return;
    setState(() => _posting = true);
    await _repo.createPost(draft);
    if (!mounted) return;
    setState(() => _posting = false);
    UiToast.show(
      context,
      title: 'Posted',
      message: 'Your ${draft.type ?? 'note'} is live on the feed.',
      intent: UiIntent.success,
    );
    if (_scope != CommunityFeedScope.forYou) {
      _setScope(CommunityFeedScope.forYou);
    } else {
      await _loadFeed();
    }
  }

  Future<void> _sendComment() async {
    final AppPost? post = _openPost;
    final AppTrader? me = _me;
    final String body = _commentDraft.trim();
    if (post == null || me == null || body.isEmpty) return;
    setState(() => _sendingComment = true);
    final AppComment comment = await _repo.addComment(
      post.id,
      AppComment(
        id: 'cmt_${DateTime.now().microsecondsSinceEpoch}',
        author: me,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() {
      _comments = <AppComment>[comment, ..._comments];
      _commentDraft = '';
      _sendingComment = false;
      _openPost = _postWithComments(post, post.comments + 1);
    });
    _replace(_openPost!);
  }

  AppPost _postWithComments(AppPost post, int comments) => AppPost(
    id: post.id,
    author: post.author,
    body: post.body,
    createdAt: post.createdAt,
    type: post.type,
    tickers: post.tickers,
    imageUrl: post.imageUrl,
    attachments: post.attachments,
    likes: post.likes,
    comments: comments,
    liked: post.liked,
    saved: post.saved,
  );

  Future<void> _toggleFollow(AppTrader trader) async {
    final AppTrader updated = await _repo.toggleFollow(trader.id);
    if (!mounted) return;
    final List<AppTrader> suggested = await _repo.getSuggestedTraders();
    final List<AppTrader> following = await _repo.getFollowing();
    final List<AppTrader> followers = await _repo.getFollowers();
    if (!mounted) return;
    setState(() {
      _suggested = suggested;
      _following = following;
      _followers = followers;
    });
    UiToast.show(
      context,
      title: updated.isFollowing
          ? 'Following @${updated.handle}'
          : 'Unfollowed @${updated.handle}',
      message: updated.isFollowing
          ? 'Their posts now appear in your Following feed.'
          : 'You will no longer see their posts there.',
      intent: updated.isFollowing ? UiIntent.success : UiIntent.neutral,
    );
    if (_scope == CommunityFeedScope.following) await _loadFeed();
  }

  Future<void> _setPeriod(String period) async {
    if (period == _period) return;
    setState(() => _period = period);
    final List<MapEntry<AppTrader, double>> rows = await _repo.getLeaderboard(
      period,
    );
    if (!mounted) return;
    setState(() => _leaderboard = rows);
  }

  /// Opens a trader profile in the people view, with the posts they wrote.
  Future<void> _openTrader(AppTrader trader) async {
    setState(() {
      _view = _CommunityView.people;
      _selectedTrader = trader;
      _traderPosts = const <AppPost>[];
    });
    final List<AppPost> posts = await _repo.getFeed(
      CommunityFeedScope.forYou,
      query: trader.handle,
    );
    if (!mounted || _selectedTrader?.id != trader.id) return;
    setState(
      () => _traderPosts = posts
          .where((AppPost p) => p.author.id == trader.id)
          .toList(growable: false),
    );
  }

  List<AppTrader> get _peopleRows => switch (_peopleTab) {
    _PeopleTab.suggested => _suggested,
    _PeopleTab.following => _following,
    _PeopleTab.followers => _followers,
  };

  /// Feed-level headline numbers, all derived from what is on screen.
  String get _subtitle {
    if (_loading) return 'Loading the room…';
    final int likes = _posts.fold<int>(0, (int s, AppPost p) => s + p.likes);
    return '${_posts.length} posts · $likes likes · '
        '${_following.length} following · ${_followers.length} followers';
  }

  @override
  Widget build(BuildContext context) {
    final bool mobileDetail =
        context.uiRes.isMobile &&
        _view == _CommunityView.feed &&
        _openPost != null;

    return AppPageBlock(
      title: 'Community',
      subtitle: _subtitle,
      scrollable: false,
      actions: <Widget>[
        UiButton(
          label: 'Refresh',
          variant: UiVariant.outline,
          leadingIcon: Icons.refresh_rounded,
          expandOnMobile: false,
          hideLabelOnMobile: true,
          loading: _loadingFeed,
          onPressed: _loadFeed,
        ),
        UiButton(
          label: 'New post',
          leadingIcon: Icons.edit_outlined,
          expandOnMobile: false,
          loading: _posting,
          onPressed: _me == null ? null : _compose,
        ),
      ],
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (!mobileDetail) ...<Widget>[
              UiToggleGroup<_CommunityView>(
                options: <UiToggleOption<_CommunityView>>[
                  const UiToggleOption<_CommunityView>(
                    value: _CommunityView.feed,
                    label: 'Feed',
                    icon: Icons.dynamic_feed_rounded,
                  ),
                  const UiToggleOption<_CommunityView>(
                    value: _CommunityView.leaderboard,
                    label: 'Leaderboard',
                    icon: Icons.emoji_events_outlined,
                  ),
                  UiToggleOption<_CommunityView>(
                    value: _CommunityView.people,
                    label: 'People',
                    icon: Icons.group_outlined,
                    badge: _following.isEmpty ? null : '${_following.length}',
                  ),
                ],
                value: _view,
                expand: context.uiRes.isMobile,
                onChanged: (_CommunityView view) =>
                    setState(() => _view = view),
              ),
              UiGap.v(context.ui.spacing.lg),
            ],
            Expanded(
              child: switch (_view) {
                _CommunityView.feed => _feedView(),
                _CommunityView.leaderboard => _leaderboardView(),
                _CommunityView.people => _peopleView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedView() {
    final AppPost? open = _openPost;
    return AppWorkspacePane(
      initialRatio: 0.52,
      hasSelection: open != null,
      onClearSelection: () => setState(() => _openPost = null),
      listTitle: communityFeedScopeLabel(_scope),
      detailTitle: open == null ? null : 'Post',
      breadcrumbs: <UiCrumb>[
        UiCrumb(
          label: 'Community',
          onTap: () => setState(() => _openPost = null),
        ),
        UiCrumb(label: communityFeedScopeLabel(_scope)),
        if (open != null) UiCrumb(label: '@${open.author.handle}'),
      ],
      detailActions: <Widget>[
        if (open != null)
          UiIconButton(
            icon: open.saved ? Icons.bookmark : Icons.bookmark_border,
            tooltip: open.saved ? 'Remove bookmark' : 'Save post',
            onPressed: () => _toggleSave(open),
          ),
        if (open != null && widget.onMessageTrader != null)
          UiIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Message @${open.author.handle}',
            onPressed: () => widget.onMessageTrader!(open.author),
          ),
      ],
      placeholderTitle: 'Open a post',
      placeholderMessage:
          'Tap any post to read the full thread and reply inline.',
      placeholderIcon: Icons.forum_outlined,
      list: _feedList(),
      detail: open == null
          ? const SizedBox.shrink()
          : AppFadeIn(
              key: ValueKey<String>(open.id),
              child: _postDetail(open),
            ),
    );
  }

  /// The pane already scrolls, so this returns a plain column.
  Widget _feedList() {
    final AppTrader? me = _me;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
          UiToggleGroup<CommunityFeedScope>(
            options: <UiToggleOption<CommunityFeedScope>>[
              for (final CommunityFeedScope scope in CommunityFeedScope.values)
                UiToggleOption<CommunityFeedScope>(
                  value: scope,
                  label: communityFeedScopeLabel(scope),
                ),
            ],
            value: _scope,
            variant: UiToggleGroupVariant.underline,
            expand: context.uiRes.isMobile,
            onChanged: _setScope,
          ),
          UiGap.v(context.ui.spacing.md),
          UiSearchField(
            value: _search,
            hintText: 'Search posts, handles or tickers',
            loading: _loadingFeed,
            onChanged: _setSearch,
          ),
          UiGap.v(context.ui.spacing.md),
          if (me != null) ...<Widget>[
            AppComposerBlock(
              me: me,
              submitting: _posting,
              onAttach: _compose,
              onSubmit: _compose,
              onChanged: (String _) {},
            ),
            UiGap.v(context.ui.spacing.md),
          ],
          if (!context.uiRes.isDesktop && _trending.isNotEmpty) ...<Widget>[
            _trendingCard(),
            UiGap.v(context.ui.spacing.md),
          ],
          AppFeedBlock(
            posts: _posts,
            loading: _loading || _loadingFeed,
            onOpen: _openDetail,
            onLike: _toggleLike,
            onSave: _toggleSave,
            onComment: _openDetail,
            onAuthorTap: _openTrader,
          ),
          if (!_loading && !_loadingFeed && _posts.isEmpty && _search.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: context.sp(context.ui.spacing.md)),
              child: UiButton(
                label: 'Clear search',
                variant: UiVariant.ghost,
                expand: true,
                onPressed: () => _setSearch(''),
              ),
            ),
      ],
    );
  }

  Widget _postDetail(AppPost post) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      AppPostCard(
        post: post,
        onLike: () => _toggleLike(post),
        onSave: () => _toggleSave(post),
        onAuthorTap: () => _openTrader(post.author),
        onTickerTap: widget.onOpenSymbol,
      ),
      UiGap.v(context.ui.spacing.lg),
      UiCard(
        title: 'Replies',
        subtitle: _comments.isEmpty
            ? 'Be the first to weigh in.'
            : '${_comments.length} in the thread',
        child: _comments.isEmpty && post.comments > 0
            ? UiSkeleton(height: context.sz(120))
            : AppCommentThreadBlock(
                comments: _comments,
                draft: _commentDraft,
                onDraftChanged: (String value) =>
                    setState(() => _commentDraft = value),
                onSend: _sendingComment ? null : _sendComment,
              ),
      ),
      UiGap.v(context.ui.spacing.lg),
      UiCard(
        title: 'About @${post.author.handle}',
        child: AppTraderCard(
          trader: post.author,
          onFollow: () => _toggleFollow(post.author),
          onMessage: widget.onMessageTrader == null
              ? null
              : () => widget.onMessageTrader!(post.author),
        ),
      ),
      if (post.tickers.isNotEmpty) ...<Widget>[
        UiGap.v(context.ui.spacing.lg),
        UiCard(
          title: 'Mentioned instruments',
          subtitle: 'Jump straight to the chart.',
          child: Wrap(
            spacing: context.sp(context.ui.spacing.sm),
            runSpacing: context.sp(context.ui.spacing.sm),
            children: <Widget>[
              for (final String ticker in post.tickers)
                UiButton(
                  label: '\$$ticker',
                  size: UiSize.sm,
                  variant: UiVariant.outline,
                  trailingIcon: Icons.arrow_outward_rounded,
                  expandOnMobile: false,
                  onPressed: widget.onOpenSymbol == null
                      ? null
                      : () => widget.onOpenSymbol!(ticker),
                ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _trendingCard() => UiCard(
    title: 'Trending now',
    subtitle: 'Instruments the room is talking about.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final TrendingTopic topic in _trending)
          Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
            child: UiCard(
              variant: UiCardVariant.surface,
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(context.ui.spacing.md),
                vertical: context.sp(context.ui.spacing.sm),
              ),
              onTap: () => _setSearch(topic.label),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('\$${topic.label}',
                            style: context.uiText.bodyStrong),
                        Text(
                          '${topic.posts} posts',
                          style: context.uiText.caption.copyWith(
                            color: context.uiColors.foregroundMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  UiBadge.delta(topic.changePercent),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  /// Leaderboard headline stats, derived from the loaded rows.
  List<AppStat> _leaderStats() {
    if (_leaderboard.isEmpty) return const <AppStat>[];
    final List<double> values = _leaderboard
        .map((MapEntry<AppTrader, double> e) => e.value)
        .toList(growable: false);
    final double total = values.fold<double>(0, (double s, double v) => s + v);
    final int green = values.where((double v) => v > 0).length;
    final MapEntry<AppTrader, double> top = _leaderboard.first;
    return <AppStat>[
      AppStat(
        label: 'Leader',
        value: top.value,
        icon: Icons.emoji_events_outlined,
        formatter: AppTokens.signedMoney,
        suffix: ' · @${top.key.handle}',
      ),
      AppStat(
        label: 'Desk total',
        value: total,
        icon: Icons.summarize_outlined,
        formatter: AppTokens.signedMoney,
      ),
      AppStat(
        label: 'Profitable',
        value: green / values.length * 100,
        icon: Icons.groups_outlined,
        formatter: AppTokens.percent,
        suffix: ' · $green of ${values.length}',
      ),
      AppStat(
        label: 'Median',
        value: _median(values),
        icon: Icons.stacked_line_chart_rounded,
        formatter: AppTokens.signedMoney,
        spark: values,
      ),
    ];
  }

  double _median(List<double> values) {
    final List<double> sorted = <double>[...values]..sort();
    final int mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  Widget _leaderboardView() => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppStatGridBlock(stats: _leaderStats(), loading: _loading),
        UiGap.v(context.ui.spacing.lg),
        AppDashboardLayoutBlock(
          main: <Widget>[
            AppFadeIn(
              child: AppLeaderboardBlock(
                entries: _leaderboard,
                period: _period,
                onPeriodChanged: _setPeriod,
                onOpen: _openTrader,
              ),
            ),
          ],
          side: <Widget>[
            if (_trending.isNotEmpty) _trendingCard(),
            UiCard(
              title: 'How ranking works',
              child: UiCallout(
                title: 'Realised P/L over the selected window',
                message:
                    'Only closed trades from public journals count. Traders with '
                    'private stats are excluded until they opt in.',
                intent: UiIntent.info,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _peopleView() {
    final AppTrader? selected = _selectedTrader;
    final List<AppTrader> rows = _peopleRows;
    return AppWorkspacePane(
      initialRatio: 0.42,
      hasSelection: selected != null,
      onClearSelection: () => setState(() => _selectedTrader = null),
      listTitle: _peopleTabLabel(_peopleTab),
      detailTitle: selected == null ? null : '@${selected.handle}',
      breadcrumbs: <UiCrumb>[
        UiCrumb(
          label: 'People',
          onTap: () => setState(() => _selectedTrader = null),
        ),
        UiCrumb(label: _peopleTabLabel(_peopleTab)),
        if (selected != null) UiCrumb(label: '@${selected.handle}'),
      ],
      detailActions: <Widget>[
        if (selected != null && widget.onMessageTrader != null)
          UiIconButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Message',
            onPressed: () => widget.onMessageTrader!(selected),
          ),
      ],
      placeholderTitle: 'Pick a trader',
      placeholderMessage:
          'Open a profile to see their stats and recent public posts.',
      placeholderIcon: Icons.person_search_outlined,
      list: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          UiToggleGroup<_PeopleTab>(
            options: <UiToggleOption<_PeopleTab>>[
              UiToggleOption<_PeopleTab>(
                value: _PeopleTab.suggested,
                label: _peopleTabLabel(_PeopleTab.suggested),
                badge: '${_suggested.length}',
              ),
              UiToggleOption<_PeopleTab>(
                value: _PeopleTab.following,
                label: _peopleTabLabel(_PeopleTab.following),
                badge: '${_following.length}',
              ),
              UiToggleOption<_PeopleTab>(
                value: _PeopleTab.followers,
                label: _peopleTabLabel(_PeopleTab.followers),
                badge: '${_followers.length}',
              ),
            ],
            value: _peopleTab,
            variant: UiToggleGroupVariant.underline,
            expand: context.uiRes.isMobile,
            onChanged: (_PeopleTab tab) => setState(() => _peopleTab = tab),
          ),
          UiGap.v(context.ui.spacing.md),
          if (_loading)
            UiCard(child: UiSkeleton(height: context.sz(220)))
          else if (rows.isEmpty)
            UiEmptyState(
              title: switch (_peopleTab) {
                _PeopleTab.suggested => 'You follow everyone already',
                _PeopleTab.following => 'Not following anyone yet',
                _PeopleTab.followers => 'No followers yet',
              },
              message: switch (_peopleTab) {
                _PeopleTab.suggested =>
                  'Check back as new traders join the desk.',
                _PeopleTab.following =>
                  'Follow a few traders to shape your feed.',
                _PeopleTab.followers =>
                  'Post your process — followers come from consistency.',
              },
              icon: Icons.group_outlined,
              action: _peopleTab == _PeopleTab.following
                  ? UiButton(
                      label: 'Find traders',
                      variant: UiVariant.outline,
                      expandOnMobile: false,
                      onPressed: () =>
                          setState(() => _peopleTab = _PeopleTab.suggested),
                    )
                  : null,
            )
          else
            for (int i = 0; i < rows.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: context.sp(context.ui.spacing.sm),
                ),
                child: AppFadeIn(
                  delay: AppMotion.step * (i % 6),
                  child: AppTraderCard(
                    trader: rows[i],
                    selected: rows[i].id == selected?.id,
                    onTap: () => _openTrader(rows[i]),
                    onFollow: () => _toggleFollow(rows[i]),
                    onMessage: widget.onMessageTrader == null
                        ? null
                        : () => widget.onMessageTrader!(rows[i]),
                  ),
                ),
              ),
        ],
      ),
      detail: selected == null
          ? const SizedBox.shrink()
          : AppFadeIn(
              key: ValueKey<String>(selected.id),
              child: _traderDetail(selected),
            ),
    );
  }

  Widget _traderDetail(AppTrader trader) {
    final int rank =
        _leaderboard.indexWhere(
          (MapEntry<AppTrader, double> e) => e.key.id == trader.id,
        ) +
        1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTraderCard(
          trader: trader,
          onFollow: () => _toggleFollow(trader),
          onMessage: widget.onMessageTrader == null
              ? null
              : () => widget.onMessageTrader!(trader),
        ),
        UiGap.v(context.ui.spacing.lg),
        AppDashboardLayoutBlock(
          main: <Widget>[
            UiCard(
              title: 'Recent posts',
              subtitle: _traderPosts.isEmpty
                  ? 'Nothing public in the current window.'
                  : '${_traderPosts.length} public ${_traderPosts.length == 1 ? 'post' : 'posts'}',
              child: AppFeedBlock(
                posts: _traderPosts,
                onOpen: (AppPost post) {
                  setState(() => _view = _CommunityView.feed);
                  _openDetail(post);
                },
                onLike: _toggleLike,
                onSave: _toggleSave,
              ),
            ),
          ],
          side: <Widget>[
            UiCard(
              title: 'Standing',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _statRow(
                    'Leaderboard',
                    rank > 0 ? '#$rank · $_period' : 'Unranked',
                  ),
                  _statRow('Followers', '${trader.followers}'),
                  _statRow('Following', '${trader.following}'),
                  if (trader.winRate != null)
                    _statRow('Win rate', AppTokens.percent(trader.winRate!)),
                  _statRow('Plan', AppTokens.tierLabel(trader.tier)),
                  if (trader.tradingStyle != null)
                    _statRow('Style', trader.tradingStyle!),
                ],
              ),
            ),
            UiCard(
              title: 'Actions',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  UiButton(
                    label: trader.isFollowing ? 'Unfollow' : 'Follow',
                    leadingIcon: trader.isFollowing
                        ? Icons.person_remove_outlined
                        : Icons.person_add_alt_1_outlined,
                    variant: trader.isFollowing
                        ? UiVariant.outline
                        : UiVariant.primary,
                    expand: true,
                    onPressed: () => _toggleFollow(trader),
                  ),
                  UiGap.v(context.ui.spacing.sm),
                  UiButton(
                    label: 'Send a message',
                    leadingIcon: Icons.chat_bubble_outline_rounded,
                    variant: UiVariant.secondary,
                    expand: true,
                    onPressed: widget.onMessageTrader == null
                        ? null
                        : () => widget.onMessageTrader!(trader),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statRow(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.sm)),
    child: Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: context.uiText.caption.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
          ),
        ),
        Text(value, style: context.uiText.bodyStrong),
      ],
    ),
  );
}
