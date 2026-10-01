import 'package:flutter/material.dart';
import 'ui_skeleton.dart';

/// Mounts expensive sections only when they approach their enclosing viewport.
/// The anchor stays mounted so section navigation and scroll restoration work.
class UiDeferred extends StatefulWidget {
  const UiDeferred({
    super.key,
    required this.builder,
    this.estimatedHeight = 240,
    this.preloadExtent = 300,
  });
  final WidgetBuilder builder;
  final double estimatedHeight, preloadExtent;
  @override
  State<UiDeferred> createState() => _UiDeferredState();
}

class _UiDeferredState extends State<UiDeferred> {
  ScrollableState? _scrollable;
  bool _loaded = false, _scheduled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    var next = Scrollable.maybeOf(context, axis: Axis.vertical);
    while (next != null &&
        next.widget.physics is NeverScrollableScrollPhysics) {
      final outer = Scrollable.maybeOf(next.context, axis: Axis.vertical);
      if (outer == null) break;
      next = outer;
    }
    if (_scrollable != next) {
      _scrollable?.position.removeListener(_check);
      _scrollable = next;
      _scrollable?.position.addListener(_check);
    }
    _check();
  }

  void _check() {
    if (_loaded || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _loaded) return;
      final section = context.findRenderObject();
      final viewport = _scrollable?.context.findRenderObject();
      if (_scrollable == null) {
        setState(() => _loaded = true);
        return;
      }
      if (section is! RenderBox ||
          viewport is! RenderBox ||
          !section.hasSize ||
          !viewport.hasSize) {
        return;
      }
      final sectionRect = section.localToGlobal(Offset.zero) & section.size;
      final viewportRect = (viewport.localToGlobal(Offset.zero) & viewport.size)
          .inflate(widget.preloadExtent);
      if (sectionRect.overlaps(viewportRect)) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _scrollable?.position.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _loaded
      ? widget.builder(context)
      : UiSkeleton(height: widget.estimatedHeight);
}
