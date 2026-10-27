import 'package:flutter/material.dart';

/// A viewport-built list that reveals local records in batches near the end.
/// Headers and items share one scroll view; no nested shrink-wrapped lists.
class UiLazyList extends StatefulWidget {
  const UiLazyList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.headerBuilder,
    this.padding = EdgeInsets.zero,
    this.pageSize = 20,
    this.maxWidth,
    this.controller,
  });
  final int itemCount, pageSize;
  final IndexedWidgetBuilder itemBuilder;
  final WidgetBuilder? headerBuilder;
  final EdgeInsetsGeometry padding;
  final double? maxWidth;
  final ScrollController? controller;
  @override
  State<UiLazyList> createState() => _UiLazyListState();
}

class _UiLazyListState extends State<UiLazyList> {
  late int _visible = widget.pageSize;
  bool _scheduled = false;
  void _more(ScrollMetrics metrics) {
    if (_scheduled ||
        metrics.extentAfter > 400 ||
        _visible >= widget.itemCount) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) setState(() => _visible += widget.pageSize);
    });
  }

  Widget _constrain(Widget child) => widget.maxWidth == null
      ? child
      : Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.maxWidth!),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );
  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollMetricsNotification>(
        onNotification: (n) {
          if (n.depth == 0) _more(n.metrics);
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.depth == 0) _more(n.metrics);
            return false;
          },
          child: CustomScrollView(
            controller: widget.controller,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: widget.padding,
                sliver: SliverMainAxisGroup(
                  slivers: [
                    if (widget.headerBuilder != null)
                      SliverToBoxAdapter(
                        child: _constrain(widget.headerBuilder!(context)),
                      ),
                    SliverList.builder(
                      itemCount: widget.itemCount.clamp(0, _visible),
                      itemBuilder: (context, i) =>
                          _constrain(widget.itemBuilder(context, i)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
