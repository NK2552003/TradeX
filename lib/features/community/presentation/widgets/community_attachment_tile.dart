import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

/// A responsive preview of a linked Writing Desk record.
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
    final theme = context.ui;
    final source = attachment.source;
    final gap = context.sp(theme.spacing.sm);
    return UiCard(
      variant: UiCardVariant.subtle,
      onTap: onTap,
      semanticLabel: 'Open ${source.kind.name}: ${source.title}',
      padding: EdgeInsets.all(context.sp(theme.spacing.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UiCard(
                variant: UiCardVariant.surface,
                padding: EdgeInsets.all(gap),
                child: Icon(
                  source.effectiveIcon,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundMuted,
                ),
              ),
              UiGap.h(gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.bodyStrong,
                    ),
                    if (source.subtitle?.isNotEmpty == true) ...[
                      UiGap.v(context.sp(theme.spacing.xxs)),
                      Text(
                        source.subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: theme.colors.foregroundMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRemove != null)
                UiIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Remove attachment',
                  onPressed: onRemove,
                )
              else if (onTap != null)
                Icon(
                  Icons.arrow_outward_rounded,
                  size: context.sz(theme.sizes.iconSm),
                  color: theme.colors.foregroundSubtle,
                ),
            ],
          ),
          if (attachment.excerpt.isNotEmpty) ...[
            UiGap.v(gap),
            Text(
              attachment.excerpt,
              maxLines: dense ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: context.uiText.body.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
          UiGap.v(gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: context.sp(theme.spacing.xs),
                  runSpacing: context.sp(theme.spacing.xs),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    UiBadge(
                      label: attachment.isPublic ? 'Public' : 'Private',
                      intent: attachment.isPublic
                          ? UiIntent.success
                          : UiIntent.neutral,
                      variant: UiBadgeVariant.soft,
                      size: UiSize.xs,
                    ),
                    if (attachment.primaryTicker != null)
                      UiBadge(
                        label: '\$${attachment.primaryTicker}',
                        size: UiSize.xs,
                      ),
                    for (final tag in attachment.tags.take(dense ? 2 : 4))
                      UiBadge(
                        label: '#$tag',
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                    if (attachment.hasMedia)
                      const UiBadge(
                        label: 'Media',
                        size: UiSize.xs,
                        variant: UiBadgeVariant.outline,
                      ),
                  ],
                ),
              ),
              if (!dense) ...<Widget>[
                UiGap.h(context.sp(theme.spacing.sm)),
                Text(
                  'Updated ${AppTokens.relativeTime(attachment.updatedAt)}',
                  textAlign: TextAlign.end,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
