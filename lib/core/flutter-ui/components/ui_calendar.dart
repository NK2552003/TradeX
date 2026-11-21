import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';
import 'ui_icon_button.dart';

/// Month calendar grid. Single date or range selection, fully themed.
/// Supports Apple Crown-style wheel picker for instant year and month navigation.
class UiCalendar extends StatefulWidget {
  UiCalendar({
    super.key,
    this.selected,
    this.range,
    this.onDateSelected,
    this.onRangeSelected,
    this.firstDate,
    this.lastDate,
    this.rangeMode = false,
    Set<DateTime> markedDates = const <DateTime>{},
    Iterable<DateTime>? events,
    this.monthCount = 1,
  }) : markedDates = events != null ? events.toSet() : markedDates;

  final DateTime? selected;
  final DateTimeRange? range;
  final ValueChanged<DateTime>? onDateSelected;
  final ValueChanged<DateTimeRange>? onRangeSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool rangeMode;

  /// Days highlighted with a dot (earnings dates, events).
  final Set<DateTime> markedDates;

  /// Show several consecutive months at once (range pickers on wide screens).
  /// Falls back to a stacked layout on phones.
  final int monthCount;

  @override
  State<UiCalendar> createState() => _UiCalendarState();
}

class _UiCalendarState extends State<UiCalendar> {
  late DateTime _month = DateTime(
    (widget.selected ?? DateTime.now()).year,
    (widget.selected ?? DateTime.now()).month,
  );
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _isWheelPickerOpen = false;
  FixedExtentScrollController? _monthWheelController;
  FixedExtentScrollController? _yearWheelController;

  static const List<String> _weekdays = <String>[
    'Mo',
    'Tu',
    'We',
    'Th',
    'Fr',
    'Sa',
    'Su',
  ];
  static const List<String> _months = <String>[
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

  int get _firstYear => widget.firstDate?.year ?? 1940;
  int get _lastYear => widget.lastDate?.year ?? (DateTime.now().year + 10);
  int get _yearCount => (_lastYear - _firstYear + 1).clamp(1, 200);

  @override
  void initState() {
    super.initState();
    _rangeStart = widget.range?.start;
    _rangeEnd = widget.range?.end;
  }

  @override
  void dispose() {
    _monthWheelController?.dispose();
    _yearWheelController?.dispose();
    super.dispose();
  }

  void _toggleWheelPicker() {
    setState(() {
      _isWheelPickerOpen = !_isWheelPickerOpen;
      if (_isWheelPickerOpen) {
        _monthWheelController?.dispose();
        _yearWheelController?.dispose();
        _monthWheelController = FixedExtentScrollController(
          initialItem: _month.month - 1,
        );
        _yearWheelController = FixedExtentScrollController(
          initialItem: (_month.year - _firstYear).clamp(0, _yearCount - 1),
        );
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _disabled(DateTime day) {
    if (widget.firstDate != null && day.isBefore(widget.firstDate!)) {
      return true;
    }
    if (widget.lastDate != null && day.isAfter(widget.lastDate!)) {
      return true;
    }
    return false;
  }

  void _tap(DateTime day) {
    if (_disabled(day)) return;
    if (!widget.rangeMode) {
      widget.onDateSelected?.call(day);
      setState(() {});
      return;
    }
    setState(() {
      if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
        _rangeStart = day;
        _rangeEnd = null;
      } else if (day.isBefore(_rangeStart!)) {
        _rangeEnd = _rangeStart;
        _rangeStart = day;
      } else {
        _rangeEnd = day;
      }
    });
    if (_rangeStart != null && _rangeEnd != null) {
      widget.onRangeSelected?.call(
        DateTimeRange(start: _rangeStart!, end: _rangeEnd!),
      );
    }
  }

  String _label(DateTime m) => '${_months[m.month - 1]} ${m.year}';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final int count = widget.monthCount < 1 ? 1 : widget.monthCount;
    final bool stacked = context.uiRes.isMobile || count == 1;
    final List<DateTime> months = <DateTime>[
      for (int i = 0; i < count; i++) DateTime(_month.year, _month.month + i),
    ];

    Widget titled(DateTime m) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (count > 1) ...<Widget>[
          Text(
            _label(m),
            style: context.uiText.label.copyWith(color: c.foreground),
          ),
          SizedBox(height: context.sp(theme.spacing.xs)),
        ],
        _monthBody(context, m),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: stacked ? context.sz(380) : context.sz(360.0 * count),
      ),
      child: Container(
        padding: EdgeInsets.all(context.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: context.radius(theme.radii.xl),
          border: Border.all(color: c.border, width: theme.borders.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header: Switch between Crown Picker mode and Month Navigation mode
            if (_isWheelPickerOpen)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  UiButton(
                    label: 'This Month',
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    expandOnMobile: false,
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _month = DateTime(now.year, now.month);
                      });
                      _monthWheelController?.animateToItem(
                        now.month - 1,
                        duration: theme.motion.normal,
                        curve: Curves.easeOutCubic,
                      );
                      _yearWheelController?.animateToItem(
                        (now.year - _firstYear).clamp(0, _yearCount - 1),
                        duration: theme.motion.normal,
                        curve: Curves.easeOutCubic,
                      );
                    },
                  ),
                  UiButton(
                    label: 'Done',
                    variant: UiVariant.primary,
                    size: UiSize.sm,
                    expandOnMobile: false,
                    trailingIcon: Icons.check_rounded,
                    onPressed: () => setState(() => _isWheelPickerOpen = false),
                  ),
                ],
              )
            else
              Row(
                children: <Widget>[
                  UiIconButton(
                    icon: Icons.chevron_left,
                    size: UiSize.sm,
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month - 1),
                    ),
                  ),
                  Expanded(
                    child: UiInteractive(
                      onTap: _toggleWheelPicker,
                      builder: (BuildContext ctx, UiInteractiveState s) =>
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ctx.sp(theme.spacing.sm),
                              vertical: ctx.sp(theme.spacing.xxs),
                            ),
                            decoration: BoxDecoration(
                              color: s.hovered
                                  ? c.surfaceHover
                                  : Colors.transparent,
                              borderRadius: ctx.radius(theme.radii.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    count > 1
                                        ? '${_label(months.first)} – ${_label(months.last)}'
                                        : _label(months.first),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: ctx.uiText.bodyStrong.copyWith(
                                      color: c.foreground,
                                    ),
                                  ),
                                ),
                                SizedBox(width: ctx.sp(theme.spacing.xxs)),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: ctx.sz(18),
                                  color: c.foregroundMuted,
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                  UiIconButton(
                    icon: Icons.chevron_right,
                    size: UiSize.sm,
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1),
                    ),
                  ),
                ],
              ),
            SizedBox(height: context.sp(theme.spacing.md)),
            if (_isWheelPickerOpen)
              _buildAppleCrownWheelPicker(context)
            else if (stacked)
              for (final DateTime m in months)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: context.sp(theme.spacing.xs),
                  ),
                  child: titled(m),
                )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < months.length; i++) ...<Widget>[
                    if (i > 0) SizedBox(width: context.sp(theme.spacing.lg)),
                    Expanded(child: titled(months[i])),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppleCrownWheelPicker(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;

    final double rowH = context.fs(44);
    const double wheelH = 220.0;

    return Container(
      height: wheelH,
      alignment: Alignment.center,
      child: ClipRRect(
        borderRadius: context.radius(theme.radii.lg),
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent,
              ],
              stops: [0.0, 0.22, 0.78, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center selection indicator band (Apple Crown style)
              Container(
                height: rowH + context.sz(2),
                margin: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.xs),
                ),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: context.radius(theme.radii.md),
                  border: Border.all(
                    color: c.primary.withValues(alpha: 0.3),
                    width: theme.borders.hairline,
                  ),
                ),
              ),
              Row(
                children: [
                  // Month Crown Wheel
                  Expanded(
                    flex: 3,
                    child: ListWheelScrollView.useDelegate(
                      controller: _monthWheelController,
                      itemExtent: rowH,
                      perspective: 0.002,
                      diameterRatio: 1.6,
                      clipBehavior: Clip.hardEdge,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        setState(() {
                          _month = DateTime(_month.year, index + 1);
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: 12,
                        builder: (BuildContext ctx, int index) {
                          final bool isSelected = index == (_month.month - 1);
                          return Center(
                            child: Text(
                              _months[index],
                              style: isSelected
                                  ? ctx.uiText.bodyStrong.copyWith(
                                      color: c.primary,
                                      fontSize: ctx.fs(16),
                                    )
                                  : ctx.uiText.body.copyWith(
                                      color: c.foregroundMuted,
                                      fontSize: ctx.fs(14),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    width: theme.borders.hairline,
                    height: rowH * 3.2,
                    color: c.border,
                  ),
                  // Year Crown Wheel (fast scroll from firstYear to lastYear)
                  Expanded(
                    flex: 2,
                    child: ListWheelScrollView.useDelegate(
                      controller: _yearWheelController,
                      itemExtent: rowH,
                      perspective: 0.002,
                      diameterRatio: 1.6,
                      clipBehavior: Clip.hardEdge,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (int index) {
                        final int newYear = _firstYear + index;
                        setState(() {
                          _month = DateTime(newYear, _month.month);
                        });
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _yearCount,
                        builder: (BuildContext ctx, int index) {
                          final int year = _firstYear + index;
                          final bool isSelected = year == _month.year;
                          return Center(
                            child: Text(
                              '$year',
                              style: isSelected
                                  ? ctx.uiText.bodyStrong.copyWith(
                                      color: c.primary,
                                      fontSize: ctx.fs(16),
                                    )
                                  : ctx.uiText.body.copyWith(
                                      color: c.foregroundMuted,
                                      fontSize: ctx.fs(14),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthBody(BuildContext context, DateTime month) {
    final theme = context.ui;
    final c = theme.colors;
    final int leading = DateTime(month.year, month.month).weekday - 1;
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final String d in _weekdays)
              Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: context.uiText.caption.copyWith(
                    color: c.foregroundSubtle,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: context.sp(theme.spacing.xs)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: leading + daysInMonth,
          itemBuilder: (BuildContext ctx, int index) {
            if (index < leading) return const SizedBox.shrink();
            final DateTime day = DateTime(
              month.year,
              month.month,
              index - leading + 1,
            );
            final bool isSelected = widget.rangeMode
                ? (_rangeStart != null && _sameDay(day, _rangeStart!)) ||
                      (_rangeEnd != null && _sameDay(day, _rangeEnd!))
                : widget.selected != null && _sameDay(day, widget.selected!);
            final bool inRange =
                widget.rangeMode &&
                _rangeStart != null &&
                _rangeEnd != null &&
                day.isAfter(_rangeStart!) &&
                day.isBefore(_rangeEnd!);
            final bool isToday = _sameDay(day, DateTime.now());
            final bool marked = widget.markedDates.any(
              (DateTime d) => _sameDay(d, day),
            );
            final bool off = _disabled(day);

            return UiInteractive(
              enabled: !off,
              onTap: () => _tap(day),
              builder: (BuildContext c2, UiInteractiveState s) =>
                  AnimatedContainer(
                    duration: theme.motion.fast,
                    margin: EdgeInsets.all(c2.sz(2)),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? c.primary
                          : inRange
                          ? c.primary.withValues(alpha: 0.12)
                          : (s.hovered
                                ? c.surfaceHover
                                : c.surfaceHover.withValues(alpha: 0.0)),
                      borderRadius: c2.radius(theme.radii.md),
                      border: isToday && !isSelected
                          ? Border.all(
                              color: c.borderStrong,
                              width: theme.borders.hairline,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          '${day.day}',
                          style: c2.uiText.label.copyWith(
                            color: off
                                ? c.disabledForeground
                                : isSelected
                                ? c.onPrimary
                                : c.foreground,
                          ),
                        ),
                        if (marked)
                          Container(
                            margin: EdgeInsets.only(top: c2.sz(2)),
                            width: c2.sz(4),
                            height: c2.sz(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? c.onPrimary : c.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
            );
          },
        ),
      ],
    );
  }
}
