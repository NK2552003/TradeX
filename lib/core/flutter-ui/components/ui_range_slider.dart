import 'package:flutter/material.dart';

import '../themes/ui_theme.dart';
import 'ui_common.dart';

/// Range slider variant (e.g. filter by market cap band).
class UiRangeSlider extends StatelessWidget {
  const UiRangeSlider({
    super.key,
    required this.range,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.divisions,
    this.label,
    this.valueFormatter,
    this.enabled = true,
    this.intent = UiIntent.primary,
  });

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
            children: <Widget>[
              Expanded(
                child: Text(
                  label!,
                  style: context.uiText.label
                      .copyWith(color: theme.colors.foregroundMuted),
                ),
              ),
              Text(
                '${fmt(range.start)} – ${fmt(range.end)}',
                style: context.uiText.numeric
                    .copyWith(color: theme.colors.foreground),
              ),
            ],
          ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: context.sz(theme.sizes.trackThickness) * 0.6,
            activeTrackColor: enabled ? active : theme.colors.disabledForeground,
            inactiveTrackColor: theme.colors.surfaceMuted,
            thumbColor: theme.colors.surface,
            overlayColor: active.withValues(alpha: 0.12),
            rangeThumbShape: RoundRangeSliderThumbShape(
              enabledThumbRadius: context.sz(10),
              elevation: 2,
            ),
          ),
          child: RangeSlider(
            values: range,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}
