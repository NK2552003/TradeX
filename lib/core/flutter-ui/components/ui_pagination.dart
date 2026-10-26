import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_icon_button.dart';

/// Page navigation for long lists (saved posts, followers, audit logs).
class UiPagination extends StatelessWidget {
  const UiPagination({
    super.key,
    int? page,
    int? currentPage,
    int? pageCount,
    int? totalPages,
    ValueChanged<int>? onPageChanged,
    ValueChanged<int>? onChanged,
    this.totalLabel,
  }) : page =
           page ??
           (currentPage != null
               ? (currentPage > 0 ? currentPage - 1 : currentPage)
               : 0),
       pageCount = pageCount ?? totalPages ?? 1,
       _onPageChanged = onPageChanged ?? onChanged;

  /// Zero-based page index.
  final int page;
  final int pageCount;
  final ValueChanged<int>? _onPageChanged;
  ValueChanged<int> get onPageChanged => _onPageChanged ?? (_) {};
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool mobile = context.uiRes.isMobile;
    final List<int> pages = <int>[
      for (int i = 0; i < pageCount; i++)
        if (i == 0 ||
            i == pageCount - 1 ||
            (i - page).abs() <= (mobile ? 0 : 1))
          i,
    ];

    // 28pt was under the 44pt minimum a finger needs, which made the page numbers
    // the hardest thing on the list to hit. A mouse does not need the room, so the
    // desktop build keeps the compact chip.
    final double cell = mobile
        ? theme.sizes.minTapTarget
        : theme.sizes.controlHeightSm;

    // Centred while the strip fits, scrollable once it does not: a high page count
    // on a narrow phone otherwise runs the numbers off both edges at once.
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: context.sp(theme.spacing.xs)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            UiIconButton(
              icon: Icons.chevron_left,
              variant: UiVariant.ghost,
              tooltip: 'Previous',
              onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
            ),
            for (int i = 0; i < pages.length; i++) ...<Widget>[
              if (i > 0 && pages[i] - pages[i - 1] > 1)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.sp(theme.spacing.xs),
                  ),
                  child: Text(
                    '…',
                    style: context.uiText.caption.copyWith(
                      color: theme.colors.foregroundSubtle,
                    ),
                  ),
                ),
              UiInteractive(
                onTap: () => onPageChanged(pages[i]),
                builder: (BuildContext ctx, UiInteractiveState s) => Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: ctx.sp(theme.spacing.xxs),
                  ),
                  constraints: BoxConstraints(
                    minWidth: ctx.sz(cell),
                    minHeight: ctx.sz(cell),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: ctx.sp(theme.spacing.xxs),
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pages[i] == page
                        ? theme.colors.primary
                        : (s.hovered ? theme.colors.surfaceHover : null),
                    borderRadius: ctx.radius(theme.radii.md),
                  ),
                  child: Text(
                    '${pages[i] + 1}',
                    maxLines: 1,
                    style: ctx.uiText.label.copyWith(
                      color: pages[i] == page
                          ? theme.colors.onPrimary
                          : theme.colors.foregroundMuted,
                    ),
                  ),
                ),
              ),
            ],
            UiIconButton(
              icon: Icons.chevron_right,
              variant: UiVariant.ghost,
              tooltip: 'Next',
              onPressed: page < pageCount - 1
                  ? () => onPageChanged(page + 1)
                  : null,
            ),
            if (totalLabel != null && !mobile) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.md)),
              Text(
                totalLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: theme.colors.foregroundMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
