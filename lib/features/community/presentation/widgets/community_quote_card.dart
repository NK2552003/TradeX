import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';

/// Concise boxed nested-post preview widget representing an attached/quoted post.
class CommunityQuoteCard extends StatelessWidget {
  const CommunityQuoteCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onOpenRef,
    this.onTagTap,
    this.maxBodyLines = 2,
  });

  final CommunityPost post;
  final VoidCallback? onTap;
  final ValueChanged<CommunityAuthor>? onAuthorTap;
  final ValueChanged<AppLinkRef>? onOpenRef;
  final ValueChanged<String>? onTagTap;
  final int maxBodyLines;

  /// Collapses markdown syntax and extra whitespace into a clean, single-block
  /// excerpt suitable for a concise nested post preview.
  static String conciseExcerpt(String raw) {
    if (raw.trim().isEmpty) return '';
    String text = raw;
    // Replace markdown links [label](url) with label
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^\)]+\)'),
      (Match m) => m.group(1) ?? '',
    );
    // Strip fenced code block markers
    text = text.replaceAll(RegExp(r'```[a-zA-Z0-9_-]*'), ' ');
    // Strip leading heading, quote, and list markers
    text = text.replaceAll(
      RegExp(r'(^|\n)\s*(?:#{1,6}\s+|>\s+|[-*+]\s+|\d+\.\s+)'),
      ' ',
    );
    // Strip inline bold/italic/code markers
    text = text.replaceAll(RegExp(r'[*_`~]+'), '');
    // Collapse all whitespace/newlines into single spaces
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static IconData _attachmentIcon(AppLinkKind kind) => switch (kind) {
    AppLinkKind.note => Icons.notes_rounded,
    AppLinkKind.journal => Icons.receipt_long_outlined,
    AppLinkKind.strategy => Icons.account_tree_outlined,
    _ => Icons.attach_file_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final CommunityAuthor author = post.author;
    final Color verifiedColor = author.verifiedColor(theme);
    final String timeAgo = AppTokens.relativeTime(post.createdAt);
    final String excerpt = conciseExcerpt(post.body);
    final bool hasImage =
        post.imageUrl != null && post.imageUrl!.trim().isNotEmpty;
    final CommunityTradeSetup? setup = post.tradeSetup;
    final AppWritingPostAttachment? attachment = post.attachment;
    final CommunityPoll? poll = post.poll;
    final bool hasMetaChips =
        setup != null || attachment != null || poll != null;

    return CommunityTile(
      key: ValueKey<String>('community-quote-card-${post.id}'),
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(theme.spacing.sm),
        vertical: context.sp(theme.spacing.xs) + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Compact single-line author header
          Row(
            children: <Widget>[
              UiAvatar(
                name: author.displayName,
                imageUrl: author.avatarUrl,
                size: UiSize.xs,
                verified: author.verified,
                verifiedColor: verifiedColor,
                onTap: onAuthorTap == null ? null : () => onAuthorTap!(author),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              Flexible(
                flex: 2,
                child: GestureDetector(
                  onTap: onAuthorTap == null
                      ? null
                      : () => onAuthorTap!(author),
                  child: Text(
                    author.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: context.fs(12),
                      color: theme.colors.foreground,
                    ),
                  ),
                ),
              ),
              if (author.verified) ...<Widget>[
                const SizedBox(width: 3),
                Icon(
                  Icons.verified_rounded,
                  color: verifiedColor,
                  size: context.sz(12.5),
                ),
              ],
              SizedBox(width: context.sp(theme.spacing.xxs)),
              Flexible(
                flex: 3,
                child: Text(
                  '${author.displayHandle} · $timeAgo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontSize: context.fs(11),
                  ),
                ),
              ),
              if (onTap != null) ...<Widget>[
                SizedBox(width: context.sp(theme.spacing.xxs)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: context.sz(14),
                  color: theme.colors.foregroundSubtle,
                ),
              ],
            ],
          ),

          // Concise body preview + optional compact right thumbnail
          if (excerpt.isNotEmpty || hasImage) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (excerpt.isNotEmpty)
                  Expanded(
                    child: Text(
                      excerpt,
                      maxLines: maxBodyLines,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body.copyWith(
                        fontSize: context.fs(12.5),
                        height: 1.35,
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ),
                if (hasImage) ...<Widget>[
                  if (excerpt.isNotEmpty)
                    SizedBox(width: context.sp(theme.spacing.sm)),
                  ClipRRect(
                    borderRadius: context.radius(theme.radii.sm),
                    child: SizedBox(
                      width: context.sz(48),
                      height: context.sz(48),
                      child: UiRemoteImage(
                        url: post.imageUrl!,
                        semanticLabel: 'Quoted image by @${author.handle}',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],

          // Concise metadata badges for setup, workspace attachment, or poll
          if (hasMetaChips) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Wrap(
              spacing: context.sp(theme.spacing.xs),
              runSpacing: context.sp(theme.spacing.xxs),
              children: <Widget>[
                if (setup != null)
                  UiBadge(
                    label: setup.pnl?.isNotEmpty == true
                        ? '${setup.ticker} · ${setup.side} · ${setup.pnl}'
                        : '${setup.ticker} · ${setup.side}',
                    intent: setup.isWin == null
                        ? UiIntent.primary
                        : (setup.isWin! ? UiIntent.success : UiIntent.danger),
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                if (attachment != null)
                  UiBadge(
                    label: attachment.source.title,
                    icon:
                        attachment.source.icon ??
                        _attachmentIcon(attachment.source.kind),
                    variant: UiBadgeVariant.outline,
                    size: UiSize.xs,
                    onTap: onOpenRef != null
                        ? () => onOpenRef!(
                            attachment.source.copyWith(isPublicContext: true),
                          )
                        : onTap,
                  ),
                if (poll != null)
                  UiBadge(
                    label: 'Poll · ${poll.options.length} options',
                    icon: Icons.poll_outlined,
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
}
