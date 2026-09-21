import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/presentation/widgets/community_ai_assistant_dialog.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_attachment_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';
import 'package:tradex/features/community/presentation/widgets/community_poll_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_quote_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_repost_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_share_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';

// ---------------------------------------------------------------------------
// CommunityPostDetailView
// ---------------------------------------------------------------------------

/// Detailed thread view with responsive multi-device layouts.
///
/// Layout Strategy:
/// - Desktop: 2-column architecture (left: main setup & LinkedIn comments thread;
///   right: sticky author analytics sidebar with win-rate stats, recent setups, and one-click copy).
/// - Tablet: Adaptive stacked layout with interactive author stat card.
/// - Mobile: Full-width feed-centric layout with sticky bottom quick reply bar.
class CommunityPostDetailView extends StatefulWidget {
  const CommunityPostDetailView({
    super.key,
    required this.post,
    required this.repository,
    required this.currentUser,
    this.onAuthorTap,
    this.onBack,
    this.onOpenRef,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onBack;
  final ValueChanged<AppLinkRef>? onOpenRef;

  @override
  State<CommunityPostDetailView> createState() =>
      _CommunityPostDetailViewState();
}

class _CommunityPostDetailViewState extends State<CommunityPostDetailView> {
  late bool _liked;
  late int _likes;
  late bool _reposted;
  late int _reposts;
  late bool _bookmarked;
  late bool _isAuthorFollowed;
  int _bullishVotes = 42;
  int _bearishVotes = 6;
  bool _hasVotedSentiment = false;

  final TextEditingController _mobileQuickReplyCtrl = TextEditingController();
  bool _mobileSubmitting = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.liked;
    _likes = widget.post.likes;
    _reposted = widget.post.reposted;
    _reposts = widget.post.reposts;
    _bookmarked = widget.post.bookmarked;
    _isAuthorFollowed = widget.post.author.isFollowing;
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _mobileQuickReplyCtrl.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() => setState(() {});

  void _handleLike() {
    setState(() {
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    widget.repository.toggleLike(widget.post.id);
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
        widget.repository.toggleRepost(widget.post.id);
      },
      onQuote: () {},
    );
  }

  void _handleBookmark() {
    setState(() {
      _bookmarked = !_bookmarked;
    });
    widget.repository.toggleBookmark(widget.post.id);
    UiToast.show(
      context,
      title: _bookmarked ? 'Bookmark Added' : 'Bookmark Removed',
      message: _bookmarked
          ? 'Post saved to your bookmarks library.'
          : 'Removed from bookmarks.',
      intent: _bookmarked ? UiIntent.primary : UiIntent.neutral,
    );
  }

  void _handleShare() {
    CommunityShareSheet.show(context, post: widget.post);
  }

  Future<void> _handleMobileQuickReply() async {
    final text = _mobileQuickReplyCtrl.text.trim();
    if (text.isEmpty || _mobileSubmitting) return;

    setState(() => _mobileSubmitting = true);
    try {
      widget.repository.addComment(
        widget.post.id,
        text,
        author: widget.currentUser,
      );
      _mobileQuickReplyCtrl.clear();
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Reply Sent',
        message: 'Your reply was added to the thread.',
        intent: UiIntent.success,
      );
    } finally {
      if (mounted) setState(() => _mobileSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isDesktop = context.uiRes.isDesktop;
    final isMobile = context.uiRes.isMobile;
    final author = widget.post.author;
    final comments = widget.repository.commentsForPost(widget.post.id);

    return Scaffold(
      backgroundColor: theme.colors.background,
      bottomNavigationBar: isMobile
          ? _buildMobileStickyReplyBar(theme)
          : null,
      body: SafeArea(
        bottom: false,
        child: isDesktop
            ? _buildDesktopLayout(theme, author, comments)
            : _buildStandardLayout(theme, isMobile, author, comments),
      ),
    );
  }

  /// Floating pill header with frosted glass, hairline border, soft glow,
  /// back button, ticker pill, and thread action buttons.
  Widget _buildFloatingHeader(
    BuildContext context,
    UiTheme theme, {
    required bool isMobile,
  }) {
    final ticker = widget.post.tradeSetup?.ticker ??
        (widget.post.tickers.isNotEmpty ? widget.post.tickers.first : null);

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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
                UiIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: UiSize.xs,
                  tooltip: 'Back to Feed',
                  onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Container(
                  height: context.sz(18),
                  width: theme.borders.hairline,
                  color: theme.colors.border.withValues(alpha: 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                Text(
                  'Post Thread',
                  style: context.uiText.bodyStrong.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(isMobile ? 13 : 14),
                    color: theme.colors.foreground,
                  ),
                ),
                if (ticker != null) ...[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiBadge(
                    label: ticker,
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.solid,
                    size: UiSize.xs,
                  ),
                ],
                if (widget.post.tradeSetup?.side != null) ...[
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  UiBadge(
                    label: widget.post.tradeSetup!.side,
                    intent: widget.post.tradeSetup!.isBullish
                        ? UiIntent.success
                        : UiIntent.danger,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                ],
                const Spacer(),
                UiIconButton(
                  icon: _bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: UiSize.xs,
                  tooltip: _bookmarked ? 'Remove Bookmark' : 'Save Thread',
                  onPressed: _handleBookmark,
                ),
                UiIconButton(
                  icon: Icons.link_rounded,
                  size: UiSize.xs,
                  tooltip: 'Copy Thread Link',
                  onPressed: () {
                    UiToast.show(
                      context,
                      title: 'Link Copied',
                      message: 'Thread URL copied to clipboard.',
                      intent: UiIntent.success,
                    );
                  },
                ),
                UiIconButton(
                  icon: Icons.ios_share_rounded,
                  size: UiSize.xs,
                  tooltip: 'Share Thread',
                  onPressed: _handleShare,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop 2-Column Responsive Layout: Left Floating Header, Right Sticky Sidebar
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout(
    UiTheme theme,
    CommunityAuthor author,
    List<CommunityComment> comments,
  ) {
    final double clearance =
        context.sz(44) + context.sp(theme.spacing.md) + context.sp(theme.spacing.xs);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Left Column: Main Post Card + LinkedIn Comments Thread with Floating Bar
        Expanded(
          flex: 7,
          child: Stack(
            children: <Widget>[
              SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  context.sp(theme.spacing.lg),
                  clearance,
                  context.sp(theme.spacing.lg),
                  context.sp(theme.spacing.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildMainPostCard(theme, author, isMobile: false),
                    SizedBox(height: context.sp(theme.spacing.lg)),
                    UniversalCommentsSection(
                      targetId: widget.post.id,
                      targetType: 'post',
                      comments: comments,
                      currentUser: widget.currentUser,
                      onAuthorTap: widget.onAuthorTap,
                      onAddComment: (text, {parentCommentId, sentiment}) async {
                        widget.repository.addComment(
                          widget.post.id,
                          text,
                          author: widget.currentUser,
                          parentId: parentCommentId,
                        );
                      },
                      onLikeComment: (commentId, {reaction}) {
                        widget.repository.likeComment(widget.post.id, commentId);
                      },
                    ),
                  ],
                ),
              ),

              // Floating Header Pinned at Top of Left Section
              Positioned(
                top: context.sp(theme.spacing.xs),
                left: context.sp(theme.spacing.lg),
                right: context.sp(theme.spacing.lg),
                child: _buildFloatingHeader(context, theme, isMobile: false),
              ),
            ],
          ),
        ),

        // Right Column: Sticky Author Analytics & Setup Actions (stays pinned on screen)
        SizedBox(
          width: context.sz(350),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: theme.colors.border.withValues(alpha: 0.5),
                  width: theme.borders.hairline,
                ),
              ),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                context.sp(theme.spacing.md),
                context.sp(theme.spacing.xs),
                context.sp(theme.spacing.md),
                context.sp(theme.spacing.xl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildAuthorAnalyticsCard(theme, author),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  _buildAuthorRecentSetupsCard(theme, author),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  _buildRiskComplianceCard(theme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tablet / Mobile Standard Layout with Floating Header
  // ---------------------------------------------------------------------------

  Widget _buildStandardLayout(
    UiTheme theme,
    bool isMobile,
    CommunityAuthor author,
    List<CommunityComment> comments,
  ) {
    final double clearance =
        context.sz(44) + context.sp(theme.spacing.sm) + context.sp(theme.spacing.xs);

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            clearance,
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(isMobile ? 80 : theme.spacing.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildMainPostCard(theme, author, isMobile: isMobile),
              SizedBox(height: context.sp(theme.spacing.md)),
              if (!isMobile) ...[
                _buildAuthorAnalyticsCard(theme, author),
                SizedBox(height: context.sp(theme.spacing.md)),
              ],
              UniversalCommentsSection(
                targetId: widget.post.id,
                targetType: 'post',
                comments: comments,
                currentUser: widget.currentUser,
                onAuthorTap: widget.onAuthorTap,
                onAddComment: (text, {parentCommentId, sentiment}) async {
                  widget.repository.addComment(
                    widget.post.id,
                    text,
                    author: widget.currentUser,
                    parentId: parentCommentId,
                  );
                },
                onLikeComment: (commentId, {reaction}) {
                  widget.repository.likeComment(widget.post.id, commentId);
                },
              ),
            ],
          ),
        ),

        // Floating Header Pinned at Top
        Positioned(
          top: context.sp(theme.spacing.xs),
          left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
          child: _buildFloatingHeader(context, theme, isMobile: isMobile),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Main Post Card (Enriched Trader-Grade Post View)
  // ---------------------------------------------------------------------------

  Widget _buildMainPostCard(UiTheme theme, CommunityAuthor author, {required bool isMobile}) {
    final verifiedColor = author.verifiedColor(theme);

    return UiCard(
      padding: EdgeInsets.all(context.sp(isMobile ? theme.spacing.sm : theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Author Header Row with Follow Action
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: isMobile ? UiSize.md : UiSize.lg,
                verified: author.verified,
                verifiedColor: verifiedColor,
                onTap: widget.onAuthorTap == null ? null : () => widget.onAuthorTap!(author),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.bodyStrong.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: context.fs(isMobile ? 14 : 16),
                              color: theme.colors.foreground,
                            ),
                          ),
                        ),
                        if (author.verified) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Icon(
                            Icons.verified_rounded,
                            color: verifiedColor,
                            size: context.sz(16),
                          ),
                        ],
                        if (author.userRole != UserRole.customer) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          UiBadge(
                            label: author.roleBadgeText,
                            intent: author.userRole == UserRole.userAdmin
                                ? UiIntent.danger
                                : UiIntent.warning,
                            variant: UiBadgeVariant.solid,
                            size: UiSize.xs,
                          ),
                        ],
                        if (author.winRate != null) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          UiBadge(
                            label: '${author.winRate!.toStringAsFixed(0)}% Win',
                            intent: author.winRate! >= 60 ? UiIntent.success : UiIntent.neutral,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '@${author.handle}',
                          style: context.uiText.caption.copyWith(
                            color: theme.colors.foregroundMuted,
                          ),
                        ),
                        if (author.tradingStyle != null) ...[
                          Text(
                            ' · ',
                            style: context.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              author.tradingStyle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              UiIconButton(
                icon: _isAuthorFollowed
                    ? Icons.check_rounded
                    : Icons.person_add_rounded,
                variant: _isAuthorFollowed
                    ? UiVariant.outline
                    : UiVariant.primary,
                size: UiSize.sm,
                tooltip: _isAuthorFollowed
                    ? 'Following @${author.handle}'
                    : 'Follow @${author.handle}',
                onPressed: () {
                  setState(() => _isAuthorFollowed = !_isAuthorFollowed);
                  widget.repository.toggleFollow(author.id);
                  UiToast.show(
                    context,
                    title: _isAuthorFollowed
                        ? 'Following @${author.handle}'
                        : 'Unfollowed @${author.handle}',
                    message: _isAuthorFollowed
                        ? 'Their setups will now appear in your Following feed.'
                        : 'Removed from following list.',
                    intent: _isAuthorFollowed ? UiIntent.success : UiIntent.neutral,
                  );
                },
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              UiIconButton(
                icon: Icons.ios_share_rounded,
                size: UiSize.xs,
                tooltip: 'Share',
                onPressed: _handleShare,
              ),
            ],
          ),

          // Market Context & Setup Conviction Strip
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xxs),
            children: [
              if (widget.post.sentiment != null)
                UiBadge(
                  label: '${widget.post.sentiment!.label} Bias',
                  icon: widget.post.sentiment!.icon,
                  intent: widget.post.sentiment == CommunitySentiment.bullish
                      ? UiIntent.success
                      : widget.post.sentiment == CommunitySentiment.bearish
                          ? UiIntent.danger
                          : UiIntent.neutral,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                )
              else if (widget.post.tradeSetup != null)
                UiBadge(
                  label: widget.post.tradeSetup!.isBullish
                      ? 'Bullish Setup'
                      : 'Bearish Setup',
                  icon: widget.post.tradeSetup!.isBullish
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  intent: widget.post.tradeSetup!.isBullish
                      ? UiIntent.success
                      : UiIntent.danger,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              if (author.winRate != null && author.winRate! >= 60)
                UiBadge(
                  label: 'High Conviction',
                  icon: Icons.verified_user_rounded,
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
              if (widget.post.isPinned)
                UiBadge(
                  label: 'Pinned Thread',
                  icon: Icons.push_pin_rounded,
                  intent: UiIntent.warning,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              UiBadge(
                label: 'Verified Setup Hash',
                icon: Icons.shield_outlined,
                intent: UiIntent.neutral,
                variant: UiBadgeVariant.outline,
                size: UiSize.xs,
              ),
            ],
          ),

          // Large Body Text
          SizedBox(height: context.sp(theme.spacing.md)),
          CommunityHighlightedText(
            text: widget.post.body,
            style: context.uiText.body.copyWith(
              fontSize: context.fs(isMobile ? 15 : 17),
              height: 1.5,
              color: theme.colors.foreground,
            ),
          ),

          // Attached Post Media / Technical Chart Screenshot
          if (widget.post.imageUrls.isNotEmpty || widget.post.imageUrl != null) ...[
            SizedBox(height: context.sp(theme.spacing.md)),
            _buildPostImages(context, theme),
          ],

          // Trade Setup Card (with live R:R, progress, and Candlestick Chart)
          if (widget.post.tradeSetup != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            _buildTradeSetupCard(theme, widget.post.tradeSetup!, isMobile: isMobile),
          ],

          // Attached Workspace Record (Note, Journal, Strategy)
          if (widget.post.attachment != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            CommunityAttachmentTile(
              attachment: widget.post.attachment!,
              dense: isMobile,
              onTap: widget.onOpenRef == null
                  ? null
                  : () => widget.onOpenRef!(widget.post.attachment!.source),
            ),
          ],

          // Quoted Post
          if (widget.post.quoted != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            CommunityQuoteCard(post: widget.post.quoted!),
          ],

          // Poll
          if (widget.post.poll != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            CommunityPollTile(
              poll: widget.post.poll!,
              onVote: (idx) => widget.repository.votePoll(widget.post.id, idx),
            ),
          ],

          // Interactive Community Sentiment Consensus Poll Strip
          SizedBox(height: context.sp(theme.spacing.md)),
          _buildCommunityConsensusCard(theme),

          // Tickers & Hashtags Badges
          if (widget.post.tickers.isNotEmpty || widget.post.tags.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final t in widget.post.tickers)
                  UiBadge(
                    label: '\$$t',
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                for (final tag in widget.post.tags)
                  UiBadge(
                    label: '#$tag',
                    intent: UiIntent.info,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
              ],
            ),
          ],

          // Timestamp & Reach Info
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(
            '${_formatTimestamp(widget.post.createdAt)} · ${uiCompactNumber(widget.post.views)} Views · ${uiCompactNumber(_likes)} Likes · ${uiCompactNumber(_reposts)} Reposts · TradeX Verified Thread',
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
              fontSize: context.fs(12),
            ),
          ),

          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // High-Visibility Engagement Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _engagementAction(
                context,
                icon: Icons.repeat_rounded,
                label: uiCompactNumber(_reposts),
                active: _reposted,
                activeColor: theme.colors.primary,
                tooltip: 'Repost setup',
                onTap: _handleRepost,
              ),
              _engagementAction(
                context,
                icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                label: uiCompactNumber(_likes),
                active: _liked,
                activeColor: theme.colors.danger,
                tooltip: 'Like setup',
                onTap: _handleLike,
              ),
              _engagementAction(
                context,
                icon: _bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: 'Save',
                active: _bookmarked,
                activeColor: theme.colors.warning,
                tooltip: 'Bookmark',
                onTap: _handleBookmark,
              ),
              _engagementAction(
                context,
                icon: Icons.link_rounded,
                label: 'Copy Link',
                active: false,
                activeColor: theme.colors.foreground,
                tooltip: 'Copy link',
                onTap: () {
                  UiToast.show(
                    context,
                    title: 'Link Copied',
                    message: 'Thread URL copied to clipboard.',
                    intent: UiIntent.success,
                  );
                },
              ),
              _engagementAction(
                context,
                icon: Icons.ios_share_rounded,
                label: 'Share',
                active: false,
                activeColor: theme.colors.foreground,
                tooltip: 'Share post',
                onTap: _handleShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Community Consensus Voting Card displaying live trader sentiment split
  Widget _buildCommunityConsensusCard(UiTheme theme) {
    final int total = _bullishVotes + _bearishVotes;
    final double bullishPct = total == 0 ? 50.0 : (_bullishVotes / total) * 100.0;

    return UiCard(
      variant: UiCardVariant.surface,
      accentColor: theme.colors.primary,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote_rounded,
                    size: context.sz(14),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    'Community Consensus',
                    style: context.uiText.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colors.foreground,
                    ),
                  ),
                ],
              ),
              Text(
                '${bullishPct.toStringAsFixed(0)}% Bullish ($total votes)',
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundSubtle,
                  fontSize: context.fs(11),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          ClipRRect(
            borderRadius: context.radius(theme.radii.pill),
            child: SizedBox(
              height: context.sz(6),
              child: Row(
                children: [
                  Expanded(
                    flex: _bullishVotes,
                    child: Container(color: theme.colors.bullish),
                  ),
                  Expanded(
                    flex: _bearishVotes,
                    child: Container(color: theme.colors.bearish),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          Row(
            children: [
              UiButton(
                label: 'Agree (Bullish)',
                leadingIcon: Icons.thumb_up_alt_rounded,
                variant: UiVariant.ghost,
                intent: UiIntent.success,
                size: UiSize.xs,
                onPressed: () {
                  if (_hasVotedSentiment) return;
                  setState(() {
                    _bullishVotes++;
                    _hasVotedSentiment = true;
                  });
                  UiToast.show(
                    context,
                    title: 'Vote Recorded',
                    message: 'You voted Bullish on this trade thesis.',
                    intent: UiIntent.success,
                  );
                },
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiButton(
                label: 'Disagree (Bearish)',
                leadingIcon: Icons.thumb_down_alt_rounded,
                variant: UiVariant.ghost,
                intent: UiIntent.danger,
                size: UiSize.xs,
                onPressed: () {
                  if (_hasVotedSentiment) return;
                  setState(() {
                    _bearishVotes++;
                    _hasVotedSentiment = true;
                  });
                  UiToast.show(
                    context,
                    title: 'Vote Recorded',
                    message: 'You voted Bearish on this trade thesis.',
                    intent: UiIntent.neutral,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Technical chart screenshot or attachment preview
  Widget _buildPostImages(BuildContext context, UiTheme theme) {
    final images = widget.post.imageUrls.isNotEmpty
        ? widget.post.imageUrls
        : [widget.post.imageUrl!];

    return ClipRRect(
      borderRadius: context.radius(theme.radii.md),
      child: Container(
        constraints: BoxConstraints(maxHeight: context.sz(300)),
        width: double.infinity,
        color: theme.colors.surface,
        child: Image.network(
          images.first,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, trace) => Container(
            height: context.sz(140),
            color: theme.colors.surface,
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.candlestick_chart_rounded,
                  color: theme.colors.primary,
                  size: context.sz(20),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  'TradingView Chart Screenshot Attached',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _engagementAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = context.ui;
    return InkWell(
      onTap: onTap,
      borderRadius: context.radius(theme.radii.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.sp(theme.spacing.sm),
          vertical: context.sp(theme.spacing.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sz(18),
              color: active ? activeColor : theme.colors.foregroundMuted,
            ),
            SizedBox(width: context.sp(theme.spacing.xxs)),
            Text(
              label,
              style: context.uiText.caption.copyWith(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? activeColor : theme.colors.foregroundMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Trade Setup Card (Enhanced with Live Computed R:R & AI Analyzer Shortcut)
  // ---------------------------------------------------------------------------

  Widget _buildTradeSetupCard(
    UiTheme theme,
    CommunityTradeSetup setup, {
    required bool isMobile,
  }) {
    final rrRatio = _computeRiskReward(setup);

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Ticker + Side + R:R + PnL
          // Header: Ticker + Side + R:R + Status + PnL (Responsive Wrap)
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.candlestick_chart_rounded,
                    size: context.sz(20),
                    color: theme.colors.primary,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Text(
                    setup.ticker,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.fs(16),
                      color: theme.colors.foreground,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  UiBadge(
                    label: setup.side,
                    intent: setup.isBullish ? UiIntent.success : UiIntent.danger,
                    variant: UiBadgeVariant.solid,
                    size: UiSize.xs,
                  ),
                  if (rrRatio != null) ...[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    UiBadge(
                      label: rrRatio,
                      intent: UiIntent.primary,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                  ],
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  UiBadge(
                    label: 'Active Setup In Play',
                    intent: UiIntent.success,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
                  if (setup.pnl != null) ...[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Text(
                      setup.pnl!,
                      style: context.uiText.numeric.copyWith(
                        color: (setup.isWin ?? true)
                            ? theme.colors.bullish
                            : theme.colors.bearish,
                        fontWeight: FontWeight.w800,
                        fontSize: context.fs(15),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          SizedBox(height: context.sp(theme.spacing.sm)),

          // Trade Metrics (2x2 on mobile, 4-column on tablet/desktop)
          if (isMobile) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(child: _metricBox(context, 'Entry', setup.entry)),
                if (setup.exit != null) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(child: _metricBox(context, 'Exit', setup.exit!)),
                ] else if (setup.target != null) ...<Widget>[
                  SizedBox(width: context.sp(theme.spacing.xs)),
                  Expanded(child: _metricBox(context, 'Target', setup.target!)),
                ],
              ],
            ),
            if (setup.stopLoss != null || (setup.exit != null && setup.target != null)) ...<Widget>[
              SizedBox(height: context.sp(theme.spacing.xs)),
              Row(
                children: <Widget>[
                  if (setup.stopLoss != null)
                    Expanded(child: _metricBox(context, 'Stop Loss', setup.stopLoss!)),
                  if (setup.exit != null && setup.target != null) ...<Widget>[
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    Expanded(child: _metricBox(context, 'Target', setup.target!)),
                  ],
                ],
              ),
            ],
          ] else
            Row(
              children: <Widget>[
                Expanded(child: _metricBox(context, 'Entry', setup.entry)),
                if (setup.exit != null)
                  Expanded(child: _metricBox(context, 'Exit', setup.exit!)),
                if (setup.stopLoss != null)
                  Expanded(child: _metricBox(context, 'Stop Loss', setup.stopLoss!)),
                if (setup.target != null)
                  Expanded(child: _metricBox(context, 'Target', setup.target!)),
              ],
            ),

          // Candlestick chart
          if (setup.candles.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.md)),
            UiCandleChart(
              candles: setup.candles,
              height: isMobile ? 140 : 200,
              showVolume: true,
              showGrid: true,
              interactive: true,
            ),
          ],

          SizedBox(height: context.sp(theme.spacing.md)),

          // Action Toolbar: Journal Copy, AI Vision Analyzer, Chart
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            runSpacing: context.sp(theme.spacing.xs),
            children: [
              UiButton(
                label: 'Copy Setup to Journal',
                leadingIcon: Icons.bookmark_add_outlined,
                variant: UiVariant.outline,
                size: UiSize.sm,
                onPressed: () {
                  final journalRecord = AppWritingPostAttachment.manual(
                    source: AppLinkRef(
                      kind: AppLinkKind.journal,
                      id: 'trade_${DateTime.now().millisecondsSinceEpoch}',
                      title: '${setup.ticker} ${setup.side} Execution',
                    ),
                    excerpt:
                        'Entry: ${setup.entry} | SL: ${setup.stopLoss ?? "N/A"} | Target: ${setup.target ?? "N/A"}',
                    updatedAt: DateTime.now(),
                    tags: [setup.ticker, setup.side],
                  );
                  widget.repository.addAttachableRecord(journalRecord);
                  UiToast.show(
                    context,
                    title: 'Setup Copied to Journal!',
                    message:
                        '${setup.ticker} ${setup.side} logged into your Trading Journal desk.',
                    intent: UiIntent.success,
                  );
                },
              ),
              UiButton(
                label: 'AI Vision Analysis',
                leadingIcon: Icons.auto_awesome_rounded,
                variant: UiVariant.soft,
                intent: UiIntent.primary,
                size: UiSize.sm,
                onPressed: () {
                  CommunityAiAssistantDialog.show(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _computeRiskReward(CommunityTradeSetup setup) {
    if (setup.rMultiple != null) return setup.rMultiple;
    final entry = double.tryParse(setup.entry.replaceAll(RegExp(r'[^0-9.]'), ''));
    final sl = setup.stopLoss != null ? double.tryParse(setup.stopLoss!.replaceAll(RegExp(r'[^0-9.]'), '')) : null;
    final target = setup.target != null ? double.tryParse(setup.target!.replaceAll(RegExp(r'[^0-9.]'), '')) : null;
    if (entry == null || sl == null || target == null) return null;
    double risk = 0;
    double reward = 0;
    if (setup.isBullish) {
      risk = entry - sl;
      reward = target - entry;
    } else {
      risk = sl - entry;
      reward = entry - target;
    }
    if (risk <= 0 || reward <= 0) return null;
    return '1 : ${(reward / risk).toStringAsFixed(1)} R:R';
  }

  Widget _metricBox(BuildContext context, String label, String value) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(11),
          ),
        ),
        Text(
          value,
          style: context.uiText.caption.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: context.fs(13),
            color: theme.colors.foreground,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Sidebar: Author Profile & Analytics
  // ---------------------------------------------------------------------------

  Widget _buildAuthorAnalyticsCard(UiTheme theme, CommunityAuthor author) {
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: UiSize.lg,
                verified: author.verified,
                verifiedColor: author.verifiedColor(theme),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: context.fs(15),
                      ),
                    ),
                    Text(
                      '@${author.handle}',
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (author.bio != null && author.bio!.isNotEmpty) ...[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              author.bio!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
                height: 1.4,
              ),
            ),
          ],
          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.sm)),

          // Verified Metrics Grid
          Row(
            children: [
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Win Rate',
                  value: author.winRate != null ? '${author.winRate!.toStringAsFixed(1)}%' : '67.2%',
                  intent: UiIntent.success,
                ),
              ),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Followers',
                  value: uiCompactNumber(author.followers),
                ),
              ),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Sharpe',
                  value: '2.14',
                ),
              ),
            ],
          ),

          SizedBox(height: context.sp(theme.spacing.md)),

          // Follow / DM Actions
          Row(
            children: [
              UiIconButton(
                icon: author.isFollowing
                    ? Icons.check_rounded
                    : Icons.person_add_rounded,
                variant: author.isFollowing
                    ? UiVariant.outline
                    : UiVariant.primary,
                size: UiSize.sm,
                tooltip: author.isFollowing
                    ? 'Following @${author.handle}'
                    : 'Follow @${author.handle}',
                onPressed: () => widget.repository.toggleFollow(author.id),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.mail_outline_rounded,
                size: UiSize.sm,
                variant: UiVariant.ghost,
                tooltip: 'Send Direct Message',
                onPressed: () {
                  UiToast.show(
                    context,
                    title: 'Direct Message',
                    message: 'Opening encrypted DM channel with @${author.handle}',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sidebarStat(
    UiTheme theme, {
    required String label,
    required String value,
    UiIntent? intent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(11),
          ),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: context.uiText.numeric.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: context.fs(14),
            color: intent == UiIntent.success ? theme.colors.bullish : theme.colors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorRecentSetupsCard(UiTheme theme, CommunityAuthor author) {
    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: context.sz(16), color: theme.colors.primary),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                'Recent Setups by @${author.handle}',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.fs(13),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          _recentSetupRow(theme, 'NIFTY 24500 CE', '+42.5%', isWin: true),
          SizedBox(height: context.sp(theme.spacing.xs)),
          _recentSetupRow(theme, 'RELIANCE Breakout', '+18.2%', isWin: true),
          SizedBox(height: context.sp(theme.spacing.xs)),
          _recentSetupRow(theme, 'BANKNIFTY Scalp', '-12.0%', isWin: false),
        ],
      ),
    );
  }

  Widget _recentSetupRow(UiTheme theme, String title, String pnl, {required bool isWin}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted,
        borderRadius: context.radius(theme.radii.sm),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.uiText.caption.copyWith(fontWeight: FontWeight.w600)),
          Text(
            pnl,
            style: context.uiText.numeric.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: context.fs(12),
              color: isWin ? theme.colors.bullish : theme.colors.bearish,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskComplianceCard(UiTheme theme) {
    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      decoration: BoxDecoration(
        color: theme.colors.surfaceMuted.withValues(alpha: 0.5),
        borderRadius: context.radius(theme.radii.sm),
        border: Border.all(color: theme.colors.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: context.sz(14), color: theme.colors.foregroundSubtle),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text(
              'TradeX Community posts are for educational purposes. Always manage position sizing and risk parameters.',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundSubtle,
                fontSize: context.fs(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mobile Sticky Bottom Quick Reply Bar
  // ---------------------------------------------------------------------------

  Widget _buildMobileStickyReplyBar(UiTheme theme) {
    return Container(
      padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            UiAvatar(
              name: widget.currentUser.displayName,
              imageUrl: widget.currentUser.avatarUrl,
              size: UiSize.xs,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Expanded(
              child: UiInput(
                controller: _mobileQuickReplyCtrl,
                hintText: 'Reply to @${widget.post.author.handle}...',
                size: UiSize.sm,
              ),
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            UiButton(
              label: 'Reply',
              size: UiSize.sm,
              loading: _mobileSubmitting,
              expandOnMobile: false,
              onPressed: _handleMobileQuickReply,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatTimestamp(DateTime dt) {
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final month = _shortMonths[dt.month - 1];
  return '$hour:$minute $period · $month ${dt.day}, ${dt.year}';
}

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
