import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Range slider variant (e.g. filter by market cap band).
class UiRangeSlider extends StatelessWidget {
  const UiRangeSlider({
    super.key,
    RangeValues? range,
    RangeValues? values,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.label,
    this.valueFormatter,
    this.enabled = true,
    this.intent = UiIntent.primary,
  }) : assert(
         range != null || values != null,
         'Either range or values must be provided',
       ),
       range = values ?? range ?? const RangeValues(0, 100);

  final RangeValues range;
  final ValueChanged<RangeValues>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final UiValueFormatter? valueFormatter;
  final bool enabled;
  final UiIntent intent;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final Color active = intent.color(context);
    final UiValueFormatter fmt = valueFormatter ?? uiCompactNumber;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  label!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.uiText.label.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
              ),
              SizedBox(width: context.sp(theme.spacing.xs)),
              // The readout is two formatted numbers and a dash, so it is the
              // longest thing in this row by some margin. It gets to shrink before
              // it pushes the label out of the box.
              Flexible(
                child: Text(
                  '${fmt(range.start)} – ${fmt(range.end)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: context.uiText.numeric.copyWith(
                    color: theme.colors.foreground,
                  ),
                ),
              ),
            ],
          ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: context.sz(theme.sizes.trackThickness) * 0.6,
            activeTrackColor: enabled
                ? active
                : theme.colors.disabledForeground,
            inactiveTrackColor: theme.colors.surfaceMuted,
            thumbColor: theme.colors.surface,
            overlayColor: active.withValues(alpha: 0.12),
            valueIndicatorColor: active,
            valueIndicatorTextStyle: context.uiText.caption.copyWith(
              color: intent.onColor(context),
            ),
            showValueIndicator: ShowValueIndicator.onDrag,
            rangeThumbShape: RoundRangeSliderThumbShape(
              enabledThumbRadius: context.sz(10),
              elevation: 2,
            ),
          ),
          child: RangeSlider(
            values: RangeValues(
              range.start.clamp(min, max),
              range.end.clamp(min, max),
            ),
            min: min,
            max: max,
            divisions: divisions,
            // Without these the thumbs show nothing while being dragged, so the
            // reader is picking a band blind on a touch screen where their own
            // finger covers the readout above.
            labels: RangeLabels(fmt(range.start), fmt(range.end)),
            semanticFormatterCallback: (double d) =>
                '${label ?? 'Range'} ${fmt(d)}',
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
