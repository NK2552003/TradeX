import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// Both unified libraries are required by the project UI contract.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_feed_list.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';
import 'package:tradex/features/community/presentation/widgets/community_trader_card.dart';

/// Full-page search experience for posts, traders, and cashtags.
class CommunitySearchPage extends StatefulWidget {
  const CommunitySearchPage({
    super.key,
    required this.repository,
    this.initialQuery = '',
    this.currentUser,
    this.onPostTap,
    this.onAuthorTap,
    this.onHashtagTap,
    this.onBack,
    this.onOpenRef,
  });

  final CommunityRepository repository;
  final String initialQuery;
  final CommunityAuthor? currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onHashtagTap;
  final VoidCallback? onBack;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<CommunitySearchPage> createState() => _CommunitySearchPageState();
}

class _CommunitySearchPageState extends State<CommunitySearchPage> {
  String _query = '';
  int _selectedCategory = 0; // All, Posts, Traders
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    widget.repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CommunitySearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      widget.repository.addListener(_onRepositoryChanged);
    }
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  void _onSearch(String value) => setState(() => _query = value);

  void _rememberSearch(String value) {
    final term = value.trim();
    if (term.isEmpty) return;
    setState(() {
      _recentSearches.removeWhere(
        (item) => item.toLowerCase() == term.toLowerCase(),
      );
      _recentSearches.insert(0, term);
      if (_recentSearches.length > 6) _recentSearches.removeLast();
    });
  }

  void _openPost(CommunityPost post) {
    _rememberSearch(_query);
    if (widget.onPostTap != null) {
      widget.onPostTap!(post);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailView(
          post: post,
          repository: widget.repository,
          currentUser: widget.currentUser ?? widget.repository.currentAuthor,
          onAuthorTap: widget.onAuthorTap,
          onOpenRef: widget.onOpenRef,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;

    final matchedPosts = _query.isEmpty
        ? <CommunityPost>[]
        : widget.repository.searchPosts(_query);
    final matchedUsers = _query.isEmpty
        ? <CommunityAuthor>[]
        : widget.repository.searchUsers(_query);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.arrow_back,
          variant: UiVariant.ghost,
          tooltip: 'Back',
          onPressed: () => widget.onBack != null
              ? widget.onBack!()
              : Navigator.of(context).pop(),
        ),
        title: UiInput.search(
          value: _query,
          hintText: 'Search community, tickers, traders...',
          onChanged: _onSearch,
          onSubmitted: _rememberSearch,
          onClear: () => _onSearch(''),
        ),
      ),
      body: widget.repository.isLoading && widget.repository.forYouPosts.isEmpty
          ? UiSkeleton.search()
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kCommunityMaxWidth),
                child: Column(
                  children: [
                    if (_query.isNotEmpty) ...[
                      Container(
                        color: colors.surface,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(12),
                          vertical: context.sp(8),
                        ),
                        child: UiTabs(
                          tabs: const ['All', 'Posts', 'Traders'],
                          selectedIndex: _selectedCategory,
                          onChanged: (idx) =>
                              setState(() => _selectedCategory = idx),
                        ),
                      ),
                      const UiDivider(),
                    ],

                    Expanded(
                      child: _query.isEmpty
                          ? _buildRecentSearches()
                          : _buildSearchResults(matchedPosts, matchedUsers),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRecentSearches() {
    final theme = context.ui;
    return ListView(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: context.sp(theme.spacing.sm),
          children: [
            Text('Recent Searches', style: context.uiText.subheading),
            if (_recentSearches.isNotEmpty)
              UiButton(
                label: 'Clear all',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                onPressed: () => setState(() => _recentSearches.clear()),
              ),
          ],
        ),
        UiGap.v(theme.spacing.sm),
        if (_recentSearches.isEmpty)
          const UiEmptyState(
            icon: Icons.search,
            title: 'Search your community',
            message:
                'Find posts by keyword, ticker, or trader. Submitted searches appear here during this visit.',
          )
        else
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: [
              for (final term in _recentSearches)
                UiButton(
                  label: term,
                  icon: Icons.history,
                  variant: UiVariant.outline,
                  onPressed: () {
                    _onSearch(term);
                    _rememberSearch(term);
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildSearchResults(
    List<CommunityPost> posts,
    List<CommunityAuthor> traders,
  ) {
    final isEmpty = switch (_selectedCategory) {
      1 => posts.isEmpty,
      2 => traders.isEmpty,
      _ => posts.isEmpty && traders.isEmpty,
    };
    if (isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.search_off,
          title: switch (_selectedCategory) {
            1 => 'No matching posts',
            2 => 'No matching traders',
            _ => 'No results found for "$_query"',
          },
          message:
              'Try checking your spelling or searching for a different keyword or symbol.',
        ),
      );
    }

    if (_selectedCategory == 1) {
      return CommunityFeedList(
        posts: posts,
        onPostTap: _openPost,
        repository: widget.repository,
        currentUser: widget.currentUser ?? widget.repository.currentAuthor,
        onAuthorTap: widget.onAuthorTap,
        onOpenRef: widget.onOpenRef,
      );
    }

    if (_selectedCategory == 2) {
      return ListView.separated(
        padding: EdgeInsets.all(context.sp(16)),
        itemCount: traders.length,
        separatorBuilder: (_, _) => SizedBox(height: context.sp(12)),
        itemBuilder: (ctx, idx) {
          final author = traders[idx];
          return CommunityTraderCard(
            trader: author,
            onTap: () => widget.onAuthorTap?.call(author),
            onFollow: author.id == widget.repository.currentAuthor.id
                ? null
                : () => widget.repository.toggleFollow(author.id),
          );
        },
      );
    }

    // Category 0: All
    final colors = context.ui.colors;
    return ListView(
      children: [
        if (traders.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(16),
              context.sp(16),
              context.sp(16),
              context.sp(8),
            ),
            child: Text(
              'Traders',
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
          ...traders
              .take(2)
              .map(
                (author) => Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(16),
                    vertical: context.sp(4),
                  ),
                  child: CommunityTraderCard(
                    trader: author,
                    onTap: () => widget.onAuthorTap?.call(author),
                    onFollow: author.id == widget.repository.currentAuthor.id
                        ? null
                        : () => widget.repository.toggleFollow(author.id),
                  ),
                ),
              ),
          SizedBox(height: context.sp(12)),
          const UiDivider(),
        ],
        if (posts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.sp(16),
              context.sp(16),
              context.sp(16),
              context.sp(8),
            ),
            child: Text(
              'Posts',
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
          ...posts.map(
            (post) => InkWell(
              onTap: () => _openPost(post),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.sp(16),
                  vertical: context.sp(8),
                ),
                child: UiCard(
                  child: Padding(
                    padding: EdgeInsets.all(context.sp(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            UiAvatar(
                              name: post.author.displayName,
                              size: UiSize.xs,
                            ),
                            SizedBox(width: context.sp(8)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.author.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.uiText.label,
                                  ),
                                  Text(
                                    post.author.displayHandle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.uiText.caption.copyWith(
                                      color: colors.foregroundMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(6)),
                        Text(
                          post.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.body.copyWith(
                            color: colors.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
