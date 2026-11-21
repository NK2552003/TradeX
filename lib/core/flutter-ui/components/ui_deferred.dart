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
  ScrollPosition? _position;
  bool _loaded = false, _scheduled = false;
  int _layoutRetries = 0;

  void _syncScrollable() {
    var next = Scrollable.maybeOf(context, axis: Axis.vertical);
    while (next != null &&
        next.widget.physics is NeverScrollableScrollPhysics) {
      final outer = Scrollable.maybeOf(next.context, axis: Axis.vertical);
      if (outer == null) break;
      next = outer;
    }
    final ScrollPosition? nextPosition = next?.position;
    if (_scrollable != next || _position != nextPosition) {
      _position?.removeListener(_check);
      _scrollable = next;
      _position = nextPosition;
      _position?.addListener(_check);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncScrollable();
    _check();
  }

  @override
  void didUpdateWidget(covariant UiDeferred oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_loaded) {
      _syncScrollable();
      _check();
    }
  }

  void _check() {
    if (_loaded || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _loaded) return;
      _syncScrollable();
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
        if (_layoutRetries < 5) {
          _layoutRetries++;
          _check();
        }
        return;
      }
      _layoutRetries = 0;
      final sectionRect = section.localToGlobal(Offset.zero) & section.size;
      final viewportRect = (viewport.localToGlobal(Offset.zero) & viewport.size)
          .inflate(widget.preloadExtent);
      if (sectionRect.overlaps(viewportRect)) {
        _position?.removeListener(_check);
        setState(() => _loaded = true);
      }
    });
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _loaded
      ? widget.builder(context)
      : UiSkeleton(height: widget.estimatedHeight);
}
