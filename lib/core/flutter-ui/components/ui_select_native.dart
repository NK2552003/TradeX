import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Compact, platform-native style select (the Dart counterpart of
/// `SelectNative`): renders as an inline dropdown button instead of a sheet or
/// anchored panel. Use it inside dense forms, table toolbars and filter bars.
class UiSelectNative<T> extends StatelessWidget {
  const UiSelectNative({
    super.key,
    required this.options,
    required this.value,
    this.onChanged,
    this.hintText = 'Select',
    this.size = UiSize.md,
    this.enabled = true,
    this.error = false,
    this.expand = false,
  });

  final List<UiOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String hintText;
  final UiSize size;
  final bool enabled;
  final bool error;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final bool disabled = !enabled || onChanged == null;
    final bool hasValue =
        value != null && options.any((UiOption<T> o) => o.value == value);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool shouldExpand = expand || constraints.hasTightWidth;
        final Widget field = Container(
          height: size.height(context),
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
          ),
          decoration: BoxDecoration(
            color: disabled ? c.surfaceMuted : c.surface,
            borderRadius: context.radius(theme.radii.lg),
            border: Border.all(
              color: error ? c.bearish : c.border,
              width: theme.borders.hairline,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: hasValue ? value : null,
              isExpanded: shouldExpand,
              isDense: true,
              borderRadius: context.radius(theme.radii.lg),
              dropdownColor: c.surface,
              focusColor: Colors.transparent,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: context.sz(theme.sizes.iconSm),
                color: c.foregroundMuted,
              ),
              hint: Text(
                hintText,
                style: context.uiText.body.copyWith(color: c.foregroundSubtle),
              ),
              style: context.uiText.body.copyWith(color: c.foreground),
              onChanged: disabled
                  ? null
                  : (T? picked) {
                      if (picked != null) onChanged!(picked);
                    },
              items: <DropdownMenuItem<T>>[
                for (final UiOption<T> o in options)
                  DropdownMenuItem<T>(
                    value: o.value,
                    enabled: o.enabled,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (o.icon != null) ...<Widget>[
                          Icon(
                            o.icon,
                            size: context.sz(theme.sizes.iconSm),
                            color: c.foregroundMuted,
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                        ],
                        Flexible(
                          child: Text(
                            o.label,
                            overflow: TextOverflow.ellipsis,
                            style: context.uiText.body.copyWith(
                              color: o.enabled
                                  ? c.foreground
                                  : c.foregroundSubtle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );

        return shouldExpand ? field : IntrinsicWidth(child: field);
      },
    );
  }
}
