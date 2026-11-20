import 'package:flutter/material.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/features/community/models/community_models.dart';

/// Twitter/X-style floating pill showing `↑ [overlapping avatars] posted` when
/// new real-time posts arrive in the feed. Tapping refreshes & scrolls to top.
class CommunityNewPostsPill extends StatelessWidget {
  const CommunityNewPostsPill({
    super.key,
    required this.count,
    required this.onTap,
    this.authors = const <CommunityAuthor>[],
  });

  final int count;
  final VoidCallback onTap;
  final List<CommunityAuthor> authors;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final UiTheme theme = context.ui;
    final Color bg = theme.colors.primary;
    final Color fg = theme.colors.onPrimary;
    final List<CommunityAuthor> visibleAuthors = authors.take(3).toList();
    const double avatarSize = 24;
    const double overlap = 16;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.radius(theme.radii.pill),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: context.sp(theme.spacing.md),
              vertical: context.sp(theme.spacing.xs) + 1,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: context.radius(theme.radii.pill),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.32),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.arrow_upward_rounded,
                  size: context.sz(16),
                  color: fg,
                ),
                SizedBox(width: context.sp(theme.spacing.xs)),
                if (visibleAuthors.isNotEmpty) ...<Widget>[
                  SizedBox(
                    width:
                        avatarSize +
                        (visibleAuthors.length - 1) * overlap,
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
                                border: Border.all(color: bg, width: 1.8),
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
                  SizedBox(width: context.sp(theme.spacing.xs)),
                ],
                Text(
                  visibleAuthors.isNotEmpty
                      ? 'posted'
                      : '$count new ${count == 1 ? 'post' : 'posts'}',
                  style: context.uiText.bodyStrong.copyWith(
                    color: fg,
                    fontSize: context.fs(13),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
