import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../models/app_models.dart';

/// Universal desk record card component — the unified card pattern for
/// Notes, Journal trades, and Strategy playbooks across TradeX.
///
/// Implements the two-part vertical flex layout:
/// - Top: Eyebrow header (accent dot + uppercase category + trailing action),
///   bold title (2-line clamp), and excerpt preview.
/// - Bottom: Domain badges wrap, hashtag chips wrap, and metadata/engagement footer.
class AppDeskRecordCard extends StatelessWidget {
  const AppDeskRecordCard({
    super.key,
    this.category,
    required this.title,
    this.accentColor,
    this.leadingDot = true,
    this.leadingIcon,
    this.trailingHeader,
    this.preview,
    this.showPreview = true,
    this.badges = const <Widget>[],
    this.tags = const <Widget>[],
    this.footerMetadata = const <Widget>[],
    this.footerEngagement,
    this.onTap,
    this.selected = false,
    this.density = AppNoteDensity.comfortable,
    this.minHeight,
    this.semanticLabel,
  });

  /// Category or record type shown in the eyebrow (e.g. 'NOTE · THESIS', 'TRADE · WIN', 'PLAYBOOK · LIVE').
  /// If null or empty, the eyebrow line is omitted unless a trailing header is present.
  final String? category;

  /// Accent color for the eyebrow dot and text (defaults to primary if null).
  final Color? accentColor;

  /// Whether to display the 8dp colored circle indicator before [category].
  final bool leadingDot;

  /// Optional icon to display before [category] instead of or in addition to the circle.
  final IconData? leadingIcon;

  /// Trailing widget on the header line (e.g. PnL text, public badge, favorite star, delete button).
  final Widget? trailingHeader;

  /// Record title (clamped to 2 lines max).
  final String title;

  /// Excerpt preview widget rendered underneath the title.
  final Widget? preview;

  /// Whether the excerpt preview is rendered (driven by density).
  final bool showPreview;

  /// Domain badges (e.g. outcome, R/R, tickers, strategy, linked items).
  final List<Widget> badges;

  /// Hashtag badges (e.g. #breakout, #scalp).
  final List<Widget> tags;

  /// Left-side footer items (e.g. relative time, word count, shares, checklist).
  final List<Widget> footerMetadata;

  /// Right-side footer engagement / social reach (views, likes, comments, post link).
  final Widget? footerEngagement;

  /// Callback when the card is pressed.
  final VoidCallback? onTap;

  /// Whether the card is visually selected.
  final bool selected;

  /// Information density setting.
  final AppNoteDensity density;

  /// Custom minimum card height override.
  final double? minHeight;

  /// Accessibility label.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color accent = accentColor ?? theme.colors.primary;

    final double effectiveMinHeight = minHeight ??
        context.sz(switch (density) {
          AppNoteDensity.titleOnly => 108,
          AppNoteDensity.comfortable => 140,
          AppNoteDensity.full => 182,
        });

    final Widget metadataWidget = Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xxs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: footerMetadata,
    );

    final Widget footerWidget = footerEngagement != null
        ? Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.xxs),
            children: <Widget>[
              metadataWidget,
              footerEngagement!,
            ],
          )
        : metadataWidget;

    return UiCard(
      onTap: onTap,
      variant: UiCardVariant.outlined,
      selected: selected,
      hoverLift: false,
      motion: false,
      minHeight: effectiveMinHeight,
      semanticLabel: semanticLabel ??
          ((category != null && category!.trim().isNotEmpty)
              ? '$category: $title'
              : title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // ── Top Section: Eyebrow header, title, and body preview ──────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Header row
              if ((category != null && category!.trim().isNotEmpty) ||
                  trailingHeader != null) ...<Widget>[
                Row(
                  children: <Widget>[
                    if (category != null && category!.trim().isNotEmpty) ...<Widget>[
                      if (leadingIcon != null)
                        Padding(
                          padding: EdgeInsets.only(
                            right: context.sp(theme.spacing.xs),
                          ),
                          child: Icon(
                            leadingIcon,
                            size: context.sz(14),
                            color: accent,
                          ),
                        )
                      else if (leadingDot)
                        Padding(
                          padding: EdgeInsets.only(
                            right: context.sp(theme.spacing.xs),
                          ),
                          child: Icon(
                            Icons.circle,
                            size: context.sz(8),
                            color: accent,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          category!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.uiText.label.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    ?trailingHeader,
                  ],
                ),
                SizedBox(height: context.sp(theme.spacing.xs)),
              ],

              // Title
              Text(
                title.trim().isEmpty ? 'Untitled' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.bodyStrong.copyWith(
                  color: title.trim().isEmpty
                      ? theme.colors.foregroundSubtle
                      : theme.colors.foreground,
                ),
              ),

              // Excerpt preview
              if (showPreview && preview != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xxs)),
                preview!,
              ],
            ],
          ),

          // ── Bottom Section: Badges, tags, and footer ──────────────────
          Padding(
            padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (badges.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    children: badges,
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                ],
                if (tags.isNotEmpty) ...<Widget>[
                  Wrap(
                    spacing: context.sp(theme.spacing.xxs),
                    runSpacing: context.sp(theme.spacing.xxs),
                    children: tags,
                  ),
                  SizedBox(height: context.sp(theme.spacing.xs)),
                ],
                footerWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable social reach and engagement stats row for card footers.
class AppDeskEngagementRow extends StatelessWidget {
  const AppDeskEngagementRow({
    super.key,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.isLinked = false,
  });

  final int views;
  final int likes;
  final int comments;
  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final TextStyle style = context.uiText.caption.copyWith(
      color: theme.colors.foregroundSubtle,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isLinked) ...<Widget>[
          Icon(
            Icons.share_rounded,
            size: context.sz(13),
            color: theme.colors.primary,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
        ],
        if (views > 0) ...<Widget>[
          Icon(
            Icons.visibility_outlined,
            size: context.sz(13),
            color: style.color,
          ),
          SizedBox(width: context.sp(theme.spacing.xxs)),
          Text('$views', style: style),
          SizedBox(width: context.sp(theme.spacing.xs)),
        ],
        Icon(
          Icons.favorite_border_rounded,
          size: context.sz(13),
          color: style.color,
        ),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        Text('$likes', style: style),
        SizedBox(width: context.sp(theme.spacing.xs)),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: context.sz(13),
          color: style.color,
        ),
        SizedBox(width: context.sp(theme.spacing.xxs)),
        Text('$comments', style: style),
      ],
    );
  }
}
