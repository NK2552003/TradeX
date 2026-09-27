import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_highlighted_text.dart';

// ---------------------------------------------------------------------------
// Universal LinkedIn-Grade Comments Section
// ---------------------------------------------------------------------------

/// Universal LinkedIn-style discussion & comment thread system.
///
/// Features:
/// - Distinct soft-card comment bubbles with trader credentials & headlines.
/// - Rich LinkedIn-style emoji reaction bar (👍 Like, 🚀 Bullish, 💡 Insightful, 🔥 Fire, ❤️ Love).
/// - Multi-level nested threading with visual connection guides and collapsible reply trees.
/// - Inline threaded reply composer with prefilled `@mention`.
/// - Autocomplete-ready primary composer with sentiment tagging.
/// - Usable across Posts, Notes, Journals, and Strategy screens.
class UniversalCommentsSection extends StatefulWidget {
  const UniversalCommentsSection({
    super.key,
    required this.targetId,
    required this.targetType,
    required this.comments,
    required this.currentUser,
    required this.onAddComment,
    this.onLikeComment,
    this.onAuthorTap,
    this.onTagTap,
    this.title = 'Trader Discussion',
  });

  final String targetId;
  final String targetType;
  final List<CommunityComment> comments;
  final CommunityAuthor currentUser;
  final Future<void> Function(String text, {String? parentCommentId, String? sentiment}) onAddComment;
  final void Function(String commentId, {String? reaction})? onLikeComment;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final String title;

  @override
  State<UniversalCommentsSection> createState() => _UniversalCommentsSectionState();
}

class _UniversalCommentsSectionState extends State<UniversalCommentsSection> {
  final TextEditingController _mainCommentCtrl = TextEditingController();
  bool _submittingMain = false;
  String? _selectedSentiment;
  String _sortBy = 'Most Relevant';

  // Reply tracking
  String? _activeReplyingCommentId;
  final TextEditingController _replyCtrl = TextEditingController();
  bool _submittingReply = false;

  @override
  void dispose() {
    _mainCommentCtrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitMainComment() async {
    final text = _mainCommentCtrl.text.trim();
    if (text.isEmpty || _submittingMain) return;

    setState(() => _submittingMain = true);
    try {
      await widget.onAddComment(
        text,
        sentiment: _selectedSentiment,
      );
      _mainCommentCtrl.clear();
      setState(() => _selectedSentiment = null);
      if (mounted) {
        UiToast.show(
          context,
          title: 'Comment Published',
          message: 'Your insight is now visible to the community.',
          intent: UiIntent.success,
        );
      }
    } finally {
      if (mounted) setState(() => _submittingMain = false);
    }
  }

  Future<void> _submitReply(String parentId, CommunityAuthor parentAuthor) async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _submittingReply) return;

    setState(() => _submittingReply = true);
    try {
      await widget.onAddComment(
        text,
        parentCommentId: parentId,
      );
      _replyCtrl.clear();
      setState(() => _activeReplyingCommentId = null);
      if (mounted) {
        UiToast.show(
          context,
          title: 'Reply Published',
          message: 'Replied to @${parentAuthor.handle}.',
          intent: UiIntent.success,
        );
      }
    } finally {
      if (mounted) setState(() => _submittingReply = false);
    }
  }

  void _startReply(CommunityComment comment) {
    setState(() {
      _activeReplyingCommentId = comment.id;
      _replyCtrl.text = '@${comment.author.handle} ';
      _replyCtrl.selection = TextSelection.collapsed(offset: _replyCtrl.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final totalCount = _countCommentsRecursively(widget.comments);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // ---------------------------------------------------------------------
        // Section Header (Title, Count, Sort)
        // ---------------------------------------------------------------------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.forum_rounded,
                  size: context.sz(18),
                  color: theme.colors.primary,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                Text(
                  widget.title,
                  style: context.uiText.heading.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: context.fs(16),
                  ),
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                UiBadge(
                  label: '$totalCount',
                  intent: UiIntent.primary,
                  variant: UiBadgeVariant.soft,
                  size: UiSize.xs,
                ),
              ],
            ),
            UiToggleGroup<String>(
              size: UiSize.xs,
              value: _sortBy,
              onChanged: (v) => setState(() => _sortBy = v),
              options: const <UiToggleOption<String>>[
                UiToggleOption(value: 'Most Relevant', label: 'Top'),
                UiToggleOption(value: 'Newest', label: 'Newest'),
              ],
            ),
          ],
        ),

        SizedBox(height: context.sp(theme.spacing.sm)),

        // ---------------------------------------------------------------------
        // LinkedIn-Style Primary Composer Box
        // ---------------------------------------------------------------------
        UiCard(
          variant: UiCardVariant.surface,
          padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  UiAvatar(
                    name: widget.currentUser.displayName,
                    imageUrl: widget.currentUser.avatarUrl,
                    size: isMobile ? UiSize.xs : UiSize.sm,
                    verified: widget.currentUser.verified,
                    verifiedColor: widget.currentUser.verifiedColor(theme),
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        UiTextarea(
                          controller: _mainCommentCtrl,
                          hintText: 'Share technical analysis, key levels, or ask a question...',
                          rows: 2,
                          maxRows: 6,
                          showCounter: false,
                        ),
                        if (_selectedSentiment != null) ...<Widget>[
                          SizedBox(height: context.sp(theme.spacing.xxs)),
                          Row(
                            children: [
                              UiBadge(
                                label: _selectedSentiment!,
                                intent: _selectedSentiment == 'BULLISH'
                                    ? UiIntent.success
                                    : (_selectedSentiment == 'BEARISH' ? UiIntent.danger : UiIntent.info),
                                variant: UiBadgeVariant.solid,
                                size: UiSize.xs,
                                onRemove: () => setState(() => _selectedSentiment = null),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              UiDivider(spacing: context.sp(theme.spacing.xxs)),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Row(
                children: <Widget>[
                  // Quick Bullish sentiment tag
                  UiIconButton(
                    icon: Icons.trending_up_rounded,
                    tooltip: 'Bullish Bias',
                    size: UiSize.xs,
                    variant: _selectedSentiment == 'BULLISH' ? UiVariant.soft : UiVariant.ghost,
                    intent: UiIntent.success,
                    onPressed: () {
                      setState(() {
                        _selectedSentiment = _selectedSentiment == 'BULLISH' ? null : 'BULLISH';
                      });
                    },
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  // Quick Bearish sentiment tag
                  UiIconButton(
                    icon: Icons.trending_down_rounded,
                    tooltip: 'Bearish Bias',
                    size: UiSize.xs,
                    variant: _selectedSentiment == 'BEARISH' ? UiVariant.soft : UiVariant.ghost,
                    intent: UiIntent.danger,
                    onPressed: () {
                      setState(() {
                        _selectedSentiment = _selectedSentiment == 'BEARISH' ? null : 'BEARISH';
                      });
                    },
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  // Add quick cash-tag icon
                  UiIconButton(
                    icon: Icons.attach_money_rounded,
                    tooltip: 'Insert \$TICKER',
                    size: UiSize.xs,
                    variant: UiVariant.ghost,
                    onPressed: () {
                      _mainCommentCtrl.text = '${_mainCommentCtrl.text}\$';
                      _mainCommentCtrl.selection = TextSelection.collapsed(
                        offset: _mainCommentCtrl.text.length,
                      );
                    },
                  ),
                  const Spacer(),
                  UiButton(
                    label: 'Comment',
                    size: UiSize.xs,
                    loading: _submittingMain,
                    expandOnMobile: false,
                    onPressed: _submitMainComment,
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: context.sp(theme.spacing.md)),

        // ---------------------------------------------------------------------
        // Threaded Comments List
        // ---------------------------------------------------------------------
        if (widget.comments.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.sp(theme.spacing.xl)),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: context.sz(32),
                  color: theme.colors.foregroundMuted.withValues(alpha: 0.5),
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  'No comments yet',
                  style: context.uiText.bodyStrong.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  'Be the first to share your technical thoughts or perspective.',
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ],
            ),
          )
        else
          for (final comment in widget.comments)
            _LinkedInCommentTile(
              comment: comment,
              theme: theme,
              activeReplyingCommentId: _activeReplyingCommentId,
              replyCtrl: _replyCtrl,
              submittingReply: _submittingReply,
              onStartReply: _startReply,
              onCancelReply: () => setState(() => _activeReplyingCommentId = null),
              onSubmitReply: _submitReply,
              onLike: (id) => widget.onLikeComment?.call(id),
              onReact: (id, reaction) => widget.onLikeComment?.call(id, reaction: reaction),
              onAuthorTap: widget.onAuthorTap,
              onTagTap: widget.onTagTap,
              indent: 0,
            ),
      ],
    );
  }

  int _countCommentsRecursively(List<CommunityComment> items) {
    int count = items.length;
    for (final c in items) {
      count += _countCommentsRecursively(c.replies);
    }
    return count;
  }
}

// ---------------------------------------------------------------------------
// Single LinkedIn-Grade Comment Tile
// ---------------------------------------------------------------------------

class _LinkedInCommentTile extends StatefulWidget {
  const _LinkedInCommentTile({
    required this.comment,
    required this.theme,
    required this.activeReplyingCommentId,
    required this.replyCtrl,
    required this.submittingReply,
    required this.onStartReply,
    required this.onCancelReply,
    required this.onSubmitReply,
    required this.onLike,
    required this.onReact,
    this.onAuthorTap,
    this.onTagTap,
    this.indent = 0,
  });

  final CommunityComment comment;
  final UiTheme theme;
  final String? activeReplyingCommentId;
  final TextEditingController replyCtrl;
  final bool submittingReply;
  final void Function(CommunityComment comment) onStartReply;
  final VoidCallback onCancelReply;
  final void Function(String parentId, CommunityAuthor author) onSubmitReply;
  final void Function(String commentId) onLike;
  final void Function(String commentId, String reaction) onReact;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<String>? onTagTap;
  final int indent;

  @override
  State<_LinkedInCommentTile> createState() => _LinkedInCommentTileState();
}

class _LinkedInCommentTileState extends State<_LinkedInCommentTile> {
  bool _repliesCollapsed = false;
  bool _showReactionPicker = false;

  static const List<Map<String, String>> _availableReactions = [
    {'emoji': '👍', 'label': 'Like'},
    {'emoji': '🚀', 'label': 'Bullish'},
    {'emoji': '💡', 'label': 'Insightful'},
    {'emoji': '🔥', 'label': 'Fire'},
    {'emoji': '❤️', 'label': 'Love'},
  ];

  String _reactionLabel(String? reaction) {
    switch (reaction) {
      case '🚀':
        return 'Bullish';
      case '💡':
        return 'Insightful';
      case '🔥':
        return 'Fire';
      case '❤️':
        return 'Love';
      case '👍':
      default:
        return 'Like';
    }
  }

  Color _reactionColor(String? reaction, UiTheme theme) {
    switch (reaction) {
      case '🚀':
        return theme.colors.success;
      case '💡':
        return theme.colors.warning;
      case '🔥':
        return theme.colors.danger;
      case '❤️':
        return theme.colors.danger;
      case '👍':
      default:
        return theme.colors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final comment = widget.comment;
    final author = comment.author;
    final verifiedColor = author.verifiedColor(theme);
    final isReplyingThis = widget.activeReplyingCommentId == comment.id;

    final double indentPadding = widget.indent > 0
        ? (widget.indent.clamp(1, 3) * context.sp(theme.spacing.md))
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(
        left: indentPadding,
        top: context.sp(theme.spacing.xxs),
        bottom: context.sp(theme.spacing.xs),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Visual thread line if indented
              if (widget.indent > 0) ...<Widget>[
                Container(
                  width: 2,
                  height: context.sz(36),
                  margin: EdgeInsets.only(right: context.sp(theme.spacing.xs)),
                  decoration: BoxDecoration(
                    color: theme.colors.border.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],

              // Author Avatar
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: widget.indent > 0 ? UiSize.xs : UiSize.sm,
                verified: author.verified,
                verifiedColor: verifiedColor,
                onTap: widget.onAuthorTap == null ? null : () => widget.onAuthorTap!(author),
              ),

              SizedBox(width: context.sp(theme.spacing.xs)),

              // Comment Bubble & Action Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ---- LinkedIn Rounded Bubble Card -----------------------
                    Container(
                      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
                      decoration: BoxDecoration(
                        color: theme.colors.surfaceMuted,
                        borderRadius: context.radius(theme.radii.md),
                        border: Border.all(
                          color: theme.colors.border.withValues(alpha: 0.6),
                          width: theme.borders.hairline,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Top Header: Name, Verified, Role, Sentiment, Headline, Time
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: context.sp(theme.spacing.xxs),
                                      runSpacing: 2,
                                      children: <Widget>[
                                        GestureDetector(
                                          onTap: widget.onAuthorTap == null
                                              ? null
                                              : () => widget.onAuthorTap!(author),
                                          child: Text(
                                            author.displayName,
                                            style: context.uiText.bodyStrong.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: context.fs(13),
                                              color: theme.colors.foreground,
                                            ),
                                          ),
                                        ),
                                        if (author.verified)
                                          Icon(
                                            Icons.verified_rounded,
                                            color: verifiedColor,
                                            size: context.sz(13),
                                          ),
                                        if (author.userRole != UserRole.customer)
                                          UiBadge(
                                            label: author.roleBadgeText,
                                            intent: author.userRole == UserRole.userAdmin
                                                ? UiIntent.danger
                                                : UiIntent.warning,
                                            variant: UiBadgeVariant.solid,
                                            size: UiSize.xs,
                                          ),
                                        if (comment.sentiment != null &&
                                            comment.sentiment!.trim().isNotEmpty)
                                          UiBadge(
                                            label: comment.sentiment!.toUpperCase(),
                                            intent: comment.sentiment!.toUpperCase() == 'BULLISH'
                                                ? UiIntent.success
                                                : (comment.sentiment!.toUpperCase() == 'BEARISH'
                                                    ? UiIntent.danger
                                                    : UiIntent.info),
                                            variant: UiBadgeVariant.soft,
                                            size: UiSize.xs,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    // Professional Trader Headline
                                    Text(
                                      _getTraderHeadline(author),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.uiText.caption.copyWith(
                                        color: theme.colors.foregroundMuted,
                                        fontSize: context.fs(11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                AppTokens.relativeTime(comment.createdAt),
                                style: context.uiText.caption.copyWith(
                                  color: theme.colors.foregroundSubtle,
                                  fontSize: context.fs(11),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: context.sp(theme.spacing.xs)),

                          // Body Text with Tag Highlighting
                          CommunityHighlightedText(
                            text: comment.body,
                            style: context.uiText.body.copyWith(
                              fontSize: context.fs(13),
                              height: 1.4,
                              color: theme.colors.foreground,
                            ),
                            onTagTap: widget.onTagTap,
                          ),
                        ],
                      ),
                    ),

                    // ---- LinkedIn Reactions & Reply Action Bar -----------------
                    Padding(
                      padding: EdgeInsets.only(
                        top: context.sp(theme.spacing.xxs),
                        left: context.sp(theme.spacing.xs),
                      ),
                      child: Row(
                        children: <Widget>[
                          // Dynamic reaction summary badge if liked
                          if (comment.likes > 0) ...<Widget>[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xs),
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colors.surfaceHover,
                                borderRadius: context.radius(theme.radii.pill),
                                border: Border.all(
                                  color: theme.colors.border.withValues(alpha: 0.5),
                                  width: theme.borders.hairline,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    comment.displayReactions.join(' '),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${comment.likes}',
                                    style: context.uiText.caption.copyWith(
                                      fontSize: context.fs(11),
                                      fontWeight: FontWeight.w600,
                                      color: comment.liked
                                          ? theme.colors.primary
                                          : theme.colors.foregroundMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                          ],

                          // Interactive Like / Reaction Button
                          InkWell(
                            onTap: () => widget.onLike(comment.id),
                            borderRadius: context.radius(theme.radii.sm),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xxs),
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  if (comment.liked &&
                                      comment.userReaction != null &&
                                      comment.userReaction != '👍') ...[
                                    Text(
                                      comment.userReaction!,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _reactionLabel(comment.userReaction),
                                      style: context.uiText.caption.copyWith(
                                        color: _reactionColor(comment.userReaction, theme),
                                        fontWeight: FontWeight.w700,
                                        fontSize: context.fs(11),
                                      ),
                                    ),
                                  ] else ...[
                                    Icon(
                                      comment.liked
                                          ? Icons.thumb_up_rounded
                                          : Icons.thumb_up_alt_outlined,
                                      size: context.sz(13),
                                      color: comment.liked
                                          ? theme.colors.primary
                                          : theme.colors.foregroundMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Like',
                                      style: context.uiText.caption.copyWith(
                                        color: comment.liked
                                            ? theme.colors.primary
                                            : theme.colors.foregroundMuted,
                                        fontWeight:
                                            comment.liked ? FontWeight.w700 : FontWeight.w500,
                                        fontSize: context.fs(11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          SizedBox(width: context.sp(theme.spacing.sm)),

                          // Reply Button
                          InkWell(
                            onTap: () => widget.onStartReply(comment),
                            borderRadius: context.radius(theme.radii.sm),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: context.sp(theme.spacing.xxs),
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.reply_rounded,
                                    size: context.sz(13),
                                    color: theme.colors.foregroundMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Reply',
                                    style: context.uiText.caption.copyWith(
                                      color: theme.colors.foregroundMuted,
                                      fontSize: context.fs(11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Quick reaction emoji picker popup toggle
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Tooltip(
                            message: 'React with emoji',
                            child: InkWell(
                              onTap: () => setState(() => _showReactionPicker = !_showReactionPicker),
                              borderRadius: context.radius(theme.radii.sm),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                child: Icon(
                                  _showReactionPicker
                                      ? Icons.close_rounded
                                      : Icons.add_reaction_outlined,
                                  size: context.sz(13),
                                  color: _showReactionPicker
                                      ? theme.colors.primary
                                      : theme.colors.foregroundMuted,
                                ),
                              ),
                            ),
                          ),

                          if (_showReactionPicker) ...<Widget>[
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colors.surface,
                                borderRadius: context.radius(theme.radii.pill),
                                border: Border.all(
                                  color: theme.colors.border.withValues(alpha: 0.8),
                                  width: theme.borders.hairline,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.16),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: _availableReactions.map((r) {
                                  final emoji = r['emoji']!;
                                  final label = r['label']!;
                                  final isSelected = comment.liked && comment.userReaction == emoji;
                                  return Tooltip(
                                    message: label,
                                    child: InkWell(
                                      onTap: () {
                                        widget.onReact(comment.id, emoji);
                                        setState(() => _showReactionPicker = false);
                                      },
                                      borderRadius: context.radius(theme.radii.pill),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? theme.colors.primary.withValues(alpha: 0.16)
                                              : Colors.transparent,
                                          borderRadius: context.radius(theme.radii.pill),
                                        ),
                                        child: Text(
                                          emoji,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ---- Inline Threaded Reply Composer ---------------------
                    if (isReplyingThis) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      Container(
                        padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
                        decoration: BoxDecoration(
                          color: theme.colors.surface,
                          borderRadius: context.radius(theme.radii.sm),
                          border: Border.all(color: theme.colors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: UiInput(
                                controller: widget.replyCtrl,
                                hintText: 'Write a reply...',
                                size: UiSize.xs,
                                autofocus: true,
                              ),
                            ),
                            SizedBox(width: context.sp(theme.spacing.xs)),
                            UiIconButton(
                              icon: Icons.close,
                              size: UiSize.xs,
                              variant: UiVariant.ghost,
                              onPressed: widget.onCancelReply,
                            ),
                            SizedBox(width: context.sp(theme.spacing.xxs)),
                            UiButton(
                              label: 'Reply',
                              size: UiSize.xs,
                              loading: widget.submittingReply,
                              expandOnMobile: false,
                              onPressed: () => widget.onSubmitReply(comment.id, comment.author),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ---- Replies Toggle & Nested List ------------------------
                    if (comment.replies.isNotEmpty) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xs)),
                      InkWell(
                        onTap: () => setState(() => _repliesCollapsed = !_repliesCollapsed),
                        child: Row(
                          children: [
                            Icon(
                              _repliesCollapsed
                                  ? Icons.keyboard_arrow_right_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: context.sz(14),
                              color: theme.colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _repliesCollapsed
                                  ? 'Show ${comment.replies.length} ${comment.replies.length == 1 ? "reply" : "replies"}'
                                  : 'Hide replies',
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: context.fs(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_repliesCollapsed) ...[
                        for (final reply in comment.replies)
                          _LinkedInCommentTile(
                            comment: reply,
                            theme: theme,
                            activeReplyingCommentId: widget.activeReplyingCommentId,
                            replyCtrl: widget.replyCtrl,
                            submittingReply: widget.submittingReply,
                            onStartReply: widget.onStartReply,
                            onCancelReply: widget.onCancelReply,
                            onSubmitReply: widget.onSubmitReply,
                            onLike: widget.onLike,
                            onReact: widget.onReact,
                            onAuthorTap: widget.onAuthorTap,
                            onTagTap: widget.onTagTap,
                            indent: widget.indent + 1,
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getTraderHeadline(CommunityAuthor author) {
    if (author.bio != null && author.bio!.isNotEmpty) return author.bio!;
    if (author.userRole == UserRole.userAdmin) {
      return 'TraderHub Official Desk · Lead Market Strategist';
    }
    return '@${author.handle} · Quantitative Trader · TradeX Community';
  }
}
