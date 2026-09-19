import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

/// The signature Writing Desk record attachment tile for TraderHub (TradeX).
///
/// Renders a linked note, trade journal entry, or strategy playbook attached to a
/// community post or previewed inside the post composer.
///
/// Follows the canonical [AppLinkRefTile] language with rich metadata:
/// - Distinct accent color and icon per record kind (note, journal, strategy).
/// - Title and record classification subtitle.
/// - Markdown-stripped excerpt preview.
/// - Meta tags: primary ticker badge, visibility status, media indicator, and relative update time.
/// - Desktop (full card with excerpt) vs. Mobile / dense row.
class CommunityAttachmentTile extends StatelessWidget {
  const CommunityAttachmentTile({
    super.key,
    required this.attachment,
    this.onTap,
    this.onRemove,
    this.dense = false,
  });

  final AppWritingPostAttachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final bool isMobile = context.uiRes.isMobile;
    final bool isDense = dense || isMobile;

    final AppLinkRef source = attachment.source;
    final Color accent = (source.intent ?? attachment.kind.intent).color(
      context,
    );
    final String timeAgo = AppTokens.relativeTime(attachment.updatedAt);

    return AppHoverLift(
      enabled: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colors.surfaceMuted.withValues(alpha: 0.5),
          borderRadius: context.radius(theme.radii.md),
          border: Border.all(
            color: theme.colors.border.withValues(alpha: 0.7),
            width: theme.borders.hairline,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: context.radius(theme.radii.md),
            child: Padding(
              padding: EdgeInsets.all(
                context.sp(isDense ? theme.spacing.sm : theme.spacing.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Top Row: Icon + Title & Subtitle + Remove / Action
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      // Kind icon container
                      Container(
                        width: context.sz(isDense ? 30 : 36),
                        height: context.sz(isDense ? 30 : 36),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: context.radius(theme.radii.sm),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.28),
                            width: theme.borders.hairline,
                          ),
                        ),
                        child: Icon(
                          source.effectiveIcon,
                          size: context.sz(isDense ? 15 : 18),
                          color: accent,
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Flexible(
                                  child: Text(
                                    source.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.uiText.bodyStrong.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: context.fs(isDense ? 13 : 14),
                                      color: c.foreground,
                                    ),
                                  ),
                                ),
                                if (attachment.primaryTicker !=
                                    null) ...<Widget>[
                                  SizedBox(width: context.sp(theme.spacing.xs)),
                                  UiBadge(
                                    label: '\$${attachment.primaryTicker}',
                                    intent: UiIntent.primary,
                                    variant: UiBadgeVariant.soft,
                                    size: UiSize.xs,
                                  ),
                                ],
                              ],
                            ),
                            if (source.subtitle != null &&
                                source.subtitle!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                source.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.uiText.caption.copyWith(
                                  color: c.foregroundMuted,
                                  fontSize: context.fs(11),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Optional Unlink / Remove button
                      if (onRemove != null) ...<Widget>[
                        SizedBox(width: context.sp(theme.spacing.xs)),
                        UiIconButton(
                          icon: Icons.close_rounded,
                          size: UiSize.xs,
                          tooltip: 'Remove attachment',
                          onPressed: onRemove,
                        ),
                      ],
                    ],
                  ),

                  // Excerpt Preview (Desktop full, compact on mobile if not empty)
                  if (attachment.excerpt.isNotEmpty) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Text(
                      attachment.excerpt,
                      maxLines: isDense ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.body.copyWith(
                        color: c.foregroundMuted,
                        fontSize: context.fs(isDense ? 12 : 13),
                        height: 1.35,
                      ),
                    ),
                  ],

                  // Bottom Metadata Bar (Desktop full card view)
                  if (!isDense) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.xs)),
                    Row(
                      children: <Widget>[
                        // Visibility Chip
                        UiBadge(
                          label: attachment.isPublic ? 'Public' : 'Private',
                          intent: attachment.isPublic
                              ? UiIntent.success
                              : UiIntent.neutral,
                          variant: UiBadgeVariant.outline,
                          size: UiSize.xs,
                        ),
                        SizedBox(width: context.sp(theme.spacing.xs)),

                        // Media Indicator
                        if (attachment.hasMedia) ...<Widget>[
                          Icon(
                            Icons.photo_library_outlined,
                            size: context.sz(13),
                            color: c.foregroundSubtle,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xxs)),
                          Text(
                            'Media',
                            style: context.uiText.caption.copyWith(
                              color: c.foregroundSubtle,
                              fontSize: context.fs(11),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                        ],

                        // Tags
                        if (attachment.tags.isNotEmpty) ...<Widget>[
                          Flexible(
                            child: Text(
                              attachment.tags
                                  .map((t) => '#$t')
                                  .take(2)
                                  .join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                color: c.foregroundSubtle,
                                fontSize: context.fs(11),
                              ),
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                        ],

                        const Spacer(),

                        // Relative timestamp
                        Text(
                          timeAgo,
                          style: context.uiText.caption.copyWith(
                            color: c.foregroundSubtle,
                            fontSize: context.fs(11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
