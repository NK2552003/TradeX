import 'dart:ui';
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

enum _TransitionPhase { idle, covering, covered, revealing }

class _UiStaggeredPageTransitionState extends State<UiStaggeredPageTransition>
    with TickerProviderStateMixin {
  late Widget _currentChild;
  Widget? _nextChild;

  late AnimationController _inController;
  late AnimationController _outController;
  _TransitionPhase _phase = _TransitionPhase.idle;

  @override
  void initState() {
    super.initState();
    _currentChild = widget.child;
    _initControllers();
  }

  void _initControllers() {
    final Duration totalDuration =
        widget.stripDuration + (widget.staggerDelay * (widget.stripCount - 1));
    _inController = AnimationController(vsync: this, duration: totalDuration);
    _outController = AnimationController(vsync: this, duration: totalDuration);
  }

  @override
  void didUpdateWidget(covariant UiStaggeredPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child.key != oldWidget.child.key ||
        widget.child.runtimeType != oldWidget.child.runtimeType) {
      _startTransition(widget.child);
    }
  }

  void _startTransition(Widget newChild) async {
    _nextChild = newChild;

    if (_phase != _TransitionPhase.idle) {
      return;
    }

    // Phase 1: Wiping In (Covering screen strip by strip)
    setState(() {
      _phase = _TransitionPhase.covering;
    });

    _inController.reset();
    _outController.reset();

    try {
      await _inController.forward().orCancel;
    } on TickerCanceled {
      return;
    }

    if (!mounted) return;

    // Phase 2 & 3: Swap child and immediately launch revealing phase with zero artificial delay
    setState(() {
      _phase = _TransitionPhase.revealing;
      _currentChild = _nextChild ?? widget.child;
      _nextChild = null;
    });

    try {
      await _outController.forward().orCancel;
    } on TickerCanceled {
      return;
    }

    if (mounted) {
      setState(() {
        _phase = _TransitionPhase.idle;
      });
    }
  }

  @override
  void dispose() {
    _inController.dispose();
    _outController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiColors colors = context.uiColors;
    final Color bg = widget.stripColor ?? colors.surface;
    final Color border = widget.borderColor ?? colors.border;

    final double totalMillis =
        _inController.duration!.inMilliseconds.toDouble();
    final double stripMillis = widget.stripDuration.inMilliseconds.toDouble();
    final double staggerMillis = widget.staggerDelay.inMilliseconds.toDouble();

    return ColoredBox(
      color: colors.background,
      child: Stack(
        children: <Widget>[
          // Current Active Page Content
          KeyedSubtree(
            key: ValueKey<Key?>(_currentChild.key),
            child: _currentChild,
          ),

          // Staggered Curtain Strips
          if (_phase != _TransitionPhase.idle)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double stripHeight =
                        constraints.maxHeight / widget.stripCount;

                    return AnimatedBuilder(
                      animation: Listenable.merge(<Listenable>[
                        _inController,
                        _outController,
                      ]),
                      builder: (BuildContext context, Widget? _) {
                        return Stack(
                          children: List<Widget>.generate(
                            widget.stripCount,
                            (int index) {
                              final double start =
                                  (index * staggerMillis) / totalMillis;
                              final double end =
                                  ((index * staggerMillis) + stripMillis) /
                                  totalMillis;

                              double scaleX;
                              Alignment origin;

                              if (_phase == _TransitionPhase.covering) {
                                // Wiping IN from left to right
                                origin = Alignment.centerLeft;
                                final double t = _inController.value;
                                if (t <= start) {
                                  scaleX = 0.0;
                                } else if (t >= end) {
                                  scaleX = 1.0;
                                } else {
                                  final double localT =
                                      ((t - start) / (end - start)).clamp(
                                    0.0,
                                    1.0,
                                  );
                                  scaleX = Curves.easeOutCubic.transform(localT);
                                }
                              } else if (_phase == _TransitionPhase.covered) {
                                // 100% Solidly covering screen
                                origin = Alignment.centerRight;
                                scaleX = 1.0;
                              } else {
                                // Wiping OUT to the right, peeling open strip by strip!
                                origin = Alignment.centerRight;
                                final double t = _outController.value;
                                if (t <= start) {
                                  scaleX = 1.0;
                                } else if (t >= end) {
                                  scaleX = 0.0;
                                } else {
                                  final double localT =
                                      ((t - start) / (end - start)).clamp(
                                    0.0,
                                    1.0,
                                  );
                                  scaleX =
                                      1.0 -
                                      Curves.easeOutCubic.transform(localT);
                                }
                              }

                              return Positioned(
                                top: index * stripHeight,
                                left: 0,
                                right: 0,
                                height:
                                    stripHeight + 1.0, // Subpixel gap prevention
                                child: Transform(
                                  alignment: origin,
                                  transform: Matrix4.diagonal3Values(
                                    scaleX,
                                    1.0,
                                    1.0,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: bg,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: border,
                                          width: 0.75,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
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
    this.duration = const Duration(milliseconds: 650),
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
          final double sigma = (1.0 - value) * 14.0;
          final double opacity = (value * 1.5).clamp(0.0, 1.0);

          Widget content = Opacity(
            opacity: opacity,
            child: childWidget,
          );

          if (sigma > 0.15) {
            content = ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.clamp,
                ),
                child: content,
              ),
            );
          }

          return content;
        },
        child: child,
      ),
    );
  }
}
