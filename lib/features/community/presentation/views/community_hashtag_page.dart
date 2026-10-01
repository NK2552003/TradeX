import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_feed_list.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_trader_card.dart';

/// Full-page drill-in view for `#tag` and `$TICKER` topics.
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
  });

  final String tag;
  final CommunityRepository repository;
  final CommunityAuthor? currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onBack;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<CommunityHashtagPage> createState() => _CommunityHashtagPageState();
}

class _CommunityHashtagPageState extends State<CommunityHashtagPage> {
  int _selectedTabIndex = 0;
  bool _isFollowingTag = false;
  late List<CommunityPost> _posts;

  @override
  void initState() {
    super.initState();
    _loadData();
    widget.repository.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
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
    if (_posts.isEmpty) {
      _posts = widget.repository.feedPosts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final displayTag = widget.tag.startsWith('#') || widget.tag.startsWith(r'$')
        ? widget.tag
        : '#${widget.tag}';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.arrow_back,
          variant: UiVariant.ghost,
          onPressed: () => widget.onBack != null
              ? widget.onBack!()
              : Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayTag,
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
            Text(
              '${_posts.length * 142} discussions · 74% Bullish',
              style: context.uiText.caption.copyWith(
                color: colors.foregroundMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: context.sp(12)),
            child: Center(
              child: UiIconButton(
                icon: _isFollowingTag
                    ? Icons.check_rounded
                    : Icons.bookmark_add_outlined,
                variant: _isFollowingTag
                    ? UiVariant.outline
                    : UiVariant.primary,
                intent: UiIntent.primary,
                size: UiSize.sm,
                tooltip: _isFollowingTag
                    ? 'Following $displayTag'
                    : 'Follow $displayTag',
                onPressed: () {
                  setState(() => _isFollowingTag = !_isFollowingTag);
                  UiToast.show(
                    context,
                    title: _isFollowingTag ? 'Following Topic' : 'Unfollowed',
                    message: _isFollowingTag
                        ? 'Following $displayTag updates'
                        : 'Unfollowed $displayTag',
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
          child: Column(
            children: [
              // Topic Header Card
              Container(
                padding: EdgeInsets.all(context.sp(16)),
                color: colors.surface,
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(context.sp(12)),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(context.sz(12)),
                      ),
                      child: Text(
                        widget.tag.startsWith(r'$') ? r'$' : '#',
                        style: context.uiText.title.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: context.sp(12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTag,
                            style: context.uiText.title.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colors.foreground,
                            ),
                          ),
                          SizedBox(height: context.sp(4)),
                          Row(
                            children: [
                              UiBadge(
                                label: 'Bullish 74%',
                                intent: UiIntent.success,
                                variant: UiBadgeVariant.soft,
                              ),
                              SizedBox(width: context.sp(8)),
                              Text(
                                'High Momentum',
                                style: context.uiText.caption.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const UiDivider(),

              // Sub tabs
              Container(
                color: colors.surface,
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(12),
                  vertical: context.sp(8),
                ),
                child: UiTabs(
                  tabs: const ['Top Posts', 'Latest', 'Traders'],
                  selectedIndex: _selectedTabIndex,
                  onChanged: (idx) => setState(() => _selectedTabIndex = idx),
                ),
              ),
              const UiDivider(),

              // Tab Content
              Expanded(
                child: _selectedTabIndex == 2
                    ? _buildTradersList()
                    : CommunityFeedList(
                        posts: _posts,
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
                                      widget.currentUser ??
                                      widget.repository.currentAuthor,
                                  onOpenRef: widget.onOpenRef,
                                ),
                              ),
                            );
                          }
                        },
                        onAuthorTap: widget.onAuthorTap,
                        onOpenRef: widget.onOpenRef,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTradersList() {
    final authors = widget.repository.topTraders;
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
