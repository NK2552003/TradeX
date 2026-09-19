import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/auth/models/auth_user_role.dart';
import 'package:tradex/features/community/data/community_repository.dart';
import 'package:tradex/features/community/models/community_models.dart';
import 'package:tradex/features/community/presentation/widgets/community_widgets.dart';

/// Detailed tweet/post thread view with full engagement stats and reply tree.
class CommunityPostDetailView extends StatefulWidget {
  const CommunityPostDetailView({
    super.key,
    required this.post,
    required this.repository,
    required this.currentUser,
    this.onAuthorTap,
    this.onBack,
  });

  final CommunityPost post;
  final CommunityRepository repository;
  final CommunityAuthor currentUser;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final VoidCallback? onBack;

  @override
  State<CommunityPostDetailView> createState() =>
      _CommunityPostDetailViewState();
}

class _CommunityPostDetailViewState extends State<CommunityPostDetailView> {
  final TextEditingController _replyController = TextEditingController();
  bool _submittingReply = false;
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
    widget.repository.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _replyController.dispose();
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
    setState(() {
      _reposted = !_reposted;
      _reposts += _reposted ? 1 : -1;
    });
    widget.repository.toggleRepost(widget.post.id);
  }

  void _handleBookmark() {
    setState(() {
      _bookmarked = !_bookmarked;
    });
    widget.repository.toggleBookmark(widget.post.id);
  }

  void _handleShare() {
    Clipboard.setData(
      ClipboardData(text: 'https://tradex.io/post/${widget.post.id}'),
    );
    UiToast.show(
      context,
      title: 'Link Copied',
      message: 'Post link copied to clipboard.',
      intent: UiIntent.success,
    );
  }

  Future<void> _submitReply() async {
    final String text = _replyController.text.trim();
    if (text.isEmpty || _submittingReply) return;

    setState(() => _submittingReply = true);
    try {
      widget.repository.addComment(
        widget.post.id,
        text,
        author: widget.currentUser,
      );
      _replyController.clear();
      if (!mounted) return;
      UiToast.show(
        context,
        title: 'Reply Sent',
        message: 'Your reply was published to the thread.',
        intent: UiIntent.success,
      );
    } finally {
      if (mounted) setState(() => _submittingReply = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;
    final author = widget.post.author;
    final verifiedColor = author.verifiedColor(theme);
    final comments = widget.repository.commentsForPost(widget.post.id);

    return Scaffold(
      backgroundColor: theme.colors.background,
      appBar: AppBar(
        backgroundColor: theme.colors.surface,
        elevation: 0,
        leading: UiIconButton(
          icon: Icons.arrow_back_rounded,
          size: UiSize.sm,
          tooltip: 'Back to feed',
          onPressed: widget.onBack,
        ),
        title: Text(
          'Post',
          style: context.uiText.heading.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: theme.colors.border.withValues(alpha: 0.6),
            height: theme.borders.hairline,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          context.sp(isMobile ? theme.spacing.sm : theme.spacing.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // -----------------------------------------------------------------
            // Main Post Box
            // -----------------------------------------------------------------
            UiCard(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Author Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      UiAvatar(
                        name: author.displayName,
                        imageUrl: author.avatarUrl,
                        size: UiSize.lg,
                        verified: author.verified,
                        verifiedColor: verifiedColor,
                        onTap: widget.onAuthorTap == null
                            ? null
                            : () => widget.onAuthorTap!(author),
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
                                      fontSize: context.fs(15),
                                      color: theme.colors.foreground,
                                    ),
                                  ),
                                ),
                                if (author.verified) ...<Widget>[
                                  SizedBox(
                                    width: context.sp(theme.spacing.xxs),
                                  ),
                                  Icon(
                                    Icons.verified_rounded,
                                    color: verifiedColor,
                                    size: context.sz(16),
                                  ),
                                ],
                                if (author.userRole !=
                                    UserRole.customer) ...<Widget>[
                                  SizedBox(
                                    width: context.sp(theme.spacing.xxs),
                                  ),
                                  UiBadge(
                                    label: author.roleBadgeText,
                                    intent:
                                        author.userRole == UserRole.userAdmin
                                        ? UiIntent.danger
                                        : UiIntent.warning,
                                    variant: UiBadgeVariant.solid,
                                    size: UiSize.xs,
                                  ),
                                ],
                              ],
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
                      UiIconButton(
                        icon: Icons.more_horiz_rounded,
                        size: UiSize.xs,
                        tooltip: 'Post options',
                        onPressed: () {},
                      ),
                    ],
                  ),

                  // Large Post Body Text
                  SizedBox(height: context.sp(theme.spacing.md)),
                  CommunityHighlightedText(
                    text: widget.post.body,
                    style: context.uiText.body.copyWith(
                      fontSize: context.fs(16),
                      height: 1.5,
                      color: theme.colors.foreground,
                    ),
                  ),

                  // Embedded Setup (if any)
                  if (widget.post.tradeSetup != null) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.md)),
                    _detailSetupSnippet(context, widget.post.tradeSetup!),
                  ],

                  // Embedded Attachment (Note / Journal / Strategy)
                  if (widget.post.attachment != null) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.md)),
                    CommunityAttachmentTile(
                      attachment: widget.post.attachment!,
                      dense: isMobile,
                      onTap: () {
                        UiToast.show(
                          context,
                          title: widget.post.attachment!.source.title,
                          message:
                              'Opening attached ${widget.post.attachment!.kind.name}...',
                          intent: UiIntent.info,
                        );
                      },
                    ),
                  ],

                  // Tickers & Tags
                  if (widget.post.tickers.isNotEmpty ||
                      widget.post.tags.isNotEmpty) ...<Widget>[
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

                  // Timestamp & Views Row
                  SizedBox(height: context.sp(theme.spacing.md)),
                  Text(
                    '${_formatTimestamp(widget.post.createdAt)} · ${uiCompactNumber(widget.post.views)} Views',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                    ),
                  ),

                  // Divider
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiDivider(),
                  SizedBox(height: context.sp(theme.spacing.sm)),

                  // Detailed Metrics Bar (e.g. 32 Reposts, 148 Likes)
                  Row(
                    children: <Widget>[
                      _metricStat(
                        context,
                        uiCompactNumber(_reposts),
                        'Reposts',
                      ),
                      SizedBox(width: context.sp(theme.spacing.lg)),
                      _metricStat(context, uiCompactNumber(_likes), 'Likes'),
                      SizedBox(width: context.sp(theme.spacing.lg)),
                      _metricStat(
                        context,
                        uiCompactNumber(comments.length),
                        'Replies',
                      ),
                    ],
                  ),

                  // Divider
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  UiDivider(),

                  // Engagement Action Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      UiIconButton(
                        icon: Icons.chat_bubble_outline_rounded,
                        size: UiSize.sm,
                        tooltip: 'Reply',
                        onPressed: () {},
                      ),
                      UiIconButton(
                        icon: Icons.repeat_rounded,
                        size: UiSize.sm,
                        tooltip: 'Repost',
                        intent: _reposted ? UiIntent.success : UiIntent.neutral,
                        onPressed: _handleRepost,
                      ),
                      UiIconButton(
                        icon: _liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: UiSize.sm,
                        tooltip: 'Like',
                        intent: _liked ? UiIntent.danger : UiIntent.neutral,
                        onPressed: _handleLike,
                      ),
                      UiIconButton(
                        icon: _bookmarked
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: UiSize.sm,
                        tooltip: 'Bookmark',
                        intent: _bookmarked
                            ? UiIntent.warning
                            : UiIntent.neutral,
                        onPressed: _handleBookmark,
                      ),
                      UiIconButton(
                        icon: Icons.ios_share_rounded,
                        size: UiSize.sm,
                        tooltip: 'Share',
                        onPressed: _handleShare,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // Reply Composer Card
            // -----------------------------------------------------------------
            SizedBox(height: context.sp(theme.spacing.sm)),
            UiCard(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  UiAvatar(
                    name: widget.currentUser.displayName,
                    imageUrl: widget.currentUser.avatarUrl,
                    size: UiSize.sm,
                  ),
                  SizedBox(width: context.sp(theme.spacing.sm)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        UiInput(
                          controller: _replyController,
                          hintText: 'Post your reply...',
                          onSubmitted: (_) => _submitReply(),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xs)),
                        Row(
                          children: <Widget>[
                            const Spacer(),
                            UiButton(
                              label: 'Reply',
                              variant: UiVariant.primary,
                              size: UiSize.sm,
                              loading: _submittingReply,
                              expandOnMobile: false,
                              onPressed: _submitReply,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // Thread Comments List
            // -----------------------------------------------------------------
            SizedBox(height: context.sp(theme.spacing.md)),
            Text(
              'Replies (${comments.length})',
              style: context.uiText.heading.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            if (comments.isEmpty)
              Padding(
                padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
                child: Center(
                  child: Text(
                    'No replies yet. Be the first to start the discussion!',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              )
            else
              for (final c in comments)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.xs),
                  ),
                  child: CommunityCommentCard(
                    comment: c,
                    onLike: () =>
                        widget.repository.likeComment(widget.post.id, c.id),
                    onReply: () {
                      _replyController.text = '@${c.author.handle} ';
                    },
                    onAuthorTap: widget.onAuthorTap,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _metricStat(BuildContext context, String count, String label) {
    return Row(
      children: <Widget>[
        Text(
          count,
          style: context.uiText.bodyStrong.copyWith(
            color: context.uiColors.foreground,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
          ),
        ),
      ],
    );
  }

  Widget _detailSetupSnippet(BuildContext context, CommunityTradeSetup setup) {
    final UiTheme theme = context.ui;
    final isMobile = context.uiRes.isMobile;

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
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
              const Spacer(),
              if (setup.pnl != null)
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
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          Row(
            children: <Widget>[
              Expanded(child: _box(context, 'Entry', setup.entry)),
              if (setup.exit != null)
                Expanded(child: _box(context, 'Exit', setup.exit!)),
              if (setup.stopLoss != null)
                Expanded(child: _box(context, 'Stop Loss', setup.stopLoss!)),
              if (setup.target != null)
                Expanded(child: _box(context, 'Target', setup.target!)),
            ],
          ),
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
        ],
      ),
    );
  }

  Widget _box(BuildContext context, String label, String value) {
    final UiTheme theme = context.ui;
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
}

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
