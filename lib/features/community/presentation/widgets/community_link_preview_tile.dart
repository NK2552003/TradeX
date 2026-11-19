import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';
import 'package:alphajournal/features/community/presentation/widgets/community_design.dart';

/// Reusable link preview card for external article and resource links in community posts.
class CommunityLinkPreviewTile extends StatelessWidget {
  const CommunityLinkPreviewTile({
    super.key,
    required this.preview,
    this.onTap,
  });

  final CommunityLinkPreview preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    return CommunityTile(
      onTap: onTap,
      background: theme.colors.surfaceMuted,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: context.radius(theme.radii.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header / Thumbnail simulation
            Container(
              height: context.sz(90),
              color: theme.colors.surface,
              alignment: Alignment.center,
              child: Stack(
                children: <Widget>[
                  Center(
                    child: Icon(
                      Icons.map_rounded,
                      size: context.sz(36),
                      color: theme.colors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  Positioned(
                    bottom: context.sp(theme.spacing.xs),
                    left: context.sp(theme.spacing.sm),
                    right: context.sp(theme.spacing.sm),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.sp(theme.spacing.xs),
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: context.radius(theme.radii.sm),
                      ),
                      child: Text(
                        preview.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.uiText.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: context.fs(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Description if available
            if (preview.description != null &&
                preview.description!.isNotEmpty) ...<Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.sp(theme.spacing.sm),
                  context.sp(theme.spacing.xs),
                  context.sp(theme.spacing.sm),
                  0,
                ),
                child: Text(
                  preview.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.caption.copyWith(
                    color: theme.colors.foregroundMuted,
                    fontSize: context.fs(11),
                  ),
                ),
              ),
            ],

            // Domain attribution footer
            Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.xs)),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.link_rounded,
                    size: context.sz(12),
                    color: theme.colors.foregroundSubtle,
                  ),
                  SizedBox(width: context.sp(theme.spacing.xxs)),
                  Text(
                    'From ${preview.domain}',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                      fontSize: context.fs(11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
