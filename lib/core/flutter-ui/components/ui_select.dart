import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_dialog.dart';
import 'ui_common.dart';
import 'ui_input.dart';

/// Dropdown select. Uses a bottom sheet on phones and an anchored menu on
/// larger screens — one API, responsive presentation.
class UiSelect<T> extends StatelessWidget {
  const UiSelect({
    super.key,
    required this.options,
    this.value,
    this.onChanged,
    this.hintText = 'Select',
    this.label,
    this.helperText,
    this.errorText,
    this.size = UiSize.md,
    this.density = UiDensity.comfortable,
    this.variant = UiInputVariant.outline,
    this.enabled = true,
    this.error = false,
    this.loading = false,
    this.multiple = false,
    this.values,
    this.maxVisibleChips,
    this.onValuesChanged,
    this.leadingIcon,
    this.searchable = false,
    this.width,
    this.minWidth,
    this.maxWidth,
    this.expand = false,
  });

  final List<UiOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String hintText;
  final String? label;
  final String? helperText;
  final String? errorText;
  final UiSize size;
  final UiDensity density;
  final UiInputVariant variant;
  final bool enabled;
  final bool error;
  final bool loading;
  final bool multiple;
  final List<T>? values;
  final int? maxVisibleChips;
  final ValueChanged<List<T>>? onValuesChanged;
  final IconData? leadingIcon;
  final bool searchable;

  /// Fixed width in logical points (scaled internally). Overrides
  /// [minWidth]/[maxWidth] when set.
  final double? width;

  /// Width bounds in logical points (scaled internally).
  final double? minWidth;
  final double? maxWidth;
  final bool expand;

  UiOption<T>? get _selected {
    for (final UiOption<T> o in options) {
      if (o.value == value) return o;
    }
    return null;
  }

  Future<void> _openMulti(BuildContext context) async {
    final List<T> current = List<T>.from(values ?? <T>[]);
    final List<T>? picked = await UiDialog.show<List<T>>(
      context,
      child: StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setStateDialog) {
          return UiDialog(
            title: label ?? hintText,
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * .55,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (BuildContext c2, int i) {
                  final UiOption<T> opt = options[i];
                  final bool isSelected = current.contains(opt.value);
                  return CheckboxListTile(
                    title: Text(opt.label),
                    value: isSelected,
                    onChanged: opt.enabled
                        ? (bool? v) {
                            setStateDialog(() {
                              if (v == true) {
                                current.add(opt.value);
                              } else {
                                current.remove(opt.value);
                              }
                            });
                          }
                        : null,
                  );
                },
              ),
            ),
            actions: <Widget>[
              UiButton(
                label: 'Cancel',
                variant: UiVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(null),
              ),
              UiButton(
                label: 'Done',
                variant: UiVariant.solid,
                intent: UiIntent.primary,
                onPressed: () => Navigator.of(ctx).pop(current),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null) {
      onValuesChanged?.call(picked);
    }
  }

  Future<void> _open(BuildContext context) async {
    if (multiple) {
      await _openMulti(context);
      return;
    }
    final T? picked = context.uiRes.isMobile
        ? await _showSheet(context)
        : await _showMenu(context);
    if (picked != null) onChanged?.call(picked);
  }

  Future<T?> _showSheet(BuildContext context) {
    return UiDialog.show<T>(
      context,
      child: Builder(
        builder: (ctx) => UiDialog(
          title: label ?? hintText,
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (c2, i) => _UiSelectRow<T>(
                option: options[i],
                selected: options[i].value == value,
                onTap: () => Navigator.of(c2).pop(options[i].value),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<T?> _showMenu(BuildContext context) {
    final theme = context.ui;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final Size screenSize = MediaQuery.sizeOf(context);
    return showMenu<T>(
      context: context,
      color: theme.colors.surface,
      elevation: 0,
      constraints: BoxConstraints(
        minWidth: box.size.width,
        maxWidth: screenSize.width - 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: context.radius(theme.radii.lg),
        side: BorderSide(
          color: theme.colors.border,
          width: theme.borders.hairline,
        ),
      ),
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + box.size.height,
        screenSize.width - (offset.dx + box.size.width),
        screenSize.height - offset.dy,
      ),
      items: <PopupMenuEntry<T>>[
        for (final UiOption<T> o in options)
          PopupMenuItem<T>(
            value: o.value,
            enabled: o.enabled,
            padding: EdgeInsets.zero,
            child: _UiSelectRow<T>(option: o, selected: o.value == value),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    final UiOption<T>? sel = _selected;
    final bool explicitlySized = expand || width != null || maxWidth != null;

    final Widget selectedLabel;
    if (multiple && values != null && values!.isNotEmpty) {
      final List<String> selectedLabels = options
          .where((UiOption<T> o) => values!.contains(o.value))
          .map((UiOption<T> o) => o.label)
          .toList();
      selectedLabel = Text(
        selectedLabels.isEmpty ? hintText : selectedLabels.join(', '),
        overflow: TextOverflow.ellipsis,
        style: context.uiText.body.copyWith(
          color: selectedLabels.isEmpty
              ? c.foregroundSubtle
              : enabled
              ? c.foreground
              : c.disabledForeground,
        ),
      );
    } else {
      selectedLabel = Text(
        sel?.label ?? hintText,
        overflow: TextOverflow.ellipsis,
        style: context.uiText.body.copyWith(
          color: sel == null
              ? c.foregroundSubtle
              : enabled
              ? c.foreground
              : c.disabledForeground,
        ),
      );
    }

    final Widget selectBox = LayoutBuilder(
      builder: (BuildContext layoutContext, BoxConstraints available) {
        final bool fillsAvailableWidth =
            explicitlySized || available.hasTightWidth;
        final bool isGhost = variant == UiInputVariant.ghost;
        final bool isFilled = variant == UiInputVariant.filled;
        final bool isUnderline = variant == UiInputVariant.underline;
        return UiInteractive(
          enabled: enabled && (onChanged != null || onValuesChanged != null),
          onTap: () => _open(layoutContext),
          semanticLabel: label ?? hintText,
          builder: (BuildContext ctx, UiInteractiveState s) {
            final Color bgColor = !enabled
                ? (isGhost ? Colors.transparent : c.disabledBackground)
                : isGhost
                ? (s.hovered ? c.surfaceHover : Colors.transparent)
                : isFilled
                ? c.surfaceMuted
                : isUnderline
                ? Colors.transparent
                : c.surface;
            final Color bColor = (error || errorText != null)
                ? c.destructive
                : s.hovered
                ? c.borderStrong
                : c.border;
            return AnimatedContainer(
              duration: theme.motion.fast,
              height: size.height(ctx),
              width: expand
                  ? double.infinity
                  : (width == null ? null : ctx.sz(width!)),
              constraints: width != null
                  ? null
                  : BoxConstraints(
                      minWidth: ctx.sz(minWidth ?? (isGhost ? 72 : 120)),
                      maxWidth: maxWidth == null
                          ? double.infinity
                          : ctx.sz(maxWidth!),
                    ),
              padding: EdgeInsets.symmetric(
                horizontal: ctx.sp(
                  isGhost || isUnderline ? theme.spacing.sm : theme.spacing.md,
                ),
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: isUnderline
                    ? BorderRadius.zero
                    : ctx.radius(theme.radii.lg),
                border: isGhost
                    ? (s.hovered
                          ? Border.all(
                              color: c.border,
                              width: theme.borders.hairline,
                            )
                          : null)
                    : isUnderline
                    ? Border(
                        bottom: BorderSide(
                          color: bColor,
                          width: theme.borders.hairline,
                        ),
                      )
                    : Border.all(color: bColor, width: theme.borders.hairline),
              ),
              child: Row(
                mainAxisSize: fillsAvailableWidth
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: <Widget>[
                  if (leadingIcon != null || sel?.icon != null) ...<Widget>[
                    Icon(
                      sel?.icon ?? leadingIcon,
                      size: size.icon(ctx),
                      color: c.foregroundMuted,
                    ),
                    SizedBox(width: ctx.sp(theme.spacing.sm)),
                  ],
                  if (fillsAvailableWidth)
                    Expanded(child: selectedLabel)
                  else
                    Flexible(child: selectedLabel),
                  SizedBox(width: ctx.sp(theme.spacing.xs)),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: size.icon(ctx),
                    color: c.foregroundSubtle,
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (label == null && helperText == null && errorText == null) {
      return selectBox;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!,
            style: context.uiText.label.copyWith(
              color: c.foregroundMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: context.sp(theme.spacing.xxs)),
        ],
        selectBox,
        if (errorText != null || helperText != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            errorText ?? helperText!,
            style: context.uiText.caption.copyWith(
              color: errorText != null ? c.destructive : c.foregroundSubtle,
            ),
          ),
        ],
      ],
    );
  }
}

class _UiSelectRow<T> extends StatelessWidget {
  const _UiSelectRow({
    required this.option,
    required this.selected,
    this.onTap,
  });

  final UiOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    return UiInteractive(
      enabled: option.enabled,
      onTap: onTap,
      builder: (BuildContext ctx, UiInteractiveState s) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: ctx.sp(theme.spacing.md),
          vertical: ctx.sp(theme.spacing.md),
        ),
        color: s.hovered ? c.surfaceHover : Colors.transparent,
        child: Row(
          children: <Widget>[
            if (option.icon != null) ...<Widget>[
              Icon(
                option.icon,
                size: ctx.sz(theme.sizes.iconMd),
                color: c.foregroundMuted,
              ),
              SizedBox(width: ctx.sp(theme.spacing.sm)),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    option.label,
                    style: ctx.uiText.body.copyWith(
                      color: option.enabled
                          ? c.foreground
                          : c.disabledForeground,
                    ),
                  ),
                  if (option.description != null)
                    Text(
                      option.description!,
                      style: ctx.uiText.caption.copyWith(
                        color: c.foregroundMuted,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check,
                size: ctx.sz(theme.sizes.iconSm),
                color: c.primary,
              ),
          ],
        ),
      ),
    );
  }
}
