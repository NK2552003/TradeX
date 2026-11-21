import 'dart:async';

import 'package:flutter/material.dart';

/// GPU-composited one-shot scroll reveal for editorial landing sections, cards,
/// and staggered galleries.
///
/// Observes the enclosing vertical [ScrollPosition] until this widget enters
/// the viewport, then plays a single smooth fade + upward glide (+ subtle scale
/// settle) and detaches its scroll listener permanently so scrolling stays at
/// 60/120fps and theme switches never replay the entrance.
class UiScrollReveal extends StatefulWidget {
  const UiScrollReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 560),
    this.slideOffset = const Offset(0, 0.05),
    this.scaleFrom = 0.985,
    this.revealMargin = 48.0,
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;
  final double scaleFrom;

  /// Extra vertical viewport margin (in logical px) before triggering reveal.
  final double revealMargin;
  final Curve curve;

  @override
  State<UiScrollReveal> createState() => _UiScrollRevealState();
}

class _UiScrollRevealState extends State<UiScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: widget.curve,
  );
  late Animation<Offset> _slide = Tween<Offset>(
    begin: widget.slideOffset,
    end: Offset.zero,
  ).animate(_curved);
  late Animation<double> _scale = Tween<double>(
    begin: widget.scaleFrom,
    end: 1.0,
  ).animate(_curved);

  ScrollableState? _scrollable;
  ScrollPosition? _position;
  Timer? _delayTimer;
  bool _revealed = false;
  bool _scheduled = false;
  int _layoutRetries = 0;

  void _syncScrollable() {
    if (_revealed) return;
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
    if (MediaQuery.disableAnimationsOf(context)) {
      _revealImmediately();
      return;
    }
    if (!_revealed) {
      _syncScrollable();
      _check();
    }
  }

  @override
  void didUpdateWidget(covariant UiScrollReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve ||
        oldWidget.slideOffset != widget.slideOffset ||
        oldWidget.scaleFrom != widget.scaleFrom) {
      _curved = CurvedAnimation(parent: _controller, curve: widget.curve);
      _slide = Tween<Offset>(
        begin: widget.slideOffset,
        end: Offset.zero,
      ).animate(_curved);
      _scale = Tween<double>(
        begin: widget.scaleFrom,
        end: 1.0,
      ).animate(_curved);
    }
    if (!_revealed) {
      _syncScrollable();
      _check();
    }
  }

  void _revealImmediately() {
    _revealed = true;
    _delayTimer?.cancel();
    _position?.removeListener(_check);
    _controller.value = 1.0;
  }

  void _triggerReveal() {
    if (_revealed) return;
    _revealed = true;
    _position?.removeListener(_check);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1.0;
      return;
    }
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _delayTimer?.cancel();
      _delayTimer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  void _check() {
    if (_revealed || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _revealed) return;
      _syncScrollable();
      if (_scrollable == null) {
        _triggerReveal();
        return;
      }
      final RenderObject? box = context.findRenderObject();
      final RenderObject? viewport = _scrollable?.context.findRenderObject();
      if (box is! RenderBox ||
          viewport is! RenderBox ||
          !box.hasSize ||
          !viewport.hasSize) {
        if (_layoutRetries < 5) {
          _layoutRetries++;
          _check();
        }
        return;
      }
      _layoutRetries = 0;
      final Rect boxRect = box.localToGlobal(Offset.zero) & box.size;
      final Rect viewportRect =
          (viewport.localToGlobal(Offset.zero) & viewport.size).inflate(
            widget.revealMargin,
          );
      if (boxRect.overlaps(viewportRect)) {
        _triggerReveal();
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _position?.removeListener(_check);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = FadeTransition(
      opacity: _curved,
      child: SlideTransition(position: _slide, child: widget.child),
    );
    if (widget.scaleFrom != 1.0) {
      content = ScaleTransition(scale: _scale, child: content);
    }
    return RepaintBoundary(child: content);
  }
}
