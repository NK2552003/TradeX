import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

/// Floating pill button displayed directly below the feed toggle tabs when
/// newly published posts are available to fetch without refreshing the page.
class CommunityNewPostsPill extends StatelessWidget {
  const CommunityNewPostsPill({
    super.key,
    required this.count,
    required this.onTap,
    this.authors = const <CommunityAuthor>[],
    this.isLoading = false,
  });

  final int count;
  final VoidCallback onTap;
  final List<CommunityAuthor> authors;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !isLoading) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final Color bg = theme.colors.primary;
    final Color fg = theme.colors.onPrimary;
    final List<CommunityAuthor> visibleAuthors = authors.take(3).toList();
    final String label = '$count new ${count == 1 ? 'post' : 'posts'}';
    final double avatarSize = context.sz(22);
    final double overlap = context.sz(14);

    final Widget leading = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.arrow_upward_rounded, size: context.sz(16), color: fg),
        if (visibleAuthors.isNotEmpty) ...<Widget>[
          SizedBox(width: context.sp(theme.spacing.xs)),
          SizedBox(
            width: avatarSize + (visibleAuthors.length - 1) * overlap,
            height: avatarSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                for (int i = 0; i < visibleAuthors.length; i++)
                  Positioned(
                    left: i * overlap,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: bg, width: 1.5),
                      ),
                      child: ClipOval(
                        child: UiAvatar(
                          name: visibleAuthors[i].displayName,
                          imageUrl: visibleAuthors[i].avatarUrl,
                          size: UiSize.xs,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );

    final double scaledFont = MediaQuery.textScalerOf(
      context,
    ).scale(context.fs(13));
    final double pillHeight = math.max(44.0, scaledFont + 18.0);

    return Center(
      child: UiButton(
        label: label,
        loading: isLoading,
        loadingLabel: 'Loading new posts...',
        onPressed: isLoading ? null : onTap,
        variant: UiVariant.primary,
        size: UiSize.sm,
        rounded: true,
        elevate: true,
        leading: leading,
        semanticLabel: 'Load $label',
        style: UiButtonStyle(
          height: pillHeight,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
          ),
          textStyle: context.uiText.bodyStrong.copyWith(
            fontSize: context.fs(13),
            fontWeight: FontWeight.w700,
          ),
          shadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      ),
    );
  }
}
