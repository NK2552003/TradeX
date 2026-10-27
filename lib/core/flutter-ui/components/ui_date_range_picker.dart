import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_dialog.dart';
import 'ui_calendar.dart';
import 'ui_common.dart';
import 'ui_date_picker.dart';

/// A named quick range (Today, Last 7 days, ...). Ranges are computed, never
/// hardcoded strings, so they stay correct whenever the sheet is opened.
class UiDateRangePreset {
  const UiDateRangePreset({required this.label, required this.resolve});

  final String label;
  final DateTimeRange Function(DateTime now) resolve;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Default preset row used when none is supplied.
  static List<UiDateRangePreset> defaults() => <UiDateRangePreset>[
    UiDateRangePreset(
      label: 'Today',
      resolve: (DateTime n) => DateTimeRange(start: _day(n), end: _day(n)),
    ),
    UiDateRangePreset(
      label: 'Last 7 days',
      resolve: (DateTime n) => DateTimeRange(
        start: _day(n).subtract(const Duration(days: 6)),
        end: _day(n),
      ),
    ),
    UiDateRangePreset(
      label: 'Last 30 days',
      resolve: (DateTime n) => DateTimeRange(
        start: _day(n).subtract(const Duration(days: 29)),
        end: _day(n),
      ),
    ),
    UiDateRangePreset(
      label: 'This month',
      resolve: (DateTime n) =>
          DateTimeRange(start: DateTime(n.year, n.month), end: _day(n)),
    ),
    UiDateRangePreset(
      label: 'This year',
      resolve: (DateTime n) =>
          DateTimeRange(start: DateTime(n.year), end: _day(n)),
    ),
  ];
}

/// Date range picker: a field that opens presets plus a range calendar.
class UiDateRangePicker extends StatelessWidget {
  UiDateRangePicker({
    super.key,
    DateTimeRange? value,
    DateTime? startDate,
    DateTime? endDate,
    ValueChanged<DateTimeRange>? onChanged,
    ValueChanged<DateTimeRange>? onRangeSelected,
    this.hintText = 'Pick a range',
    this.size = UiSize.md,
    this.enabled = true,
    this.presets,
    this.firstDate,
    this.lastDate,
    this.showPresets = true,
  }) : value =
           value ??
           (startDate != null && endDate != null
               ? DateTimeRange(start: startDate, end: endDate)
               : null),
       onChanged = onRangeSelected ?? onChanged;

  final DateTimeRange? value;
  final ValueChanged<DateTimeRange>? onChanged;
  final String hintText;
  final UiSize size;
  final bool enabled;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final List<UiDateRangePreset>? presets;
  final bool showPresets;

  String get _text => value == null
      ? hintText
      : '${UiDatePicker.format(value!.start)} – ${UiDatePicker.format(value!.end)}';

  Future<void> _open(BuildContext context) async {
    final theme = context.ui;
    final List<UiDateRangePreset> items =
        presets ?? UiDateRangePreset.defaults();

    await UiDialog.show<void>(
      context,
      maxWidth: 760,
      child: Builder(
        builder: (BuildContext ctx) => UiDialog(
          title: 'Date range',
          content: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(ctx.sp(theme.spacing.lg)),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ctx.sz(760)),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showPresets && items.isNotEmpty) ...<Widget>[
                        Wrap(
                          spacing: ctx.sp(theme.spacing.xs),
                          runSpacing: ctx.sp(theme.spacing.xs),
                          children: <Widget>[
                            for (final UiDateRangePreset p in items)
                              UiInteractive(
                                onTap: () {
                                  onChanged?.call(p.resolve(DateTime.now()));
                                  Navigator.of(ctx).pop();
                                },
                                builder:
                                    (BuildContext c2, UiInteractiveState s) =>
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: c2.sp(theme.spacing.md),
                                            vertical: c2.sp(theme.spacing.xs),
                                          ),
                                          decoration: BoxDecoration(
                                            color: s.hovered
                                                ? theme.colors.surfaceHover
                                                : theme.colors.surfaceMuted,
                                            borderRadius: c2.radius(
                                              theme.radii.pill,
                                            ),
                                            border: Border.all(
                                              color: theme.colors.border,
                                              width: theme.borders.hairline,
                                            ),
                                          ),
                                          child: Text(
                                            p.label,
                                            style: c2.uiText.caption.copyWith(
                                              color: theme.colors.foreground,
                                            ),
                                          ),
                                        ),
                              ),
                          ],
                        ),
                        SizedBox(height: ctx.sp(theme.spacing.lg)),
                      ],
                      UiCalendar(
                        range: value,
                        rangeMode: true,
                        firstDate: firstDate,
                        lastDate: lastDate,
                        onRangeSelected: (DateTimeRange r) {
                          onChanged?.call(r);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
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
    return UiInteractive(
      enabled: enabled,
      onTap: enabled ? () => _open(context) : null,
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        height: size.height(ctx),
        padding: EdgeInsets.symmetric(horizontal: ctx.sp(theme.spacing.md)),
        decoration: BoxDecoration(
          color: enabled ? c.surface : c.surfaceMuted,
          borderRadius: ctx.radius(theme.radii.lg),
          border: Border.all(
            color: s.hovered ? c.borderStrong : c.border,
            width: theme.borders.hairline,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.date_range_rounded,
              size: ctx.sz(theme.sizes.iconSm),
              color: c.foregroundMuted,
            ),
            SizedBox(width: ctx.sp(theme.spacing.xs)),
            Expanded(
              child: Text(
                _text,
                overflow: TextOverflow.ellipsis,
                style: ctx.uiText.body.copyWith(
                  color: value == null ? c.foregroundSubtle : c.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
