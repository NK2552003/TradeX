import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// Private Bookmarks view where saved posts and signals are archived.
class CommunityBookmarksView extends StatefulWidget {
  const CommunityBookmarksView({
    super.key,
    required this.repository,
    required this.currentUser,
    this.onPostTap,
    this.onAuthorTap,
    this.onOpenRef,
  });

  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityPost>? onPostTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<CommunityBookmarksView> createState() => _CommunityBookmarksViewState();
}

class _CommunityBookmarksViewState extends State<CommunityBookmarksView> {
  int _selectedFilter =
      0; // 0: All, 1: Setups, 2: Notes, 3: Journal, 4: Strategies

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final bookmarked = widget.repository.bookmarkedPosts;

    final filtered = bookmarked.where((p) {
      if (_selectedFilter == 1) {
        return p.tradeSetup != null;
      }
      if (_selectedFilter == 2) {
        return p.attachment?.source.title.toLowerCase().contains('note') ??
            false;
      }
      if (_selectedFilter == 3) {
        return p.attachment?.source.title.toLowerCase().contains('journal') ??
            false;
      }
      if (_selectedFilter == 4) {
        return p.attachment?.source.title.toLowerCase().contains('strategy') ??
            false;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.sz(700)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Header Row
          Row(
            children: <Widget>[
              Text(
                'Bookmarks',
                style: context.uiText.title.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colors.foreground,
                ),
              ),
              const Spacer(),
              if (bookmarked.isNotEmpty)
                UiButton(
                  label: 'Clear all',
                  variant: UiVariant.ghost,
                  size: UiSize.sm,
                  expandOnMobile: false,
                  onPressed: () {
                    for (final p in List<CommunityPost>.from(bookmarked)) {
                      widget.repository.toggleBookmark(p.id);
                    }
                    UiToast.show(
                      context,
                      title: 'Bookmarks Cleared',
                      message: 'All bookmarked posts were removed.',
                      intent: UiIntent.info,
                    );
                  },
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Filter tabs
          UiTabs(
            tabs: [
              'All (${bookmarked.length})',
              'Setups',
              'Notes',
              'Journal',
              'Strategies',
            ],
            selectedIndex: _selectedFilter,
            onChanged: (idx) => setState(() => _selectedFilter = idx),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Privacy Callout
          UiCallout(
            title: 'Private Saves',
            message:
                'Bookmarks are private. Only you can view your saved setups and notes.',
            intent: UiIntent.info,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),

          // Empty state or Post List
          if (filtered.isEmpty)
            const CommunityEmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'No bookmarks found',
              message:
                  'Tap the bookmark icon on any trade setup or post to save it here for quick reference.',
            )
          else
            for (final post in filtered)
              Padding(
                padding: EdgeInsets.only(bottom: context.sp(theme.spacing.sm)),
                child: CommunityPostCard(
                  post: post,
                  variant: CommunityPostCardVariant.boxed,
                  repository: widget.repository,
                  onTap: () => widget.onPostTap?.call(post),
                  onLike: () => widget.repository.toggleLike(post.id),
                  onRepost: () => widget.repository.toggleRepost(post.id),
                  onBookmark: () => widget.repository.toggleBookmark(post.id),
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
}
