import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

@immutable
class UiCrumb {
  const UiCrumb({required this.label, this.onTap, this.icon});

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
}

/// Breadcrumb trail (Journal / June 2026 / AAPL long).
///
/// A trail is written by whatever page hosts it, so any crumb can carry a title
/// as long as the reader made it. Two things keep that from tearing the layout:
/// every label truncates rather than pushing past its box, and on a phone the
/// middle of a long trail collapses to an ellipsis so the crumb that matters —
/// the one the reader is on — stays legible instead of being pushed off-screen.
class UiBreadcrumbs extends StatelessWidget {
  const UiBreadcrumbs({
    super.key,
    required this.crumbs,
    this.maxVisible,
    this.maxCrumbWidth,
  });

  final List<UiCrumb> crumbs;

  /// How many crumbs to show before collapsing the middle. Defaults to 2 on a
  /// phone and the whole trail on wider screens.
  final int? maxVisible;

  /// Ceiling on a single crumb's label before it ellipsises. Defaults to a
  /// readable fraction of the trail's own width.
  final double? maxCrumbWidth;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    if (crumbs.isEmpty) return const SizedBox.shrink();

    final int visible =
        maxVisible ?? (context.uiRes.isMobile ? 2 : crumbs.length);
    // Keep the first crumb as the way home and the tail as the current location,
    // dropping only the middle — a trail that loses its root is harder to escape.
    final bool collapsed = crumbs.length > visible && visible >= 2;
    final List<UiCrumb?> shown = collapsed
        ? <UiCrumb?>[
            crumbs.first,
            null, // the ellipsis standing in for what was dropped
            ...crumbs.sublist(crumbs.length - (visible - 1)),
          ]
        : List<UiCrumb?>.of(crumbs);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // Share the width between the crumbs rather than letting any one of them
        // claim all of it, leaving room for the separators.
        final double budget = constraints.maxWidth.isFinite
            ? (constraints.maxWidth / shown.length.clamp(1, 4)) -
                  context.sp(theme.spacing.lg)
            : double.infinity;
        final double cap =
            maxCrumbWidth ??
            (budget.isFinite ? budget.clamp(72.0, 320.0) : 320.0);

        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int i = 0; i < shown.length; i++) ...<Widget>[
              if (shown[i] == null)
                Text(
                  '…',
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundSubtle,
                  ),
                )
              else
                _Crumb(
                  crumb: shown[i]!,
                  isLast: i == shown.length - 1,
                  maxWidth: cap,
                ),
              if (i != shown.length - 1)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    size: context.sz(theme.sizes.iconSm),
                    color: theme.colors.foregroundSubtle,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({
    required this.crumb,
    required this.isLast,
    required this.maxWidth,
  });

  final UiCrumb crumb;
  final bool isLast;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiInteractive(
      onTap: crumb.onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (crumb.icon != null) ...<Widget>[
            Icon(
              crumb.icon,
              size: ctx.sz(theme.sizes.iconSm),
              color: theme.colors.foregroundMuted,
            ),
            SizedBox(width: ctx.sp(theme.spacing.xxs)),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ctx.sz(maxWidth)),
            child: Text(
              crumb.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: isLast
                  ? ctx.uiText.label
                  : ctx.uiText.label.copyWith(
                      color: s.hovered
                          ? theme.colors.primary
                          : theme.colors.foregroundMuted,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
