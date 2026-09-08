import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_data_panel.dart';

/// One line of a [UiKeyValueTable].
@immutable
class UiKeyValueRow {
  const UiKeyValueRow({
    required this.label,
    required this.value,
    this.detail,
    this.trailing,
    this.intent = UiIntent.neutral,
    this.emphasis = false,
    this.share,
    this.icon,
  });

  final String label;

  /// Primary figure. Rendered with tabular numerals and right-aligned.
  final String value;

  /// Secondary line under [label] — the assumption behind the number.
  final String? detail;

  /// Third column: a share, a rate, a short verdict.
  final String? trailing;
  final UiIntent intent;

  /// Totals and subtotals: heavier type, muted fill, stronger rule above.
  final bool emphasis;

  /// 0..1 contribution, drawn as a hairline bar along the row's baseline. Lets
  /// a breakdown table double as a bar chart without a second widget.
  final double? share;
  final IconData? icon;
}

/// Dense breakdown table: label, figure, optional third column, optional
/// in-row share bar.
///
/// [UiTable] is built for record collections — sorting, paging, selection. A
/// breakdown is different: a fixed handful of named quantities that must read
/// top-to-bottom like a statement. This renders that without the machinery, and
/// carries the share bar so the reader sees proportion and value at once.
class UiKeyValueTable extends StatelessWidget {
  const UiKeyValueTable({
    super.key,
    required this.rows,
    this.labelHeader,
    this.valueHeader,
    this.trailingHeader,
    this.density = UiDensity.compact,
    this.showShareBars = true,
    this.valueWidth = 104,
    this.trailingWidth = 72,
  });

  final List<UiKeyValueRow> rows;
  final String? labelHeader;
  final String? valueHeader;
  final String? trailingHeader;
  final UiDensity density;
  final bool showShareBars;
  final double valueWidth;
  final double trailingWidth;

  bool get _hasTrailing =>
      trailingHeader != null ||
      rows.any((UiKeyValueRow r) => r.trailing != null);

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final bool header =
        labelHeader != null || valueHeader != null || trailingHeader != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (header) _header(context),
        for (int i = 0; i < rows.length; i++)
          _row(context, rows[i], first: i == 0 && !header),
      ],
    );
  }

  EdgeInsets _pad(BuildContext context) {
    final theme = context.ui;
    final double f = density.factor;
    return EdgeInsets.symmetric(
      horizontal: context.sp(theme.spacing.sm) * f,
      vertical: context.sp(theme.spacing.md) * f * 0.8,
    );
  }

  Widget _header(BuildContext context) {
    final theme = context.ui;
    final c = theme.colors;
    return Container(
      padding: _pad(context),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.border, width: theme.borders.hairline),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              (labelHeader ?? '').toUpperCase(),
              style: uiOverline(context),
            ),
          ),
          SizedBox(
            width: context.sz(valueWidth),
            child: Text(
              (valueHeader ?? '').toUpperCase(),
              style: uiOverline(context),
              textAlign: TextAlign.end,
            ),
          ),
          if (_hasTrailing)
            SizedBox(
              width: context.sz(trailingWidth),
              child: Text(
                (trailingHeader ?? '').toUpperCase(),
                style: uiOverline(context),
                textAlign: TextAlign.end,
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, UiKeyValueRow row, {required bool first}) {
    final theme = context.ui;
    final c = theme.colors;
    final Color tint = row.intent == UiIntent.neutral
        ? c.foreground
        : row.intent.color(context);
    final double? share = showShareBars ? row.share : null;

    final Widget content = Padding(
      padding: _pad(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (row.icon != null) ...<Widget>[
            Icon(
              row.icon,
              size: context.sz(theme.sizes.iconXs),
              color: row.intent == UiIntent.neutral
                  ? c.foregroundSubtle
                  : tint,
            ),
            SizedBox(width: context.sp(theme.spacing.xs)),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  row.label,
                  style: (row.emphasis
                          ? context.uiText.bodyStrong
                          : context.uiText.body)
                      .copyWith(color: c.foreground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (row.detail != null)
                  Text(
                    row.detail!,
                    style: context.uiText.caption.copyWith(
                      color: c.foregroundSubtle,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(width: context.sp(theme.spacing.xs)),
          SizedBox(
            width: context.sz(valueWidth),
            child: Text(
              row.value,
              textAlign: TextAlign.end,
              style: context.uiText.numeric.copyWith(
                color: tint,
                fontWeight: row.emphasis ? FontWeight.w700 : FontWeight.w500,
                fontSize: context.uiText.numeric.fontSize,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_hasTrailing)
            SizedBox(
              width: context.sz(trailingWidth),
              child: Text(
                row.trailing ?? '',
                textAlign: TextAlign.end,
                style: context.uiText.caption.copyWith(
                  color: c.foregroundMuted,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: row.emphasis ? c.surfaceMuted : null,
        border: Border(
          top: first
              ? BorderSide.none
              : BorderSide(
                  color: row.emphasis ? c.borderStrong : c.border,
                  width: theme.borders.hairline,
                ),
        ),
      ),
      child: share == null
          ? content
          : Stack(
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: share.clamp(0.0, 1.0),
                    child: Container(
                      height: context.sz(2),
                      color: (row.intent == UiIntent.neutral
                              ? c.primary
                              : tint)
                          .withValues(alpha: 0.55),
                    ),
                  ),
                ),
                content,
              ],
            ),
    );
  }
}
