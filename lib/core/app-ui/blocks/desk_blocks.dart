import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// Primitive layer is used directly for UiDataPanel / UiInteractive / tokens.
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Reusable building blocks for the Writing Desk landing surface.
///
/// Everything here resolves size, spacing and colour from [UiTheme] /
/// [UiResponsive] and [AppTokens] — no literal dimensions or hex colours — so
/// the desk rescales for phones through large desktops and follows the system
/// light/dark preference automatically.

// ─────────────────────────────────────────────────────────────────────────────
// Masthead: eyebrow · (title + single trailing action) · description
// ─────────────────────────────────────────────────────────────────────────────

/// Editorial page masthead: a small tracked [eyebrow], a large [title] with an
/// optional [trailing] control pinned to its right (e.g. a dropdown icon
/// button), and a muted [description] underneath.
///
/// Distinct from [AppWorkspaceHeading], whose actions sit beside the whole text
/// block; here a single control rides the title line itself.
class AppWorkspaceMasthead extends StatelessWidget {
  const AppWorkspaceMasthead({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;

  /// A compact control aligned to the right of the title line.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: uiOverline(context, color: theme.colors.primary),
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: context.uiText.heading,
              ),
            ),
            if (trailing != null) ...<Widget>[
              SizedBox(width: context.sp(theme.spacing.sm)),
              trailing!,
            ],
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        Text(
          description,
          style: context.uiText.caption.copyWith(
            color: theme.colors.foregroundMuted,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header with a trailing control slot
// ─────────────────────────────────────────────────────────────────────────────

/// A lightweight in-page section header: [title] (+ optional [icon] and
/// [subtitle]) with a [trailing] control (a toggle group, a "View all" button)
/// that drops below the title on narrow widths instead of clipping.
class AppDeskSectionHeader extends StatelessWidget {
  const AppDeskSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Widget identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(
            icon,
            size: context.sz(theme.sizes.iconMd),
            color: theme.colors.foregroundMuted,
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.subheading.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xxs)),
                Text(
                  subtitle!,
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
      ],
    );

    if (trailing == null) return identity;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < context.sz(520)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              identity,
              SizedBox(height: context.sp(theme.spacing.sm)),
              Align(alignment: Alignment.centerLeft, child: trailing),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: identity),
            SizedBox(width: context.sp(theme.spacing.md)),
            // Natural width (no Flexible): a segmented toggle given a bounded
            // width would stretch to fill it instead of hugging its segments.
            trailing!,
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week strip: a horizontal 7-day-at-a-glance date selector
// ─────────────────────────────────────────────────────────────────────────────

/// A single horizontal row of date chips that scrolls to keep [selected]
/// centred, ported from the QuietNote home surface into TradeX tokens.
///
/// Days carrying activity can be flagged via [markers] (compared by calendar
/// day) so the reader can see where their notes and trades live before tapping.
class AppWeekStrip extends StatefulWidget {
  const AppWeekStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    this.markers = const <DateTime>{},
    this.daysBefore = 7,
    this.daysAfter = 27,
  });

  /// The active day (compared by calendar day, not exact time).
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Calendar days that should show an activity dot.
  final Set<DateTime> markers;

  /// How many days to render either side of today.
  final int daysBefore;
  final int daysAfter;

  @override
  State<AppWeekStrip> createState() => _AppWeekStripState();
}

class _AppWeekStripState extends State<AppWeekStrip> {
  final ScrollController _scrollCtrl = ScrollController();
  late List<DateTime> _days;
  late Set<DateTime> _markerDays;

  @override
  void initState() {
    super.initState();
    final DateTime today = AppTokens.dateOnly(DateTime.now());
    final DateTime start = today.subtract(Duration(days: widget.daysBefore));
    final int count = widget.daysBefore + widget.daysAfter + 1;
    _days = List<DateTime>.generate(
      count,
      (int i) => start.add(Duration(days: i)),
    );
    _rebuildMarkers();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToSelected(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant AppWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!AppTokens.isSameDay(oldWidget.selected, widget.selected)) {
      _scrollToSelected(animate: true);
    }
    if (oldWidget.markers != widget.markers) _rebuildMarkers();
  }

  void _rebuildMarkers() {
    _markerDays = widget.markers.map(AppTokens.dateOnly).toSet();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Chip geometry, resolved from tokens so the whole strip rescales per device.
  double _itemWidth(BuildContext context) => context.sz(48);
  double _itemMargin(BuildContext context) => context.sp(context.ui.spacing.xxs);
  double _stripHeight(BuildContext context) => context.sz(64);

  void _scrollToSelected({required bool animate}) {
    if (!_scrollCtrl.hasClients || !mounted) return;
    final int index =
        _days.indexWhere((DateTime d) => AppTokens.isSameDay(d, widget.selected));
    if (index == -1) return;
    final double total = _itemWidth(context) + _itemMargin(context) * 2;
    final double viewport = _scrollCtrl.position.viewportDimension;
    final double target =
        (index * total) - (viewport / 2) + (total / 2);
    final double clamped =
        target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    if (animate) {
      _scrollCtrl.animateTo(
        clamped,
        duration: context.ui.motion.normal,
        curve: context.ui.motion.curve,
      );
    } else {
      _scrollCtrl.jumpTo(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final DateTime today = AppTokens.dateOnly(DateTime.now());
    final double itemWidth = _itemWidth(context);
    final double margin = _itemMargin(context);

    return SizedBox(
      height: _stripHeight(context),
      child: ListView.builder(
        controller: _scrollCtrl,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _days.length,
        itemBuilder: (BuildContext context, int index) {
          final DateTime d = _days[index];
          final bool isSelected = AppTokens.isSameDay(d, widget.selected);
          final bool isToday = AppTokens.isSameDay(d, today);
          final bool hasMarker = _markerDays.contains(d);

          final Color dayColor = isSelected ? c.onPrimary : c.foreground;
          final Color dowColor = isSelected
              ? c.onPrimary.withValues(alpha: 0.8)
              : c.foregroundMuted;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onSelect(d),
            child: AnimatedContainer(
              duration: theme.motion.fast,
              curve: theme.motion.curve,
              width: itemWidth,
              margin: EdgeInsets.symmetric(horizontal: margin),
              decoration: BoxDecoration(
                color: isSelected ? c.primary : c.surface,
                borderRadius: context.radius(theme.radii.lg),
                border: Border.all(
                  color: isSelected
                      ? c.primary
                      : isToday
                          ? c.borderStrong
                          : c.border,
                  width: theme.borders.hairline,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    AppTokens.weekdayInitial(d),
                    style: context.uiText.caption.copyWith(
                      color: dowColor,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    '${d.day}',
                    style: context.uiText.bodyStrong.copyWith(color: dayColor),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  // Reserve the dot's row height at all times so day numbers
                  // stay vertically aligned whether or not a day is flagged.
                  Container(
                    width: context.sz(4),
                    height: context.sz(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasMarker
                          ? (isSelected ? c.onPrimary : c.primary)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick-link strip: hairline-celled, tappable navigation with a headline count
// ─────────────────────────────────────────────────────────────────────────────

/// One tappable destination inside an [AppQuickLinkStrip].
@immutable
class AppQuickLink {
  const AppQuickLink({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.intent = UiIntent.primary,
  });

  final IconData icon;

  /// The destination name, e.g. "Journal".
  final String label;

  /// The headline figure, e.g. "42".
  final String value;

  /// Optional qualifier under the value, e.g. "3 live".
  final String? hint;

  final UiIntent intent;
  final VoidCallback onTap;
}

/// A compact, single-row bank of quick links laid out like the calculator's
/// readout: hairline-separated cells inside one [UiDataPanel], each pairing a
/// headline figure with its destination and reflowing to fewer columns on
/// phones.
class AppQuickLinkStrip extends StatelessWidget {
  const AppQuickLinkStrip({super.key, required this.links});

  final List<AppQuickLink> links;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    if (links.isEmpty) return const SizedBox.shrink();

    final int cols = context.uiRes.isMobile
        ? (links.length < 3 ? links.length : 3)
        : (links.length < 4 ? links.length : 4);

    return UiDataPanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double cellWidth = constraints.maxWidth / cols;
          return Wrap(
            children: <Widget>[
              for (int i = 0; i < links.length; i++)
                SizedBox(
                  width: cellWidth,
                  child: _QuickLinkCell(
                    link: links[i],
                    // Internal hairlines only: a left rule for any cell that
                    // isn't starting a row, a top rule for any cell past the
                    // first row. Overlaps read as a single grid line.
                    showLeftRule: i % cols != 0,
                    showTopRule: i >= cols,
                    color: c,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickLinkCell extends StatelessWidget {
  const _QuickLinkCell({
    required this.link,
    required this.showLeftRule,
    required this.showTopRule,
    required this.color,
  });

  final AppQuickLink link;
  final bool showLeftRule;
  final bool showTopRule;
  final UiColors color;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final Color accent = link.intent.color(context);
    final BorderSide rule =
        BorderSide(color: color.border, width: theme.borders.hairline);

    return UiInteractive(
      onTap: link.onTap,
      semanticLabel: '${link.label}: ${link.value}',
      builder: (BuildContext context, UiInteractiveState state) {
        return AnimatedContainer(
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: state.hovered ? color.surfaceHover : Colors.transparent,
            border: Border(
              left: showLeftRule ? rule : BorderSide.none,
              top: showTopRule ? rule : BorderSide.none,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                link.icon,
                size: context.sz(theme.sizes.iconMd),
                color: accent,
              ),
              SizedBox(width: context.sp(theme.spacing.sm)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            link.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.bodyStrong,
                          ),
                        ),
                        if (link.hint != null) ...<Widget>[
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          Flexible(
                            child: Text(
                              link.hint!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                color: theme.colors.foregroundSubtle,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      link.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
