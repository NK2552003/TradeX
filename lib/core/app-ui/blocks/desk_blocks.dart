import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// Primitive layer is used directly for UiDataPanel / UiInteractive / tokens.
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

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
            Expanded(child: Text(title, style: context.uiText.heading)),
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
/// centred, ported from the QuietNote home surface into alphajournal tokens.
///
/// Days carrying activity can be flagged via [markers] (compared by calendar
/// day) so the reader can see where their notes and trades live before tapping.
class AppWeekStrip extends StatefulWidget {
  const AppWeekStrip({
    super.key,
    required this.selected,
    required this.onSelect,
    this.markers = const <DateTime>{},
    this.coloredMarkers,
    this.daysBefore = 7,
    this.daysAfter = 27,
  });

  /// The active day (compared by calendar day, not exact time).
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  /// Calendar days that should show an activity dot.
  final Set<DateTime> markers;

  /// Optional map of calendar day to list of activity dot colors (e.g. note, trade, strategy).
  final Map<DateTime, List<Color>>? coloredMarkers;

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
  late Map<DateTime, List<Color>> _coloredMap;

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
    if (oldWidget.markers != widget.markers ||
        oldWidget.coloredMarkers != widget.coloredMarkers) {
      _rebuildMarkers();
    }
  }

  void _rebuildMarkers() {
    _markerDays = widget.markers.map(AppTokens.dateOnly).toSet();
    _coloredMap = <DateTime, List<Color>>{};
    if (widget.coloredMarkers != null) {
      widget.coloredMarkers!.forEach((DateTime key, List<Color> colors) {
        _coloredMap[AppTokens.dateOnly(key)] = colors;
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Chip geometry, resolved from tokens so the whole strip rescales per device.
  double _itemWidth(BuildContext context) =>
      context.sz(48) * (MediaQuery.textScalerOf(context).scale(14) / 14);
  double _itemMargin(BuildContext context) =>
      context.sp(context.ui.spacing.xxs);
  double _stripHeight(BuildContext context) =>
      context.sz(64) * (MediaQuery.textScalerOf(context).scale(14) / 14);

  void _scrollToSelected({required bool animate}) {
    if (!_scrollCtrl.hasClients || !mounted) return;
    final int index = _days.indexWhere(
      (DateTime d) => AppTokens.isSameDay(d, widget.selected),
    );
    if (index == -1) return;
    final double total = _itemWidth(context) + _itemMargin(context) * 2;
    final double viewport = _scrollCtrl.position.viewportDimension;
    final double target = (index * total) - (viewport / 2) + (total / 2);
    final double clamped = target.clamp(
      0.0,
      _scrollCtrl.position.maxScrollExtent,
    );
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
          final List<Color>? dayDots = _coloredMap[d];
          final bool hasCustomDots = dayDots != null && dayDots.isNotEmpty;
          final bool hasMarker = hasCustomDots || _markerDays.contains(d);

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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.uiText.caption.copyWith(
                      color: dowColor,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
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
                  SizedBox(
                    height: context.sz(4),
                    child: hasCustomDots
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              for (
                                int dotIdx = 0;
                                dotIdx < dayDots.length && dotIdx < 3;
                                dotIdx++
                              ) ...<Widget>[
                                if (dotIdx > 0) SizedBox(width: context.sz(2)),
                                Container(
                                  width: context.sz(4),
                                  height: context.sz(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? c.onPrimary
                                        : dayDots[dotIdx],
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Container(
                            width: context.sz(4),
                            height: context.sz(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasMarker
                                  ? (isSelected ? c.onPrimary : c.primary)
                                  : Colors.transparent,
                            ),
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
        ? (links.length < 2 ? links.length : 2)
        : (links.length < 4 ? links.length : 4);

    final List<List<AppQuickLink>> rows = <List<AppQuickLink>>[
      for (int i = 0; i < links.length; i += cols)
        links.sublist(
          i,
          (i + cols) > links.length ? links.length : (i + cols),
        ),
    ];

    return UiDataPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int rowIndex = 0; rowIndex < rows.length; rowIndex++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (
                    int colIndex = 0;
                    colIndex < rows[rowIndex].length;
                    colIndex++
                  )
                    Expanded(
                      child: _QuickLinkCell(
                        link: rows[rowIndex][colIndex],
                        // Internal hairlines only: a left rule for any cell that
                        // isn't starting a row, a top rule for any cell past the
                        // first row. Overlaps read as a single grid line.
                        showLeftRule: colIndex != 0,
                        showTopRule: rowIndex != 0,
                        color: c,
                      ),
                    ),
                ],
              ),
            ),
        ],
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
    final BorderSide rule = BorderSide(
      color: color.border,
      width: theme.borders.hairline,
    );

    return UiInteractive(
      onTap: link.onTap,
      semanticLabel: '${link.label}: ${link.value}',
      builder: (BuildContext context, UiInteractiveState state) {
        return AnimatedContainer(
          duration: theme.motion.fast,
          curve: theme.motion.curve,
          constraints: const BoxConstraints(minHeight: 44),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.sm),
          ),
          decoration: BoxDecoration(
            color: state.hovered
                ? color.surfaceHover
                : color.surfaceHover.withValues(alpha: 0.0),
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

// ─────────────────────────────────────────────────────────────────────────────
// Workspace calendar controls: Bar, Month Calendar, and Carousel
// ─────────────────────────────────────────────────────────────────────────────

/// Header above the workspace calendar strip / month grid that displays the
/// focused month/year label, a "Today" quick jump button, and a view toggler
/// between the 7-day horizontal strip and the full month grid.
class AppWorkspaceCalendarBar extends StatelessWidget {
  const AppWorkspaceCalendarBar({
    super.key,
    required this.selectedDay,
    required this.isMonthView,
    required this.onToggleView,
    required this.onJumpToday,
  });

  final DateTime selectedDay;
  final bool isMonthView;
  final ValueChanged<bool> onToggleView;
  final VoidCallback onJumpToday;

  static const List<String> _fullMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isToday = AppTokens.isSameDay(selectedDay, DateTime.now());
    final String monthLabel =
        '${_fullMonths[selectedDay.month - 1]} ${selectedDay.year}';

    final Widget leftSide = Wrap(
      spacing: context.sp(theme.spacing.xs),
      runSpacing: context.sp(theme.spacing.xxs),
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.calendar_today_rounded,
              size: context.sz(theme.sizes.iconSm),
              color: theme.colors.primary,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
            Flexible(
              child: Text(
                monthLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.bodyStrong.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (!isToday)
          UiButton(
            label: 'Today',
            variant: UiVariant.ghost,
            size: UiSize.xs,
            expandOnMobile: false,
            leadingIcon: Icons.my_location_rounded,
            onPressed: onJumpToday,
          ),
      ],
    );

    final Widget toggle = UiToggleGroup<bool>(
      value: isMonthView,
      size: UiSize.xs,
      onChanged: onToggleView,
      options: const <UiToggleOption<bool>>[
        UiToggleOption<bool>(
          value: false,
          label: 'Week',
          icon: Icons.view_week_outlined,
        ),
        UiToggleOption<bool>(
          value: true,
          label: 'Month',
          icon: Icons.calendar_month_outlined,
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: leftSide),
        SizedBox(width: context.sp(theme.spacing.xs)),
        toggle,
      ],
    );
  }
}

/// Month view calendar grid displaying colored activity dots under each day.
class AppWorkspaceMonthCalendar extends StatefulWidget {
  const AppWorkspaceMonthCalendar({
    super.key,
    required this.selected,
    required this.onSelect,
    this.coloredMarkers = const <DateTime, List<Color>>{},
  });

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final Map<DateTime, List<Color>> coloredMarkers;

  @override
  State<AppWorkspaceMonthCalendar> createState() =>
      _AppWorkspaceMonthCalendarState();
}

class _AppWorkspaceMonthCalendarState extends State<AppWorkspaceMonthCalendar> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _displayedMonth = DateTime(widget.selected.year, widget.selected.month);
  }

  @override
  void didUpdateWidget(covariant AppWorkspaceMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected.month != widget.selected.month ||
        oldWidget.selected.year != widget.selected.year) {
      _displayedMonth = DateTime(widget.selected.year, widget.selected.month);
    }
  }

  static const List<String> _weekdays = <String>[
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
    'Su',
  ];

  static const List<String> _fullMonths = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final UiColors c = theme.colors;
    final DateTime today = AppTokens.dateOnly(DateTime.now());

    final DateTime firstDayOfMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month,
      1,
    );
    final int daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final int leadingEmptyDays = (firstDayOfMonth.weekday - 1) % 7;

    final Map<DateTime, List<Color>> normalizedMarkers =
        <DateTime, List<Color>>{};
    widget.coloredMarkers.forEach((DateTime key, List<Color> val) {
      normalizedMarkers[AppTokens.dateOnly(key)] = val;
    });

    return UiCard(
      variant: UiCardVariant.surface,
      padding: EdgeInsets.all(context.sp(theme.spacing.sm)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Month navigation bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              UiIconButton(
                icon: Icons.chevron_left_rounded,
                size: UiSize.sm,
                tooltip: 'Previous month',
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month - 1,
                  );
                }),
              ),
              Text(
                '${_fullMonths[_displayedMonth.month - 1]} ${_displayedMonth.year}',
                style: context.uiText.bodyStrong,
              ),
              UiIconButton(
                icon: Icons.chevron_right_rounded,
                size: UiSize.sm,
                tooltip: 'Next month',
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month + 1,
                  );
                }),
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
          // Weekday initials
          Row(
            children: <Widget>[
              for (final String day in _weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: context.uiText.caption.copyWith(
                        color: c.foregroundMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
          // Calendar days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyDays + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.15,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemBuilder: (BuildContext ctx, int index) {
              if (index < leadingEmptyDays) {
                return const SizedBox.shrink();
              }
              final int dayNum = index - leadingEmptyDays + 1;
              final DateTime date = DateTime(
                _displayedMonth.year,
                _displayedMonth.month,
                dayNum,
              );
              final bool isSelected = AppTokens.isSameDay(
                date,
                widget.selected,
              );
              final bool isCurrentDay = AppTokens.isSameDay(date, today);
              final List<Color>? dots = normalizedMarkers[date];
              final bool hasDots = dots != null && dots.isNotEmpty;

              final Color textColor = isSelected
                  ? c.onPrimary
                  : isCurrentDay
                  ? c.primary
                  : c.foreground;

              return UiInteractive(
                onTap: () => widget.onSelect(date),
                builder: (BuildContext itemCtx, UiInteractiveState state) {
                  return AnimatedContainer(
                    duration: theme.motion.fast,
                    curve: theme.motion.curve,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? c.primary
                          : state.hovered
                          ? c.surfaceHover
                          : Colors.transparent,
                      borderRadius: context.radius(theme.radii.sm),
                      border: isCurrentDay && !isSelected
                          ? Border.all(
                              color: c.borderStrong,
                              width: theme.borders.hairline,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '$dayNum',
                          style: context.uiText.caption.copyWith(
                            color: textColor,
                            fontWeight: isSelected || isCurrentDay
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.xxs)),
                        SizedBox(
                          height: context.sz(4),
                          child: hasDots
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    for (
                                      int d = 0;
                                      d < dots.length && d < 3;
                                      d++
                                    ) ...<Widget>[
                                      if (d > 0) SizedBox(width: context.sz(2)),
                                      Container(
                                        width: context.sz(4),
                                        height: context.sz(4),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? c.onPrimary
                                              : dots[d],
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Responsive horizontal card carousel for the Writing Desk.
///
/// Lays out max 6 items:
/// - Desktop: 3 cards per page
/// - Tablet: 2 cards per page
/// - Mobile: 1 card per page
///
/// Features Left and Right arrow buttons to flip pages with smooth animated transitions.
/// Responsive horizontal card carousel for the Writing Desk.
///
/// Lays out max 6 items:
/// - Desktop: 3 cards visible per view
/// - Tablet: 2 cards visible per view
/// - Mobile: 1 card visible per view
///
/// Features fluid horizontal touch/drag/trackpad scrolling, snapping,
/// and Left & Right arrow buttons to smoothly slide across pages.
class AppWorkspaceSectionCarousel extends StatefulWidget {
  const AppWorkspaceSectionCarousel({
    super.key,
    required this.cards,
    this.maxCards = 6,
    this.height,
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.emptyPlaceholder,
  });

  final List<Widget> cards;
  final int maxCards;
  final double? height;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Widget? emptyPlaceholder;

  @override
  State<AppWorkspaceSectionCarousel> createState() =>
      _AppWorkspaceSectionCarouselState();
}

class _AppWorkspaceSectionCarouselState
    extends State<AppWorkspaceSectionCarousel> {
  late final ScrollController _scrollController;
  int _currentPage = 0;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;
  double _lastWidth = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  int _calcColumns(BuildContext context) =>
      context.uiRes.pick<int>(mobile: 1, tablet: 2, desktop: 3);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    final bool canLeft = position.pixels > 4;
    final bool canRight = position.pixels < position.maxScrollExtent - 4;

    final int columns = _calcColumns(context);
    final double gap = context.sp(context.ui.spacing.md);
    final double cardWidth = _lastWidth > 0
        ? (_lastWidth - (columns - 1) * gap) / columns
        : 1.0;
    final double pageStep = (cardWidth + gap) * columns;
    final int page = pageStep > 0 ? (position.pixels / pageStep).round() : 0;

    if (canLeft != _canScrollLeft ||
        canRight != _canScrollRight ||
        page != _currentPage) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
        _currentPage = page;
      });
    }
  }

  void _scrollToPage(int page, double pageStep) {
    if (!_scrollController.hasClients) return;
    final double target = (page * pageStep).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final List<Widget> limited = widget.cards.take(widget.maxCards).toList();
    final bool isEmpty = limited.isEmpty;

    if (isEmpty && widget.title == null && widget.emptyPlaceholder == null) {
      return const SizedBox.shrink();
    }

    final int columns = _calcColumns(context);
    final int totalPages = isEmpty ? 0 : (limited.length / columns).ceil();
    final double gap = context.sp(theme.spacing.md);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        _lastWidth = width;
        final double cardWidth = (width - (columns - 1) * gap) / columns;
        final double pageStep = (cardWidth + gap) * columns;

        // Schedule check after layout in case scroll extent changed
        if (!isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_scrollController.hasClients) return;
            final ScrollPosition position = _scrollController.position;
            final bool canLeft = position.pixels > 4;
            final bool canRight =
                position.pixels < position.maxScrollExtent - 4;
            if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
              setState(() {
                _canScrollLeft = canLeft;
                _canScrollRight = canRight;
              });
            }
          });
        }

        Widget? carouselTrack;
        if (!isEmpty) {
          final double vertPad = context.sp(theme.spacing.sm);
          carouselTrack = SingleChildScrollView(
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(vertical: vertPad),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = 0; i < limited.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(width: cardWidth, child: limited[i]),
                  ],
                ],
              ),
            ),
          );

          // Allow desktop mouse click-and-drag as well as trackpad and touch
          carouselTrack = ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: <PointerDeviceKind>{
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
                PointerDeviceKind.stylus,
              },
            ),
            child: carouselTrack,
          );

          if (widget.height != null) {
            carouselTrack = SizedBox(
              height: widget.height! + vertPad * 2,
              child: carouselTrack,
            );
          }
        }

        Widget? paginationControls;
        if (totalPages > 1) {
          paginationControls = Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              UiBadge(
                label:
                    '${(_currentPage + 1).clamp(1, totalPages)} / $totalPages',
                size: UiSize.xs,
                variant: UiBadgeVariant.ghost,
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              UiIconButton(
                icon: Icons.chevron_left_rounded,
                size: UiSize.xs,
                tooltip: 'Previous cards',
                onPressed: _canScrollLeft || _currentPage > 0
                    ? () => _scrollToPage(_currentPage - 1, pageStep)
                    : null,
              ),
              SizedBox(width: context.sp(theme.spacing.xxs)),
              UiIconButton(
                icon: Icons.chevron_right_rounded,
                size: UiSize.xs,
                tooltip: 'Next cards',
                onPressed: _canScrollRight || _currentPage < totalPages - 1
                    ? () => _scrollToPage(_currentPage + 1, pageStep)
                    : null,
              ),
            ],
          );
        }

        Widget? headerWidget;
        if (widget.title != null) {
          final Widget identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (widget.icon != null) ...<Widget>[
                Icon(
                  widget.icon,
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
                      widget.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.uiText.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.subtitle != null) ...<Widget>[
                      SizedBox(height: context.sp(theme.spacing.xxs)),
                      Text(
                        widget.subtitle!,
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

          final bool isMobile = width < context.sz(520);
          if (isMobile) {
            headerWidget = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: identity),
                    if (paginationControls != null) ...<Widget>[
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      paginationControls,
                    ],
                  ],
                ),
                if (widget.trailing != null) ...<Widget>[
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  SizedBox(width: double.infinity, child: widget.trailing!),
                ],
              ],
            );
          } else {
            headerWidget = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child: identity),
                if (paginationControls != null) ...<Widget>[
                  paginationControls,
                  SizedBox(width: context.sp(theme.spacing.sm)),
                ],
                if (widget.trailing != null) widget.trailing!,
              ],
            );
          }
        }

        final List<Widget> children = <Widget>[];

        if (headerWidget != null) {
          children.add(headerWidget);
          children.add(SizedBox(height: context.sp(theme.spacing.xs)));
        } else if (paginationControls != null) {
          children.add(
            Padding(
              padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xs)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[paginationControls],
              ),
            ),
          );
        }

        if (isEmpty) {
          if (widget.emptyPlaceholder != null) {
            children.add(widget.emptyPlaceholder!);
          }
        } else if (carouselTrack != null) {
          children.add(carouselTrack);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}
