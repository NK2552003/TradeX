import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_calendar.dart';
import 'ui_common.dart';

/// Date / date-range picker field. Opens [UiCalendar] in a themed overlay.
class UiDatePicker extends StatelessWidget {
  const UiDatePicker({
    super.key,
    this.value,
    this.range,
    this.onChanged,
    this.onRangeChanged,
    this.rangeMode = false,
    this.hintText = 'Pick a date',
    this.size = UiSize.md,
    this.enabled = true,
    this.firstDate,
    this.lastDate,
  });

  final DateTime? value;
  final DateTimeRange? range;
  final ValueChanged<DateTime>? onChanged;
  final ValueChanged<DateTimeRange>? onRangeChanged;
  final bool rangeMode;
  final String hintText;
  final UiSize size;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;

  static String format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String get _text {
    if (rangeMode) {
      if (range == null) return hintText;
      return '${format(range!.start)} – ${format(range!.end)}';
    }
    return value == null ? hintText : format(value!);
  }

  Future<void> _open(BuildContext context) async {
    final theme = context.ui;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: theme.colors.overlay,
      isScrollControlled: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(ctx.sp(theme.spacing.lg)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ctx.sz(420)),
            child: UiCalendar(
              selected: value,
              range: range,
              rangeMode: rangeMode,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateSelected: (DateTime d) {
                onChanged?.call(d);
                Navigator.of(ctx).pop();
              },
              onRangeSelected: (DateTimeRange r) {
                onRangeChanged?.call(r);
                Navigator.of(ctx).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final bool empty = rangeMode ? range == null : value == null;
    return UiInteractive(
      enabled: enabled,
      onTap: () => _open(context),
      semanticLabel: hintText,
      builder: (BuildContext ctx, UiInteractiveState s) => AnimatedContainer(
        duration: theme.motion.fast,
        height: size.height(ctx),
        padding: EdgeInsets.symmetric(horizontal: ctx.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: enabled ? c.surface : c.disabledBackground,
          borderRadius: ctx.radius(theme.radii.lg),
          border: Border.all(
            color: s.hovered ? c.borderStrong : c.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: size.icon(ctx),
              color: c.foregroundMuted,
            ),
            SizedBox(width: ctx.sp(theme.spacing.sm)),
            Expanded(
              child: Text(
                _text,
                overflow: TextOverflow.ellipsis,
                style: ctx.uiText.body.copyWith(
                  color: empty ? c.foregroundSubtle : c.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
