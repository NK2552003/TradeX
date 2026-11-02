import 'package:tradex/features/community/presentation/widgets/community_composer_card.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tradex/features/market_data/presentation/market_sidebar.dart';
import 'package:tradex/core/app-ui/app_ui.dart' hide CommunityPostCard;
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_trade_setup_tile.dart';
import 'package:tradex/features/community/presentation/widgets/community_edit_post_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_post_card.dart';
import 'package:tradex/features/community/presentation/widgets/community_repost_dialog.dart';
import 'package:tradex/features/ai_assistant/ai_assistant.dart';
import 'package:tradex/features/community/presentation/widgets/community_send_dm_dialog.dart';
import 'package:tradex/features/community/presentation/widgets/community_share_sheet.dart';
import 'package:tradex/features/community/presentation/widgets/universal_comments_section.dart';
import 'package:tradex/features/journal/data/journal_repository.dart';

// ---------------------------------------------------------------------------
// CommunityPostDetailView
// ---------------------------------------------------------------------------

/// Detailed thread view with unified post card and responsive multi-device layouts.
///
/// Uses the canonical [CommunityPostCard] (with [CommunityPostCardVariant.boxed])
/// ensuring 100% design fidelity and consistency with feed post cards.
///
/// Layout Strategy:
/// - Desktop: 2-column architecture (left: canonical post card & LinkedIn comments thread;
///   right: sticky author analytics sidebar with win-rate stats, recent setups, and risk compliance).
/// - Tablet: Adaptive stacked layout with interactive author stat card.
/// - Mobile: Full-width feed-centric layout with sticky bottom quick reply bar.
class CommunityPostDetailView extends StatefulWidget {
  const CommunityPostDetailView({
    super.key,
    required this.post,
    required this.repository,
    required this.currentUser,
    this.onAuthorTap,
    this.onStartDirectMessage,
    this.onBack,
    this.showHeader = true,
    this.onOpenRef,
    this.onTagTap,
    this.onPostTap,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppTrader>? onStartDirectMessage;
  final VoidCallback? onBack;
  final bool showHeader;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<CommunityPost>? onPostTap;

  @override
  State<CommunityPostDetailView> createState() =>
      _CommunityPostDetailViewState();
}

class _CommunityPostDetailViewState extends State<CommunityPostDetailView> {
  final TextEditingController _mobileQuickReplyCtrl = TextEditingController();
  final FocusNode _mobileReplyFocusNode = FocusNode();
  final ScrollController _rightSidebarController = ScrollController();
  bool _mobileSubmitting = false;
  bool? _authorFollowingOverride;

  @override
  void initState() {
    super.initState();
    widget.repository.recordDetailExpand(widget.post.id);
    widget.repository.recordView(widget.post.id);
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _mobileQuickReplyCtrl.dispose();
    _mobileReplyFocusNode.dispose();
    _rightSidebarController.dispose();
    widget.repository.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  /// Finds the freshest instance of this post from the repository.
  CommunityPost get _currentPost {
    for (final p in widget.repository.forYouPosts) {
      if (p.id == widget.post.id) return p;
    }
    for (final p in widget.repository.followingPosts) {
      if (p.id == widget.post.id) return p;
    }
    for (final p in widget.repository.signalPosts) {
      if (p.id == widget.post.id) return p;
    }
    for (final p in widget.repository.bookmarkedPosts) {
      if (p.id == widget.post.id) return p;
    }
    return widget.post;
  }

  void _handleLike() {
    widget.repository.toggleLike(widget.post.id);
  }

  void _handleRepost() {
    CommunityRepostDialog.show(
      context,
      post: _currentPost,
      onRepost: () {
        widget.repository.toggleRepost(widget.post.id);
      },
      onQuote: () => _quotePost(_currentPost),
    );
  }

  void _quotePost(CommunityPost post) {
    UiDialog.show<void>(
      context,
      maxWidth: 680,
      child: Builder(
        builder: (dialogContext) => SingleChildScrollView(
          child: CommunityComposerCard(
            author: widget.currentUser,
            repository: widget.repository,
            quotedPost: post,
            onPostCreated: () => Navigator.of(dialogContext).pop(),
            onClose: () => Navigator.of(dialogContext).pop(),
          ),
        ),
      ),
    );
  }

  void _handleBookmark() {
    widget.repository.toggleBookmark(widget.post.id);
    final bool isBookmarked = !_currentPost.bookmarked;
    UiToast.show(
      context,
      title: isBookmarked ? 'Bookmark Added' : 'Bookmark Removed',
      message: isBookmarked
          ? 'Post saved to your bookmarks library.'
          : 'Removed from bookmarks.',
      intent: isBookmarked ? UiIntent.primary : UiIntent.neutral,
    );
  }

  void _handleShare() {
    CommunityShareSheet.show(context, post: _currentPost);
  }

  Future<void> _togglePostVisibility(bool next) async {
    if (next) {
      final bool ok = await UiDialog.confirm(
        context,
        title: 'Make this post public?',
        description:
            'This post will become visible to all community members and appear in the explore feed.',
        confirmLabel: 'Make Public',
      );
      if (!ok || !mounted) return;
    }
    try {
      await widget.repository.setPostVisibility(_currentPost.id, next);
    } catch (error) {
      if (mounted) {
        UiToast.error(
          context,
          title: 'Visibility was not changed',
          message: '$error',
        );
      }
      return;
    }
    if (mounted) {
      UiToast.show(
        context,
        title: next ? 'Post Published' : 'Post Made Private',
        message: next
            ? 'Your post is now visible to the trading community.'
            : 'Your post is now private to your profile.',
        intent: next ? UiIntent.success : UiIntent.warning,
      );
    }
  }

  Future<void> _copySetupToJournal(CommunityTradeSetup setup) async {
    final double? entry = double.tryParse(setup.entry);
    if (entry == null) {
      UiToast.error(
        context,
        title: 'Setup cannot be copied',
        message: 'The shared entry price is invalid.',
      );
      return;
    }
    await JournalRepositoryScope.repository.create(
      AppTrade(
        id: 'trade_community_${DateTime.now().millisecondsSinceEpoch}',
        ticker: setup.ticker,
        side: setup.side.toLowerCase() == 'short'
            ? AppSide.short
            : AppSide.long,
        openedAt: DateTime.now(),
        entry: entry,
        exit: null,
        stopLoss: double.tryParse(setup.stopLoss ?? ''),
        target: double.tryParse(setup.target ?? ''),
        size: 0,
        title: 'Community setup: ${setup.ticker}',
        content:
            'Copied from @${_currentPost.author.handle}\n\n${_currentPost.body}',
        strategy: 'Community setup',
      ),
    );
    if (!mounted) return;
    UiToast.success(
      context,
      title: 'Copied to Journal',
      message:
          'Trade setup for ${setup.ticker} is ready to review in your journal.',
    );
  }

  Future<void> _handleMobileQuickReply() async {
    final text = _mobileQuickReplyCtrl.text.trim();
    if (text.isEmpty || _mobileSubmitting) return;

    setState(() => _mobileSubmitting = true);
    try {
      await widget.repository.addComment(
        widget.post.id,
        text,
        author: widget.currentUser,
      );
      _mobileQuickReplyCtrl.clear();
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Reply sent for review',
        message: 'An admin must approve it before it appears in the thread.',
        intent: UiIntent.success,
      );
    } finally {
      if (mounted) setState(() => _mobileSubmitting = false);
    }
  }

  bool get _isAuthor {
    final current = widget.currentUser;
    final author = _currentPost.author;
    if (author.id == current.id ||
        author.handle.toLowerCase() == current.handle.toLowerCase()) {
      return true;
    }
    final cleanCurrent = current.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    final cleanAuthor = author.handle
        .toLowerCase()
        .replaceFirst('@', '')
        .trim();
    return cleanCurrent.isNotEmpty && cleanCurrent == cleanAuthor;
  }

  Future<void> _handleEditPost() async {
    await CommunityEditPostDialog.show(
      context,
      post: _currentPost,
      repository: widget.repository,
    );
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isDesktop = context.uiRes.isDesktop;
    final isMobile = context.uiRes.isMobile;
    final author = _currentPost.author;
    final comments = widget.repository.commentsForPost(widget.post.id);

    return Scaffold(
      backgroundColor: theme.colors.background,
      bottomNavigationBar: isMobile ? _buildMobileStickyReplyBar(theme) : null,
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
    final post = _currentPost;
    final ticker =
        post.tradeSetup?.ticker ??
        (post.tickers.isNotEmpty ? post.tickers.first : null);

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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  onPressed:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
                Container(
                  height: context.sz(18),
                  width: theme.borders.hairline,
                  color: theme.colors.border.withValues(alpha: 0.6),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
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
                        if (post.tradeSetup?.side != null) ...[
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          UiBadge(
                            label: post.tradeSetup!.side,
                            intent: post.tradeSetup!.isBullish
                                ? UiIntent.success
                                : UiIntent.danger,
                            variant: UiBadgeVariant.soft,
                            size: UiSize.xs,
                          ),
                        ],
                        if (_isAuthor) ...[
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          UiButton(
                            label: isMobile ? 'Edit' : 'Edit Post',
                            icon: Icons.edit_outlined,
                            size: UiSize.xs,
                            variant: UiVariant.soft,
                            intent: UiIntent.primary,
                            onPressed: _handleEditPost,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                if (!isMobile)
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
                  icon: Icons.auto_awesome_rounded,
                  size: UiSize.xs,
                  tooltip: 'Analyze with AI Copilot',
                  intent: UiIntent.primary,
                  onPressed: () {
                    final String prompt =
                        'Analyze community post by @${post.author.handle}:\n\n'
                        '"${post.body}"\n\n'
                        'Provide sentiment breakdown, technical setup validity, and potential counter-thesis risks.';

                    AiAssistantOverlaySheet.show(
                      context,
                      repository: AiAssistantRepositoryScope.repository,
                      initialPrompt: prompt,
                      contextTitle: 'Post by @${post.author.handle}',
                      contextSubtitle: post.body.length > 50
                          ? '${post.body.substring(0, 50)}...'
                          : post.body,
                      contextIcon: Icons.public_rounded,
                      contextRef: AppLinkRef(
                        id: post.id,
                        kind: AppLinkKind.communityPost,
                        title: 'Post by @${post.author.handle}',
                        subtitle: post.body,
                      ),
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

  Widget _buildDesktopHeader(BuildContext context, UiTheme theme) {
    final post = _currentPost;
    final ticker =
        post.tradeSetup?.ticker ??
        (post.tickers.isNotEmpty ? post.tickers.first : null);

    return Container(
      height: context.sz(40),
      padding: const EdgeInsets.symmetric(horizontal: 4),
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
          if (ticker != null) ...[
            UiBadge(
              label: ticker,
              intent: UiIntent.primary,
              variant: UiBadgeVariant.solid,
              size: UiSize.xs,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          if (post.tradeSetup?.side != null) ...[
            UiBadge(
              label: post.tradeSetup!.side,
              intent: post.tradeSetup!.isBullish
                  ? UiIntent.success
                  : UiIntent.danger,
              variant: UiBadgeVariant.soft,
              size: UiSize.xs,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          if (_isAuthor) ...[
            UiButton(
              label: 'Edit Post',
              icon: Icons.edit_outlined,
              size: UiSize.xs,
              variant: UiVariant.soft,
              intent: UiIntent.primary,
              onPressed: _handleEditPost,
            ),
          ],
          const Spacer(),
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
            icon: Icons.auto_awesome_rounded,
            size: UiSize.xs,
            tooltip: 'Analyze with AI Copilot',
            intent: UiIntent.primary,
            onPressed: () {
              final String prompt =
                  'Analyze community post by @${post.author.handle}:\n\n'
                  '"${post.body}"\n\n'
                  'Provide sentiment breakdown, technical setup validity, and potential counter-thesis risks.';

              AiAssistantOverlaySheet.show(
                context,
                repository: AiAssistantRepositoryScope.repository,
                initialPrompt: prompt,
                contextTitle: 'Post by @${post.author.handle}',
                contextSubtitle: post.body.length > 50
                    ? '${post.body.substring(0, 50)}...'
                    : post.body,
                contextIcon: Icons.public_rounded,
                contextRef: AppLinkRef(
                  id: post.id,
                  kind: AppLinkKind.communityPost,
                  title: 'Post by @${post.author.handle}',
                  subtitle: post.body,
                ),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop 2-Column Responsive Layout: Left Main Column, Right Sticky Sidebar
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout(
    UiTheme theme,
    CommunityAuthor author,
    List<CommunityComment> comments,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Panel 1: Main Post Thread & Comments Panel (Expanded to span all space up to the right sidebar)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.colors.border.withValues(alpha: 0.6),
                  width: theme.borders.hairline,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (widget.showHeader)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.sp(theme.spacing.md),
                      context.sp(theme.spacing.xs),
                      context.sp(theme.spacing.md),
                      0,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: context.sz(700)),
                        child: _buildDesktopHeader(
                          context,
                          theme,
                        ),
                      ),
                    ),
                  ),
                // Thread content (post card & comments centered at maxWidth: 700px)
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: context.sz(700)),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.md),
                          context.sp(theme.spacing.xl),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            CommunityPostCard(
                              key: ValueKey<String>(
                                'detail_${_currentPost.id}',
                              ),
                              post: _currentPost,
                              variant: CommunityPostCardVariant.boxed,
                              showAuthorHeader: false,
                              showTradeSetup: false,
                              repository: widget.repository,
                              currentUser: widget.currentUser,
                              onLike: _handleLike,
                              onRepost: () => widget.repository.toggleRepost(
                                widget.post.id,
                              ),
                              onQuote: _quotePost,
                              onBookmark: _handleBookmark,
                              onShare: _handleShare,
                              onCopySetup: _currentPost.tradeSetup == null
                                  ? null
                                  : () => _copySetupToJournal(
                                      _currentPost.tradeSetup!,
                                    ),
                              onAuthorTap: widget.onAuthorTap,
                              onOpenRef: widget.onOpenRef,
                              onTagTap: widget.onTagTap,
                              onVotePoll: (idx) => widget.repository.votePoll(
                                widget.post.id,
                                idx,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.lg)),
                            UniversalCommentsSection(
                              targetId: widget.post.id,
                              targetType: 'post',
                              comments: comments,
                              currentUser: widget.currentUser,
                              isPublic: _currentPost.isPublic,
                              canToggleVisibility:
                                  _currentPost.author.id ==
                                  widget.currentUser.id,
                              onToggleVisibility: _togglePostVisibility,
                              onAuthorTap: widget.onAuthorTap,
                              onTagTap: widget.onTagTap,

                              onAddComment:
                                  (text, {parentCommentId, sentiment}) async {
                                    await widget.repository.addComment(
                                      widget.post.id,
                                      text,
                                      author: widget.currentUser,
                                      parentId: parentCommentId,
                                      sentiment: sentiment,
                                    );
                                  },
                              onLikeComment: (commentId, {reaction}) {
                                widget.repository.likeComment(
                                  widget.post.id,
                                  commentId,
                                  reaction: reaction,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Panel 2: Right Companion Sidebar (docked firmly to the right side of the screen at width 340)
        SizedBox(
          width: context.sz(340),
          child: Scrollbar(
            controller: _rightSidebarController,
            child: SingleChildScrollView(
              controller: _rightSidebarController,
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!_isAuthor) ...[
                    _buildAuthorProfileCard(theme, author),
                    SizedBox(height: context.sp(theme.spacing.md)),
                  ],
                  if (_currentPost.tradeSetup != null) ...[
                    UiGap.v(theme.spacing.md),
                    UiCard(
                      title: 'Setup Blueprint',
                      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                      child: CommunityTradeSetupTile(
                        setup: _currentPost.tradeSetup!,
                        onLogToJournal: () =>
                            _copySetupToJournal(_currentPost.tradeSetup!),
                      ),
                    ),
                  ],
                  SizedBox(height: context.sp(theme.spacing.md)),
                  _buildThreadActivityCard(theme, comments),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  _buildAuthorRecentSetupsCard(theme, author),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  _buildRiskComplianceCard(theme),
                  UiGap.v(theme.spacing.md),
                  const MarketSidebar(),
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
    final double clearance = widget.showHeader
        ? (context.sz(44) +
            context.sp(theme.spacing.sm) +
            context.sp(theme.spacing.xs))
        : context.sp(theme.spacing.xs);

    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            clearance,
            context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            context.sp(isMobile ? 80 : theme.spacing.lg),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: context.sz(700)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  CommunityPostCard(
                    key: ValueKey<String>('detail_${_currentPost.id}'),
                    post: _currentPost,
                    variant: CommunityPostCardVariant.boxed,
                    repository: widget.repository,
                    currentUser: widget.currentUser,
                    onReply: () {
                      if (isMobile) {
                        _mobileReplyFocusNode.requestFocus();
                      }
                    },
                    onLike: _handleLike,
                    onRepost: () =>
                        widget.repository.toggleRepost(widget.post.id),
                    onQuote: _quotePost,
                    onBookmark: _handleBookmark,
                    onShare: _handleShare,
                    onCopySetup: _currentPost.tradeSetup == null
                        ? null
                        : () => _copySetupToJournal(_currentPost.tradeSetup!),
                    onAuthorTap: widget.onAuthorTap,
                    onOpenRef: widget.onOpenRef,
                    onTagTap: widget.onTagTap,
                    onVotePoll: (idx) =>
                        widget.repository.votePoll(widget.post.id, idx),
                  ),
                  if (!_isAuthor) ...[
                    SizedBox(height: context.sp(theme.spacing.md)),
                    _buildAuthorProfileCard(theme, author),
                  ],
                  SizedBox(height: context.sp(theme.spacing.md)),
                  UniversalCommentsSection(
                    targetId: widget.post.id,
                    targetType: 'post',
                    comments: comments,
                    currentUser: widget.currentUser,
                    isPublic: _currentPost.isPublic,
                    canToggleVisibility:
                        _currentPost.author.id == widget.currentUser.id,
                    onToggleVisibility: _togglePostVisibility,
                    onAuthorTap: widget.onAuthorTap,
                    onTagTap: widget.onTagTap,

                    onAddComment: (text, {parentCommentId, sentiment}) async {
                      await widget.repository.addComment(
                        widget.post.id,
                        text,
                        author: widget.currentUser,
                        parentId: parentCommentId,
                        sentiment: sentiment,
                      );
                    },
                    onLikeComment: (commentId, {reaction}) {
                      widget.repository.likeComment(
                        widget.post.id,
                        commentId,
                        reaction: reaction,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),

        // Standalone views own a header; the app shell supplies it when embedded.
        if (widget.showHeader)
          Positioned(
            top: context.sp(theme.spacing.xs),
            left: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            right: context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: context.sz(700)),
                child: _buildFloatingHeader(context, theme, isMobile: isMobile),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Desktop Sidebar Companion Cards
  // ---------------------------------------------------------------------------

  Widget _buildAuthorProfileCard(UiTheme theme, CommunityAuthor postAuthor) {
    final author = widget.repository.authorById(postAuthor.id) ?? postAuthor;
    final bool isCurrentUser = _isAuthor;
    final bool isFollowing = _authorFollowingOverride ?? author.isFollowing;
    final int followers =
        author.followers +
        (isFollowing == author.isFollowing ? 0 : (isFollowing ? 1 : -1));
    return UiCard(
      semanticLabel: 'Post author ${author.displayName}',
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                verified: author.verified,
                onTap: widget.onAuthorTap == null
                    ? null
                    : () => widget.onAuthorTap!(author),
              ),
              UiGap.h(theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            author.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.bodyStrong.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (author.verified) ...[
                          UiGap.h(theme.spacing.xxs),
                          Icon(
                            Icons.verified_rounded,
                            size: context.sz(16),
                            color: author.verifiedColor(theme),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      author.displayHandle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          UiGap.v(theme.spacing.md),
          UiDivider(),
          UiGap.v(theme.spacing.sm),
          Row(
            children: [
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Win Rate',
                  value: author.winRate == null
                      ? '—'
                      : '${author.winRate!.toStringAsFixed(1)}%',
                  intent: UiIntent.success,
                ),
              ),
              UiGap.h(theme.spacing.sm),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Followers',
                  value: uiCompactNumber(followers < 0 ? 0 : followers),
                ),
              ),
            ],
          ),
          if (!isCurrentUser) ...[
            UiGap.v(theme.spacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool stackActions =
                    constraints.maxWidth < context.sz(280) ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final follow = UiButton(
                  label: isFollowing ? 'Following' : 'Follow',
                  variant: isFollowing ? UiVariant.outline : UiVariant.primary,
                  size: UiSize.sm,
                  expand: true,
                  leadingIcon: isFollowing
                      ? Icons.check_rounded
                      : Icons.person_add_rounded,
                  onPressed: () {
                    widget.repository.toggleFollow(author.id);
                    setState(() => _authorFollowingOverride = !isFollowing);
                  },
                );
                final message = UiButton(
                  label: 'Message',
                  variant: UiVariant.outline,
                  size: UiSize.sm,
                  expand: true,
                  leadingIcon: Icons.mail_outline_rounded,
                  onPressed: () {
                    if (widget.onStartDirectMessage case final open?) {
                      open(
                        AppTrader(
                          id: author.id,
                          handle: author.handle,
                          displayName: author.displayName,
                          avatarUrl: author.avatarUrl,
                        ),
                      );
                      return;
                    }
                    CommunitySendDmDialog.show(
                      context,
                      repository: widget.repository,
                      initialRecipient: author,
                    );
                  },
                );
                if (stackActions) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [follow, UiGap.v(theme.spacing.xs), message],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: follow),
                    UiGap.h(theme.spacing.xs),
                    Expanded(child: message),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThreadActivityCard(
    UiTheme theme,
    List<CommunityComment> comments,
  ) {
    final Set<String> seenTickers = <String>{};
    final List<String> distinctTickers = <String>[];
    for (final raw in _currentPost.tickers) {
      final String clean = raw.trim().replaceFirst(RegExp(r'^\$+'), '');
      if (clean.isEmpty) continue;
      final String key = clean
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      if (seenTickers.add(key)) {
        distinctTickers.add(clean);
      }
    }

    final Set<String> tickerKeys = distinctTickers
        .map((t) => t.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase())
        .toSet();
    final Set<String> seenTags = <String>{};
    final List<String> distinctTags = <String>[];
    for (final raw in _currentPost.tags) {
      final String clean = raw.trim().replaceFirst(RegExp(r'^[#\$]+'), '');
      if (clean.isEmpty) continue;
      final String key = clean
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toLowerCase();
      if (tickerKeys.contains(key)) continue;
      if (seenTags.add(key)) {
        distinctTags.add(clean);
      }
    }

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.forum_outlined,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Text(
                'Thread Activity',
                style: context.uiText.label.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: context.fs(13),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Replies',
                  value: '${comments.length}',
                ),
              ),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Likes',
                  value: uiCompactNumber(_currentPost.likes),
                ),
              ),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Reposts',
                  value: uiCompactNumber(_currentPost.reposts),
                ),
              ),
              Expanded(
                child: _sidebarStat(
                  theme,
                  label: 'Views',
                  value: uiCompactNumber(_currentPost.views),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiDivider(),
          SizedBox(height: context.sp(theme.spacing.xs)),
          // Interactive Action Controls for Desktop Companion Sidebar
          Row(
            children: <Widget>[
              Expanded(
                child: UiButton(
                  label: _currentPost.liked ? 'Liked' : 'Like',
                  icon: _currentPost.liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  variant: _currentPost.liked
                      ? UiVariant.soft
                      : UiVariant.outline,
                  intent: _currentPost.liked
                      ? UiIntent.danger
                      : UiIntent.primary,
                  size: UiSize.xs,
                  onPressed: _handleLike,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: UiButton(
                  label: _currentPost.reposted ? 'Reposted' : 'Repost',
                  icon: Icons.repeat_rounded,
                  variant: _currentPost.reposted
                      ? UiVariant.soft
                      : UiVariant.outline,
                  intent: _currentPost.reposted
                      ? UiIntent.success
                      : UiIntent.primary,
                  size: UiSize.xs,
                  onPressed: _handleRepost,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: _currentPost.bookmarked
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                tooltip: _currentPost.bookmarked ? 'Bookmarked' : 'Bookmark',
                size: UiSize.xs,
                intent: _currentPost.bookmarked
                    ? UiIntent.warning
                    : UiIntent.primary,
                variant: _currentPost.bookmarked
                    ? UiVariant.soft
                    : UiVariant.ghost,
                onPressed: _handleBookmark,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              UiIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: 'Share',
                size: UiSize.xs,
                variant: UiVariant.ghost,
                onPressed: _handleShare,
              ),
            ],
          ),
          if (distinctTickers.isNotEmpty ||
              distinctTags.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            const UiDivider(),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.tag_rounded,
                  size: context.sz(14),
                  color: theme.colors.foregroundSubtle,
                ),
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Flexible(
                  child: Text(
                    'Associated Tickers & Tags',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xs),
              children: <Widget>[
                for (final ticker in distinctTickers)
                  UiBadge(
                    label: '\$$ticker',
                    intent: UiIntent.primary,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                for (final tag in distinctTags)
                  UiBadge(
                    label: '#$tag',
                    intent: UiIntent.info,
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuthorRecentSetupsCard(UiTheme theme, CommunityAuthor author) {
    final bool isCurrentUser = author.id == widget.currentUser.id;
    final seen = <String>{};
    final recentSetups =
        <CommunityPost>[
              _currentPost,
              ...widget.repository.postsForAuthor(author.id),
            ]
            .where((post) => post.tradeSetup != null && seen.add(post.id))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.history_rounded,
                size: context.sz(16),
                color: theme.colors.primary,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Expanded(
                child: Text(
                  isCurrentUser
                      ? 'Your Recent Setups'
                      : 'Recent Setups by @${author.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(13),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          if (recentSetups.isEmpty)
            Text(
              'No public setups shared yet.',
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          for (final post in recentSetups.take(3)) ...[
            _recentSetupRow(theme, post),
            UiGap.v(theme.spacing.xs),
          ],
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundSubtle,
            fontSize: context.fs(11),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          style: context.uiText.numeric.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: context.fs(14),
            color: intent == UiIntent.success
                ? theme.colors.bullish
                : intent == UiIntent.danger
                ? theme.colors.bearish
                : theme.colors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _recentSetupRow(UiTheme theme, CommunityPost post) {
    final setup = post.tradeSetup!;
    return UiCard(
      variant: UiCardVariant.subtle,
      padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
      onTap: widget.onPostTap == null ? null : () => widget.onPostTap!(post),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '${setup.ticker} · ${setup.side}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.caption.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          UiGap.h(theme.spacing.xs),
          UiBadge(
            label: setup.pnl?.isNotEmpty == true ? setup.pnl! : 'Open',
            intent: setup.isWin == null
                ? UiIntent.neutral
                : (setup.isWin! ? UiIntent.success : UiIntent.danger),
            variant: UiBadgeVariant.soft,
            size: UiSize.xs,
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
          Icon(
            Icons.shield_outlined,
            size: context.sz(14),
            color: theme.colors.foregroundSubtle,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          Expanded(
            child: Text(
              'alphajournal Community posts are for educational purposes. Always manage position sizing and risk parameters.',
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.xs),
        context.sp(theme.spacing.xs),
        context.sp(theme.spacing.xs),
        context.sp(theme.spacing.xs) + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.colors.surface,
        border: Border(
          top: BorderSide(
            color: theme.colors.border,
            width: theme.borders.hairline,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
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
                focusNode: _mobileReplyFocusNode,
                hintText:
                    'Reply to @${widget.post.author.handle.replaceFirst(RegExp(r'^@'), '')}...',
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
