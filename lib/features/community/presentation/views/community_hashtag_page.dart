import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';
import 'package:alphajournal/features/community/data/community_repository.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/views/community_post_detail_view.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_feed_list.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_trader_card.dart';

/// Clean, overlay-friendly drill-in view for `#tag` and `$TICKER` topics.
class CommunityHashtagPage extends StatefulWidget {
  const CommunityHashtagPage({
    super.key,
    required this.tag,
    required this.repository,
    this.currentUser,
    this.onPostTap,
    this.onAuthorTap,
    this.onBack,
    this.onOpenRef,
    this.onTagTap,
  });

  final String tag;
  final CommunityRepository repository;
  final CommunityAuthor? currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onBack;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;

  @override
  State<CommunityHashtagPage> createState() => _CommunityHashtagPageState();
}

class _CommunityHashtagPageState extends State<CommunityHashtagPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isFollowingTag = false;
  late List<CommunityPost> _posts;

  static const List<String> _tabs = <String>['Top Posts', 'Latest', 'Traders'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(() {
        if (mounted && !_tabController.indexIsChanging) {
          setState(() {});
        }
      });
    _loadData();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.repository.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) {
      setState(() => _loadData());
    }
  }

  void _loadData() {
    final clean = widget.tag.replaceAll('#', '').replaceAll(r'$', '');
    _posts = widget.repository.fetchHashtagPosts(clean);
  }

  List<CommunityPost> _postsForTab(int index) {
    final posts = List<CommunityPost>.of(_posts);
    if (index == 1) {
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else {
      posts.sort(
        (a, b) => (b.likes + b.comments + b.reposts).compareTo(
          a.likes + a.comments + a.reposts,
        ),
      );
    }
    return posts;
  }

  List<CommunityAuthor> get _uniqueTraders {
    final seen = <String>{};
    final result = <CommunityAuthor>[];
    for (final post in _posts) {
      if (seen.add(post.author.id)) {
        result.add(post.author);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final colors = theme.colors;
    final bool isTicker = widget.tag.startsWith(r'$');
    final String displayTag =
        widget.tag.startsWith('#') || isTicker ? widget.tag : '#${widget.tag}';
    final int postCount = _posts.length;
    final int traderCount = _uniqueTraders.length;
    final String statsLine =
        '$postCount ${postCount == 1 ? 'discussion' : 'discussions'} · '
        '$traderCount ${traderCount == 1 ? 'trader' : 'traders'}';

    if (widget.repository.isLoading && widget.repository.forYouPosts.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: UiSkeleton.community(tab: 1),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Compact topic stats & Follow action bar (no duplicate title)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.sp(theme.spacing.md),
                  context.sp(theme.spacing.xs),
                  context.sp(theme.spacing.md),
                  context.sp(theme.spacing.sm),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: context.radius(theme.radii.md),
                        border: Border.all(
                          color: colors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        isTicker ? r'$' : '#',
                        style: context.uiText.bodyStrong.copyWith(
                          color: colors.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            isTicker ? 'Ticker Topic' : 'Community Topic',
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundSubtle,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            statsLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.caption.copyWith(
                              color: colors.foregroundMuted,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: context.sp(theme.spacing.sm)),
                    UiButton(
                      label: _isFollowingTag ? 'Following' : 'Follow',
                      leadingIcon: _isFollowingTag
                          ? Icons.check_rounded
                          : Icons.bookmark_add_outlined,
                      variant: _isFollowingTag
                          ? UiVariant.outline
                          : UiVariant.soft,
                      intent: UiIntent.primary,
                      size: UiSize.sm,
                      rounded: true,
                      onPressed: () {
                        setState(() => _isFollowingTag = !_isFollowingTag);
                        UiToast.show(
                          context,
                          title: _isFollowingTag
                              ? 'Following Topic'
                              : 'Unfollowed',
                          message: _isFollowingTag
                              ? 'Following $displayTag updates'
                              : 'Unfollowed $displayTag',
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Unified pill tab bar matching Community Feed / Explore / Network
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.sp(theme.spacing.md),
                  0,
                  context.sp(theme.spacing.md),
                  context.sp(theme.spacing.sm),
                ),
                child: CommunityPillTabBar(
                  tabs: _tabs,
                  selectedIndex: _tabController.index,
                  expandTabs: true,
                  onChanged: (int i) {
                    _tabController.animateTo(i);
                    setState(() {});
                  },
                ),
              ),

              const UiDivider(spacing: 0),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: <Widget>[
                    _buildPostsList(_postsForTab(0)),
                    _buildPostsList(_postsForTab(1)),
                    _buildTradersList(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostsList(List<CommunityPost> posts) {
    return CommunityFeedList(
      posts: posts,
      repository: widget.repository,
      currentUser: widget.currentUser ?? widget.repository.currentAuthor,
      onPostTap: (post) {
        if (widget.onPostTap != null) {
          widget.onPostTap!(post);
        } else {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityPostDetailView(
                post: post,
                repository: widget.repository,
                currentUser:
                    widget.currentUser ?? widget.repository.currentAuthor,
                onOpenRef: widget.onOpenRef,
                onTagTap: widget.onTagTap,
              ),
            ),
          );
        }
      },
      onAuthorTap: widget.onAuthorTap,
      onOpenRef: widget.onOpenRef,
      onTagTap: widget.onTagTap,
    );
  }

  Widget _buildTradersList() {
    final authors = _uniqueTraders;
    if (authors.isEmpty) {
      return const UiEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'No traders for this topic yet',
      );
    }
    return ListView.separated(
      padding: EdgeInsets.all(context.sp(16)),
      itemCount: authors.length,
      separatorBuilder: (_, _) => SizedBox(height: context.sp(12)),
      itemBuilder: (ctx, idx) {
        final author = authors[idx];
        return CommunityTraderCard(
          trader: author,
          onTap: () => widget.onAuthorTap?.call(author),
          onFollow: () => widget.repository.toggleFollow(author.id),
        );
      },
    );
  }
}
