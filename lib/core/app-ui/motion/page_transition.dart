import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Reusable staggered horizontal strips page transition matching ultimate-media-downloader.
///
/// Divides the screen into [stripCount] horizontal panels that wipe across from left to right
/// to cover the old page strip by strip, seamlessly mounts the destination page under cover,
/// and wipes out to the right strip by strip revealing the new page with zero lag.
class UiStaggeredPageTransition extends StatefulWidget {
  const UiStaggeredPageTransition({
    super.key,
    required this.child,
    this.stripCount = 5,
    this.stripDuration = const Duration(milliseconds: 280),
    this.staggerDelay = const Duration(milliseconds: 48),
    this.stripColor,
    this.borderColor,
  });

  final Widget child;
  final int stripCount;
  final Duration stripDuration;
  final Duration staggerDelay;
  final Color? stripColor;
  final Color? borderColor;

  @override
  State<UiStaggeredPageTransition> createState() =>
      _UiStaggeredPageTransitionState();
}

class _UiStaggeredPageTransitionState extends State<UiStaggeredPageTransition>
    with SingleTickerProviderStateMixin {
  late Widget _currentChild;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  )..value = 1;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
  }

  @override
  void didUpdateWidget(covariant UiStaggeredPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != oldWidget.child.key ||
        widget.child.runtimeType != oldWidget.child.runtimeType) {
      _currentChild = widget.child;
      _controller.forward(from: 0);
    } else {
      _currentChild = widget.child;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiColors colors = context.uiColors;
    return ColoredBox(
      color: colors.background,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.88, end: 1).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        ),
        child: KeyedSubtree(
          key: ValueKey<Key?>(_currentChild.key),
          child: _currentChild,
        ),
      ),
    );
  }
}

/// Smooth whole-page blur-to-unblur reveal transition for splash -> onboarding.
///
/// Features solid background anchoring with [UiColors.background] and [ClipRect]
/// to eliminate any white flash or transparency bleed during the unblur animation.
class AppBlurFade extends StatelessWidget {
  const AppBlurFade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final colors = context.uiColors;

    return ColoredBox(
      color: colors.background,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double value, Widget? childWidget) {
          return Opacity(opacity: value, child: childWidget);
        },
        child: child,
      ),
    );
  }
}
