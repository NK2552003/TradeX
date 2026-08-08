import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

@immutable
class UiTimelineEntry {
  const UiTimelineEntry({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.icon,
    this.intent = UiIntent.primary,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? timestamp;
  final IconData? icon;
  final UiIntent intent;
  final Widget? trailing;
}

/// Vertical timeline: version history, activity log, audit trail.
class UiTimeline extends StatelessWidget {
  const UiTimeline({super.key, required this.entries, this.onTap});

  final List<UiTimelineEntry> entries;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < entries.length; i++)
          UiInteractive(
            onTap: onTap == null ? null : () => onTap!(i),
            builder: (BuildContext ctx, UiInteractiveState s) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Container(
                      width: ctx.sz(theme.sizes.iconLg),
                      height: ctx.sz(theme.sizes.iconLg),
                      decoration: BoxDecoration(
                        color: entries[i].intent.surface(ctx),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        entries[i].icon ?? Icons.circle,
                        size: ctx.sz(theme.sizes.iconSm),
                        color: entries[i].intent.color(ctx),
                      ),
                    ),
                    if (i != entries.length - 1)
                      Container(
                        width: theme.borders.hairline,
                        height: ctx.sz(34),
                        color: theme.colors.border,
                      ),
                  ],
                ),
                SizedBox(width: ctx.sp(theme.spacing.md)),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.lg)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(entries[i].title,
                                  style: ctx.uiText.bodyStrong),
                              if (entries[i].subtitle != null)
                                Text(
                                  entries[i].subtitle!,
                                  style: ctx.uiText.caption.copyWith(
                                    color: theme.colors.foregroundMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (entries[i].timestamp != null)
                          Text(
                            entries[i].timestamp!,
                            style: ctx.uiText.caption.copyWith(
                              color: theme.colors.foregroundSubtle,
                            ),
                          ),
                        if (entries[i].trailing != null) ...<Widget>[
                          SizedBox(width: ctx.sp(theme.spacing.sm)),
                          entries[i].trailing!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
