import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_post_detail_view.dart';
import 'package:tradex/features/community/presentation/widgets/community_feed_list.dart';
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
  });

  final CommunityRepository repository;
  final String initialQuery;
  final CommunityAuthor? currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onHashtagTap;
  final VoidCallback? onBack;

  @override
  State<CommunitySearchPage> createState() => _CommunitySearchPageState();
}

class _CommunitySearchPageState extends State<CommunitySearchPage> {
  late final TextEditingController _controller;
  String _query = '';
  int _selectedCategory = 0; // 0: All, 1: Posts, 2: Traders, 3: Tickers
  final List<String> _recentSearches = ['NIFTY', 'BANKNIFTY', 'Crypto Breakouts', 'Options Scalp'];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _controller = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String val) {
    setState(() {
      _query = val;
      if (val.isNotEmpty && !_recentSearches.contains(val)) {
        _recentSearches.insert(0, val);
        if (_recentSearches.length > 6) _recentSearches.removeLast();
      }
    });
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
          onPressed: () => widget.onBack != null ? widget.onBack!() : Navigator.of(context).pop(),
        ),
        title: UiInput.search(
          value: _query,
          hintText: 'Search community, tickers, traders...',
          onChanged: _onSearch,
          onClear: () {
            _controller.clear();
            setState(() => _query = '');
          },
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            children: [
              if (_query.isNotEmpty) ...[
                Container(
                  color: colors.surface,
                  padding: EdgeInsets.symmetric(horizontal: context.sp(12), vertical: context.sp(8)),
                  child: UiTabs(
                    tabs: const ['All', 'Posts', 'Traders'],
                    selectedIndex: _selectedCategory,
                    onChanged: (idx) => setState(() => _selectedCategory = idx),
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
    final colors = context.ui.colors;
    return ListView(
      padding: EdgeInsets.all(context.sp(16)),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Searches',
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
            UiButton(
              label: 'Clear all',
              variant: UiVariant.ghost,
              size: UiSize.sm,
              onPressed: () => setState(() => _recentSearches.clear()),
            ),
          ],
        ),
        SizedBox(height: context.sp(12)),
        Wrap(
          spacing: context.sp(8),
          runSpacing: context.sp(8),
          children: _recentSearches.map((term) {
            return InkWell(
              onTap: () {
                _controller.text = term;
                _onSearch(term);
              },
              borderRadius: BorderRadius.circular(context.sz(20)),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: context.sp(12), vertical: context.sp(8)),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(context.sz(20)),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: context.sz(14), color: colors.foregroundMuted),
                    SizedBox(width: context.sp(6)),
                    Text(
                      term,
                      style: context.uiText.caption.copyWith(color: colors.foreground),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: context.sp(28)),
        Text(
          'Trending Topics Today',
          style: context.uiText.subheading.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.foreground,
          ),
        ),
        SizedBox(height: context.sp(12)),
        ...['#NIFTY50', '#Budget2026', '#CryptoRally', '#OptionsOI'].map((tag) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.trending_up, color: colors.primary, size: context.sz(20)),
            title: Text(tag, style: context.uiText.body.copyWith(fontWeight: FontWeight.w600, color: colors.foreground)),
            subtitle: Text('Over 1,200 traders discussing', style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
            onTap: () {
              _controller.text = tag;
              _onSearch(tag);
            },
          );
        }),
      ],
    );
  }

  Widget _buildSearchResults(List<CommunityPost> posts, List<CommunityAuthor> traders) {
    if (posts.isEmpty && traders.isEmpty) {
      return Center(
        child: UiEmptyState(
          icon: Icons.search_off,
          title: 'No results found for "$_query"',
          message: 'Try checking your spelling or searching for a different keyword or symbol.',
        ),
      );
    }

    if (_selectedCategory == 1) {
      return CommunityFeedList(
        posts: posts,
        onPostTap: (post) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CommunityPostDetailView(
                post: post,
                repository: widget.repository,
                currentUser: widget.repository.currentAuthor,
              ),
            ),
          );
        },
        onAuthorTap: widget.onAuthorTap,
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
            onFollow: () => widget.repository.toggleFollow(author.id),
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
            padding: EdgeInsets.fromLTRB(context.sp(16), context.sp(16), context.sp(16), context.sp(8)),
            child: Text(
              'Traders',
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
          ...traders.take(2).map((author) => Padding(
                padding: EdgeInsets.symmetric(horizontal: context.sp(16), vertical: context.sp(4)),
                child: CommunityTraderCard(
                  trader: author,
                  onTap: () => widget.onAuthorTap?.call(author),
                  onFollow: () => widget.repository.toggleFollow(author.id),
                ),
              )),
          SizedBox(height: context.sp(12)),
          const UiDivider(),
        ],
        if (posts.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(context.sp(16), context.sp(16), context.sp(16), context.sp(8)),
            child: Text(
              'Posts',
              style: context.uiText.subheading.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.foreground,
              ),
            ),
          ),
          ...posts.map((post) => InkWell(
                onTap: () {
                  if (widget.onPostTap != null) {
                    widget.onPostTap!(post);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CommunityPostDetailView(
                          post: post,
                          repository: widget.repository,
                          currentUser: widget.currentUser ?? widget.repository.currentAuthor,
                        ),
                      ),
                    );
                  }
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.sp(16), vertical: context.sp(8)),
                  child: UiCard(
                    child: Padding(
                      padding: EdgeInsets.all(context.sp(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UiAvatar(name: post.author.displayName, size: UiSize.xs),
                              SizedBox(width: context.sp(8)),
                              Text(post.author.displayName, style: context.uiText.label.copyWith(fontWeight: FontWeight.w600, color: colors.foreground)),
                              SizedBox(width: context.sp(4)),
                              Text(post.author.handle, style: context.uiText.caption.copyWith(color: colors.foregroundMuted)),
                            ],
                          ),
                          SizedBox(height: context.sp(6)),
                          Text(
                            post.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.body.copyWith(color: colors.foreground),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ],
    );
  }
}
