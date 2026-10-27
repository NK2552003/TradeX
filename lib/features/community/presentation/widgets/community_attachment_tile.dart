import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/community/presentation/widgets/community_design.dart';

/// The Writing-Desk record attachment tile for hejournal.in (hejournal.in).
///
/// Renders a linked note, trade-journal entry, or strategy playbook attached to
/// a community post (or previewed inside the composer). Built on the shared
/// [CommunityTile] base so its border, radius and hover match every other
/// community card. Tapping it is wired by the post card to open the underlying
/// record via `onOpenRef(attachment.source)`.
///
/// Layout: an accent kind-icon, the record title with an optional primary-ticker
/// badge, a classification subtitle, a markdown-stripped excerpt, and — in the
/// full (non-dense) view — a metadata bar (visibility, media, tags, updated).
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
    final bool isDense = dense || context.uiRes.isMobile;

    final AppLinkRef source = attachment.source;
    final Color accent = (source.intent ?? attachment.kind.intent).color(
      context,
    );

    return CommunityTile(
      onTap: onTap,
      background: c.surfaceMuted.withValues(alpha: 0.4),
      padding: EdgeInsets.all(
        context.sp(isDense ? theme.spacing.sm : theme.spacing.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Kind icon chip.
              Container(
                width: context.sz(isDense ? 28 : 34),
                height: context.sz(isDense ? 28 : 34),
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
                  size: context.sz(isDense ? 15 : 17),
                  color: accent,
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),

              // Title + classification subtitle.
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
                              color: c.foreground,
                            ),
                          ),
                        ),
                        if (attachment.primaryTicker != null) ...<Widget>[
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
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        source.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: c.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Optional unlink / remove affordance.
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

          // Excerpt preview.
          if (attachment.excerpt.isNotEmpty) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              attachment.excerpt,
              maxLines: isDense ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body.copyWith(
                color: c.foregroundMuted,
                height: 1.3,
              ),
            ),
          ],

          // Metadata bar (full view only).
          if (!isDense) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.sm)),
            Row(
              children: <Widget>[
                UiBadge(
                  label: attachment.isPublic ? 'Public' : 'Private',
                  intent: attachment.isPublic
                      ? UiIntent.success
                      : UiIntent.neutral,
                  variant: UiBadgeVariant.outline,
                  size: UiSize.xs,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                if (attachment.hasMedia) ...<Widget>[
                  Icon(
                    Icons.photo_library_outlined,
                    size: context.sz(theme.sizes.iconXs),
                    color: c.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    'Media',
                    style: context.uiText.caption.copyWith(
                      color: c.foregroundSubtle,
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                if (attachment.tags.isNotEmpty) ...<Widget>[
                  Flexible(
                    child: Text(
                      attachment.tags.map((t) => '#$t').take(2).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: c.foregroundSubtle,
                      ),
                    ),
                  ),
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                const Spacer(),
                Text(
                  AppTokens.relativeTime(attachment.updatedAt),
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundSubtle,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
