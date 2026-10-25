import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/linking/link_graph.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/views/community_image_viewer_page.dart';
import 'package:tradex/features/community/presentation/widgets/public_workspace_attachment.dart';
import 'package:tradex/features/community/presentation/widgets/community_author_header.dart';
import 'package:tradex/features/community/presentation/widgets/community_edit_post_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_engagement_bar.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';
import 'package:tradex/features/community/presentation/widgets/community_link_preview_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_poll_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_insights_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_options_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_quote_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_repost_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_share_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/community_trade_setup_tile.dart';

/// Visual presentation variant for [CommunityPostCard].
enum CommunityPostCardVariant {
  /// Flat timeline presentation with hairline separators and Threads-style avatar thread-line.
  feed,

  /// Standalone card container with border and elevation, used in bookmarks, quotes, and explore grid.
  boxed,
}

/// The signature Twitter/Threads-grade post card for TraderHub (TradeX).
///
/// Features a Hybrid layout:
/// - In [CommunityPostCardVariant.feed]: flat timeline with a continuous vertical thread-line
///   down the avatar rail and no boxed card clutter.
/// - In [CommunityPostCardVariant.boxed]: wraps within a [UiCard] for standalone displays.
///
/// Handles inline trade setups, note/journal/strategy attachments, quoted posts,
/// image media, cashtag/hashtag highlighting, and interactive engagement states.
class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.variant = CommunityPostCardVariant.feed,
    this.repository,
    this.onTap,
    this.onReply,
    this.onLike,
    this.onRepost,
    this.onBookmark,
    this.onShare,
    this.onCopySetup,
    this.onAuthorTap,
    this.onTagTap,
    this.onQuote,
    this.onVotePoll,
    this.onOpenRef,
    this.showAuthorHeader = true,
    this.showTradeSetup = true,
    this.showEngagementBar = true,
    this.showTagsAndTickers = true,
    this.loading = false,
    this.currentUser,
  });

  final CommunityPost post;
  final CommunityPostCardVariant variant;
  final dynamic repository;
  final CommunityAuthor? currentUser;
  final VoidCallback? onTap;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onRepost;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onCopySetup;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<CommunityPost>? onQuote;
  final void Function(int optionIndex)? onVotePoll;

  /// Opens the linked Writing-Desk record when the post's attachment tile is
  /// tapped. When null the attachment tile falls back to [onTap].
  final ValueChanged<AppLinkRef>? onOpenRef;

  /// Whether to render the author header (avatar + display name + handle).
  /// Defaults to true. On desktop detail view, this can be hidden when the author profile is shown in the right sidebar.
  final bool showAuthorHeader;

  /// Whether to render the embedded trade setup snippet tile.
  /// Defaults to true. On desktop detail view, this can be hidden when the trade setup blueprint is shown in the right sidebar.
  final bool showTradeSetup;

  /// Whether to render the engagement action bar (likes, reposts, comments, share).
  /// Defaults to true. On desktop detail view, this can be hidden when thread activity & actions are elevated to the companion sidebar.
  final bool showEngagementBar;

  /// Whether to render the cashtag and hashtag badge wrap.
  /// Defaults to true. On desktop detail view, this can be hidden when tags are elevated to the companion sidebar.
  final bool showTagsAndTickers;

  final bool loading;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  late bool _liked;
  late int _likes;
  late bool _reposted;
  late int _reposts;
  late bool _bookmarked;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likes = widget.post.likes;
    _reposted = widget.post.reposted;
    _reposts = widget.post.reposts;
    _bookmarked = widget.post.bookmarked;
  }

  @override
  void didUpdateWidget(CommunityPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.liked != widget.post.liked ||
        oldWidget.post.likes != widget.post.likes) {
      _liked = widget.post.liked;
      _likes = widget.post.likes;
    }
    if (oldWidget.post.reposted != widget.post.reposted ||
        oldWidget.post.reposts != widget.post.reposts) {
      _reposted = widget.post.reposted;
      _reposts = widget.post.reposts;
    }
    if (oldWidget.post.bookmarked != widget.post.bookmarked) {
      _bookmarked = widget.post.bookmarked;
    }
  }

  void _handleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    widget.onLike?.call();
  }

  void _handleRepost() {
    CommunityRepostDialog.show(
      context,
      post: widget.post,
      onRepost: () {
        setState(() {
          _reposted = !_reposted;
          _reposts += _reposted ? 1 : -1;
        });
        widget.onRepost?.call();
      },
      onQuote: () {
        widget.onQuote?.call(widget.post);
      },
    );
  }

  void _handleBookmark() {
    setState(() {
      _bookmarked = !_bookmarked;
    });
    widget.onBookmark?.call();
  }

  void _handleShare(BuildContext context) {
    CommunityShareSheet.show(context, post: widget.post);
    widget.onShare?.call();
  }

  bool get _isAuthor {
    final current =
        widget.currentUser ??
        (widget.repository is CommunityRepository
            ? (widget.repository as CommunityRepository).currentAuthor
            : null);
    if (current == null) return false;
    final author = widget.post.author;
    if (author.id == current.id ||
        author.handle.toLowerCase() == current.handle.toLowerCase()) {
      return true;
    }
    final cleanCurrentHandle = current.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    final cleanAuthorHandle = author.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    if (cleanCurrentHandle.isNotEmpty &&
        cleanCurrentHandle == cleanAuthorHandle) {
      return true;
    }
    return false;
  }

  Future<void> _handleEditPost(BuildContext context) async {
    final repo = widget.repository is CommunityRepository
        ? widget.repository as CommunityRepository
        : CommunityRepository();
    await CommunityEditPostDialog.show(
      context,
      post: widget.post,
      repository: repo,
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// Tickers cleaned and deduplicated against redundant prefixes and duplicates.
  List<String> get _deduplicatedTickers {
    final Set<String> seen = <String>{};
    final List<String> result = <String>[];
    for (final raw in widget.post.tickers) {
      final String clean = raw.trim().replaceFirst(RegExp(r'^\$+'), '');
      if (clean.isEmpty) continue;
      final String key = clean
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      if (seen.add(key)) {
        result.add(clean);
      }
    }
    return result;
  }

  /// Tags deduplicated against tickers and redundant formatting, avoiding duplicacy.
  List<String> get _deduplicatedTags {
    final Set<String> tickerKeys = _deduplicatedTickers
        .map((t) => t.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase())
        .toSet();
    final Set<String> seen = <String>{};
    final List<String> result = <String>[];

    for (final raw in widget.post.tags) {
      final String clean = raw.trim().replaceFirst(RegExp(r'^[#\$]+'), '');
      if (clean.isEmpty) continue;
      final String key = clean
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      // Skip tag if it duplicates an active ticker symbol or was already seen
      if (tickerKeys.contains(key)) continue;
      if (seen.add(key)) {
        result.add(clean);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;

    if (widget.loading) {
      return const CommunityPostCardSkeleton();
    }

    final post = widget.post;

    final bool isDesktop = context.uiRes.isDesktop;

    if (widget.variant == CommunityPostCardVariant.boxed) {
      return UiCard(
        onTap: widget.onTap,
        hoverLift: !isDesktop,
        padding: EdgeInsets.all(
          context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        ),
        child: _buildPostContent(context, theme, showAvatarInHeader: true),
      );
    }

    // Hybrid Feed Timeline Layout
    return InkWell(
      onTap: widget.onTap,
      hoverColor: isDesktop ? Colors.transparent : null,
      splashColor: isDesktop
          ? Colors.transparent
          : theme.colors.primary.withValues(alpha: 0.03),
      highlightColor: isDesktop
          ? Colors.transparent
          : theme.colors.surfaceMuted.withValues(alpha: 0.08),
      overlayColor: isDesktop
          ? const WidgetStatePropertyAll<Color>(Colors.transparent)
          : null,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(
            isMobile ? theme.spacing.sm : theme.spacing.md,
          ),
          vertical: context.sp(theme.spacing.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Repost / Pinned Header Banners
            if (post.repostedBy != null) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(
                  left: context.sp(theme.spacing.xl),
                  bottom: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.repeat_rounded,
                      size: context.sz(14),
                      color: theme.colors.foregroundMuted,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      '${post.repostedBy} reposted',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (post.isPinned) ...<Widget>[
              Padding(
                padding: EdgeInsets.only(
                  left: context.sp(theme.spacing.xl),
                  bottom: context.sp(theme.spacing.xs),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.push_pin_rounded,
                      size: context.sz(13),
                      color: theme.colors.primary,
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      'Pinned Setup',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Main Post with Avatar & Content
            if (widget.showAuthorHeader)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Left: Avatar
                  UiAvatar(
                    name: post.author.displayName,
                    imageUrl: post.author.avatarUrl,
                    size: UiSize.md,
                    verified: post.author.verified,
                    verifiedColor: post.author.verifiedColor(theme),
                    onTap: widget.onAuthorTap == null
                        ? null
                        : () => widget.onAuthorTap!(post.author),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),

                  // Right: Header, Body, Setup, Attachment, Media, Actions
                  Expanded(
                    child: _buildPostContent(
                      context,
                      theme,
                      showAvatarInHeader: false,
                    ),
                  ),
                ],
              )
            else
              // Full-width post content when author header is in desktop sidebar
              _buildPostContent(context, theme, showAvatarInHeader: false),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent(
    BuildContext context,
    UiTheme theme, {
    required bool showAvatarInHeader,
  }) {
    final post = widget.post;
    final List<String> displayTickers = _deduplicatedTickers;
    final List<String> displayTags = _deduplicatedTags;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Official Desk Alert Banner
        if (post.isDeskAlert) ...<Widget>[
          Container(
            margin: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.sm),
              vertical: context.sp(theme.spacing.xs),
            ),
            decoration: BoxDecoration(
              color: theme.colors.danger.withValues(alpha: 0.12),
              borderRadius: context.radius(theme.radii.sm),
              border: Border.all(
                color: theme.colors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.campaign,
                  color: theme.colors.danger,
                  size: context.sz(16),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'OFFICIAL DESK ANNOUNCEMENT',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.danger,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Author Header or Compact Timestamp Strip
        if (widget.showAuthorHeader)
          CommunityAuthorHeader(
            author: post.author,
            createdAt: post.createdAt,
            showAvatar: showAvatarInHeader,
            onAuthorTap: widget.onAuthorTap,
            onShare: () => _handleShare(context),
            onBookmark: _handleBookmark,
            bookmarked: _bookmarked,
            onEdit: _isAuthor ? () => _handleEditPost(context) : null,
            onMoreTap: widget.repository == null
                ? null
                : () {
                    CommunityPostOptionsSheet.show(
                      context,
                      post: post,
                      repository: widget.repository,
                      isAuthor: _isAuthor,
                    );
                  },
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.schedule_rounded,
                    size: context.sz(14),
                    color: theme.colors.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    AppTokens.relativeTime(post.createdAt),
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: context.fs(12),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_isAuthor) ...<Widget>[
                    UiButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      size: UiSize.xs,
                      variant: UiVariant.soft,
                      intent: UiIntent.primary,
                      onPressed: () => _handleEditPost(context),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                  ],
                  if (widget.repository != null)
                    UiIconButton(
                      icon: Icons.more_horiz_rounded,
                      size: UiSize.xs,
                      tooltip: 'More options',
                      onPressed: () {
                        CommunityPostOptionsSheet.show(
                          context,
                          post: post,
                          repository: widget.repository,
                          isAuthor: _isAuthor,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ],

        // Sentiment badge & edited note
        if (post.sentiment != null || post.isEdited) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: [
              if (post.sentiment != null)
                UiBadge(
                  label: post.sentiment == CommunitySentiment.bullish
                      ? 'BULLISH'
                      : post.sentiment == CommunitySentiment.bearish
                      ? 'BEARISH'
                      : 'NEUTRAL',
                  intent: post.sentiment == CommunitySentiment.bullish
                      ? UiIntent.success
                      : post.sentiment == CommunitySentiment.bearish
                      ? UiIntent.danger
                      : UiIntent.info,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              if (post.isEdited) ...[
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'Edited',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontStyle: FontStyle.italic,
                    fontSize: context.fs(11),
                  ),
                ),
              ],
            ],
          ),
        ],

        // Body Text
        if (post.body.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          CommunityHighlightedText(text: post.body, onTagTap: widget.onTagTap),
        ],

        // Embedded Trade Setup Snippet (if any and if showTradeSetup is true)
        if (widget.showTradeSetup && post.tradeSetup != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          CommunityTradeSetupTile(
            setup: post.tradeSetup!,
            onTap: widget.onTap,
            onLogToJournal: widget.onCopySetup,
          ),
        ],

        // Attached Workspace Record (Note, Trade, Strategy)
        if (post.attachment != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          PublicWorkspaceAttachment(
            attachment: post.attachment!,
            onTap: widget.onOpenRef != null
                ? () => widget.onOpenRef!(
                    post.attachment!.source.copyWith(isPublicContext: true),
                  )
                : widget.onTap,
          ),
        ],

        // Embedded Link Preview Card (if any)
        if (post.linkPreview != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          CommunityLinkPreviewTile(
            preview: post.linkPreview!,
            onTap: () {
              final String rawUrl =
                  post.linkPreview!.domain.startsWith('http')
                  ? post.linkPreview!.domain
                  : 'https://${post.linkPreview!.domain}';
              final AppLinkRef? deepTarget = AppDeepLink.tryParseUrl(rawUrl);
              if (deepTarget != null && widget.onOpenRef != null) {
                widget.onOpenRef!(deepTarget.copyWith(isPublicContext: true));
                return;
              }
              Clipboard.setData(ClipboardData(text: rawUrl));
              UiToast.info(
                context,
                title: post.linkPreview!.title,
                message: 'External link copied: $rawUrl',
              );
            },
          ),
        ],

        // Embedded Poll (if any)
        if (post.poll != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          CommunityPollTile(
            poll: post.poll!,
            onVote: (idx) {
              widget.onVotePoll?.call(idx);
              widget.repository?.votePoll(post.id, idx);
            },
          ),
        ],

        // Attached Image Media
        if (post.imageUrls.isNotEmpty) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          ClipRRect(
            borderRadius: context.radius(theme.radii.md),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  CommunityImageViewerPage.open(
                    context,
                    imageUrls: post.imageUrls,
                  );
                },
                child: UiRemoteImage(
                  url: post.imageUrls.first,
                  semanticLabel: 'Post media by @${post.author.handle}',
                ),
              ),
            ),
          ),
        ] else if (post.imageUrl != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          ClipRRect(
            borderRadius: context.radius(theme.radii.md),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: GestureDetector(
                onTap: () {
                  CommunityImageViewerPage.open(
                    context,
                    imageUrls: [post.imageUrl!],
                  );
                },
                child: UiRemoteImage(
                  url: post.imageUrl!,
                  semanticLabel: 'Post attachment by @${post.author.handle}',
                ),
              ),
            ),
          ),
        ],

        // Quoted Post (if any)
        if (post.quoted != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          if (widget.repository is CommunityRepository)
            ListenableBuilder(
              listenable: widget.repository as CommunityRepository,
              builder: (context, _) {
                final original = (widget.repository as CommunityRepository)
                    .loadPostById(post.quoted!.id);
                if (original == null || !original.isPublic) {
                  return const UiEmptyState(
                    title: 'Original post unavailable',
                    message:
                        'The original post is private or has been removed.',
                  );
                }
                return CommunityQuoteCard(
                  post: original,
                  onAuthorTap: widget.onAuthorTap,
                  onOpenRef: widget.onOpenRef,
                  onTagTap: widget.onTagTap,
                  onTap: widget.onOpenRef != null
                      ? () => widget.onOpenRef!(
                          AppLinkRef(
                            kind: AppLinkKind.communityPost,
                            id: original.id,
                            title: 'Post by @${original.author.handle}',
                            isPublicContext: true,
                          ),
                        )
                      : widget.onTap,
                );
              },
            )
          else
            const UiEmptyState(
              title: 'Original post unavailable',
              message: 'The original post could not be verified.',
            ),
        ],

        // Ticker Badges & Hashtags (Cleaned & Deduplicated)
        if (widget.showTagsAndTickers &&
            (displayTickers.isNotEmpty || displayTags.isNotEmpty)) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final ticker in displayTickers)
                UiBadge(
                  label: '\$$ticker',
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                  onTap: widget.onTagTap == null
                      ? null
                      : () => widget.onTagTap!('\$$ticker'),
                ),
              for (final tag in displayTags)
                UiBadge(
                  label: '#$tag',
                  intent: UiIntent.info,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                  onTap: widget.onTagTap == null
                      ? null
                      : () => widget.onTagTap!('#$tag'),
                ),
            ],
          ),
        ],

        // Engagement Action Bar
        if (widget.showEngagementBar) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          CommunityEngagementBar(
            comments: post.comments,
            reposts: _reposts,
            likes: _likes,
            views: post.views,
            liked: _liked,
            reposted: _reposted,
            bookmarked: _bookmarked,
            onReply: widget.onReply ?? widget.onTap,
            onRepost: _handleRepost,
            onLike: _handleLike,
            onBookmark: _handleBookmark,
            onShare: () => _handleShare(context),
            onViewStats: () =>
                CommunityPostInsightsSheet.show(context, post: post),
            showBorder: true,
          ),
        ],
      ],
    );
  }
}

/// Shimmer loading placeholder skeleton for [CommunityPostCard].
class CommunityPostCardSkeleton extends StatelessWidget {
  const CommunityPostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiCard(
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              UiSkeleton(width: context.sz(40), height: context.sz(40)),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  UiSkeleton(width: context.sz(120), height: context.sz(14)),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  UiSkeleton(width: context.sz(80), height: context.sz(12)),
                ],
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(width: double.infinity, height: context.sz(14)),
          SizedBox(height: context.sp(theme.spacing.xs)),
          UiSkeleton(width: context.sz(240), height: context.sz(14)),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSkeleton(width: double.infinity, height: context.sz(90)),
        ],
      ),
    );
  }
}
