import 'package:flutter/material.dart';

import '../theme/ui_responsive.dart';
import '../theme/ui_theme.dart';
import 'ui_common.dart';

/// Resizable two-pane layout (list + detail). On phones only one pane is
/// rendered at a time: [detail] when [detailVisible] is true, otherwise
/// [primary]. On tablet/desktop both panes are shown side by side with a
/// draggable divider.
class UiSplitPane extends StatefulWidget {
  const UiSplitPane({
    super.key,
    Widget? primary,
    Widget? detail,
    Widget? left,
    Widget? right,
    double? initialRatio,
    double? splitRatio,
    this.minRatio = 0.2,
    this.maxRatio = 0.6,
    this.detailVisible = false,
    this.showDetail = true,
    this.resizable = true,
    this.splitFrom = UiDeviceType.tablet,
  }) : primary = primary ?? left ?? const SizedBox.shrink(),
       detail = detail ?? right ?? const SizedBox.shrink(),
       initialRatio = splitRatio ?? initialRatio ?? 0.35;

  final Widget primary;
  final Widget detail;
  final double initialRatio;
  final double minRatio;
  final double maxRatio;

  /// Only used on single-pane (phone) layouts.
  final bool detailVisible;

  /// Hide the secondary pane without remounting the primary pane.
  final bool showDetail;
  final bool resizable;

  /// Smallest device class that renders both panes.
  final UiDeviceType splitFrom;

  @override
  State<UiSplitPane> createState() => _UiSplitPaneState();
}

class _UiSplitPaneState extends State<UiSplitPane> {
  late double _ratio = widget.initialRatio;

  bool _shouldSplit(UiDeviceType type) {
    const List<UiDeviceType> order = <UiDeviceType>[
      UiDeviceType.mobile,
      UiDeviceType.tablet,
      UiDeviceType.desktop,
      UiDeviceType.largeDesktop,
    ];
    return order.indexOf(type) >= order.indexOf(widget.splitFrom);
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiResponsiveBuilder(
      builder: (BuildContext ctx, UiResponsive r) {
        if (!_shouldSplit(r.deviceType)) {
          return widget.detailVisible ? widget.detail : widget.primary;
        }
        return LayoutBuilder(
          builder: (BuildContext c, BoxConstraints box) {
            final double width = box.maxWidth;
            final double primaryWidth = widget.showDetail
                ? width * _ratio.clamp(widget.minRatio, widget.maxRatio)
                : width;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(width: primaryWidth, child: widget.primary),
                if (widget.showDetail)
                  MouseRegion(
                    cursor: widget.resizable
                        ? SystemMouseCursors.resizeLeftRight
                        : SystemMouseCursors.basic,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: widget.resizable
                          ? (DragUpdateDetails d) => setState(() {
                              _ratio = ((primaryWidth + d.delta.dx) / width)
                                  .clamp(widget.minRatio, widget.maxRatio);
                            })
                          : null,
                      child: Container(
                        width: ctx.sz(theme.spacing.sm),
                        alignment: Alignment.center,
                        child: Container(
                          width: theme.borders.hairline,
                          color: theme.colors.border,
                        ),
                      ),
                    ),
                  ),
                if (widget.showDetail) Expanded(child: widget.detail),
              ],
            );
          },
        );
      },
    );
  }
}

/// Three-pane desktop layout: navigation/filter rail, list, detail.
class UiThreePane extends StatelessWidget {
  const UiThreePane({
    super.key,
    required this.rail,
    required this.list,
    required this.detail,
    this.railWidth = 240,
    this.listRatio = 0.34,
    this.detailVisible = false,
    this.railVisible = true,
  });

  final Widget rail;
  final Widget list;
  final Widget detail;
  final double railWidth;
  final double listRatio;
  final bool detailVisible;
  final bool railVisible;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return UiResponsiveBuilder(
      builder: (BuildContext ctx, UiResponsive r) {
        final Widget split = UiSplitPane(
          primary: list,
          detail: detail,
          initialRatio: listRatio,
          detailVisible: detailVisible,
        );
        if (!r.isDesktop || !railVisible) return split;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: ctx.sz(railWidth), child: rail),
            Container(
              width: theme.borders.hairline,
              color: theme.colors.border,
            ),
            Expanded(child: split),
          ],
        );
      },
    );
  }
}

/// Placeholder shown in an empty detail pane ("Select an entry").
class UiPanePlaceholder extends StatelessWidget {
  const UiPanePlaceholder({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.view_sidebar_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    return Container(
      color: theme.colors.background,
      alignment: Alignment.center,
      padding: EdgeInsets.all(context.sp(theme.spacing.xl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: context.sz(theme.sizes.iconLg * 2),
            color: theme.colors.foregroundSubtle,
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          Text(title, style: context.uiText.subheading),
          if (message != null) ...<Widget>[
            SizedBox(height: context.sp(theme.spacing.xs)),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: context.uiText.caption.copyWith(
                color: theme.colors.foregroundMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Master-detail wrapper: handles responsive push-vs-split behaviour.
class UiMasterDetail<T> extends StatelessWidget {
  const UiMasterDetail({
    super.key,
    required this.listBuilder,
    required this.detailBuilder,
    required this.selected,
    required this.onClearSelection,
    this.placeholderTitle = 'Nothing selected',
    this.placeholderMessage,
  });

  final WidgetBuilder listBuilder;
  final Widget Function(BuildContext context, T value) detailBuilder;
  final T? selected;
  final VoidCallback onClearSelection;
  final String placeholderTitle;
  final String? placeholderMessage;

  @override
  Widget build(BuildContext context) {
    final T? value = selected;
    return UiSplitPane(
      detailVisible: value != null,
      primary: listBuilder(context),
      detail: value == null
          ? UiPanePlaceholder(
              title: placeholderTitle,
              message: placeholderMessage,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (context.uiRes.isMobile)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: UiInteractive(
                      onTap: onClearSelection,
                      builder: (BuildContext ctx, UiInteractiveState _) =>
                          Padding(
                            padding: EdgeInsets.all(ctx.sp(ctx.uiSpace.md)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.arrow_back,
                                  size: ctx.sz(ctx.uiSizes.iconMd),
                                  color: ctx.uiColors.foregroundMuted,
                                ),
                                SizedBox(width: ctx.sp(ctx.uiSpace.xs)),
                                Text('Back', style: ctx.uiText.label),
                              ],
                            ),
                          ),
                    ),
                  ),
                Expanded(child: detailBuilder(context, value)),
              ],
            ),
    );
  }
}
