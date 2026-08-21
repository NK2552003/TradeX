import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';

/// Shared motion helpers. Every duration/curve resolves from `theme.motion`
/// so motion stays consistent with the design system.
class AppMotion {
  const AppMotion._();

  static Duration fast(BuildContext context) => context.uiMotion.fast;
  static Duration normal(BuildContext context) => context.uiMotion.normal;
  static Duration slow(BuildContext context) => context.uiMotion.slow;
  static Curve curve(BuildContext context) => context.uiMotion.curve;

  /// Stagger step between siblings in a list/grid entrance.
  static const Duration step = Duration(milliseconds: 45);

  /// Wraps each child in an [AppFadeIn] with an increasing delay.
  static List<Widget> stagger(
    List<Widget> children, {
    Duration step = AppMotion.step,
    double offset = 12,
    bool enabled = true,
  }) {
    if (!enabled) return children;
    return List<Widget>.generate(
      children.length,
      (int i) => AppFadeIn(delay: step * i, offset: offset, child: children[i]),
    );
  }
}

/// Fade + slide entrance. Runs once on mount.
class AppFadeIn extends StatefulWidget {
  const AppFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 12,
    this.horizontal = false,
  });

  final Widget child;
  final Duration delay;
  final double offset;
  final bool horizontal;

  @override
  State<AppFadeIn> createState() => _AppFadeInState();
}

class _AppFadeInState extends State<AppFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Curve curve = context.uiMotion.curve;
    final Animation<double> t = CurvedAnimation(
      parent: _controller,
      curve: curve,
    );
    return AnimatedBuilder(
      animation: t,
      builder: (BuildContext context, Widget? child) {
        final double dy = widget.horizontal ? 0 : widget.offset * (1 - t.value);
        final double dx = widget.horizontal ? widget.offset * (1 - t.value) : 0;
        return Opacity(
          opacity: t.value.clamp(0, 1),
          child: Transform.translate(offset: Offset(dx, dy), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Animated numeric value. Counts up/down whenever [value] changes.
class AppCountUp extends StatelessWidget {
  const AppCountUp({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 700),
    this.textAlign,
  });

  final num value;
  final String Function(num value) formatter;
  final TextStyle? style;
  final Duration duration;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: context.uiMotion.curve,
      builder: (BuildContext context, double v, Widget? _) => Text(
        formatter(v),
        style: style,
        textAlign: textAlign,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Desktop hover lift: subtle scale + shadow. No-ops on touch layouts.
class AppHoverLift extends StatefulWidget {
  const AppHoverLift({
    super.key,
    required this.child,
    this.scale = 1.015,
    this.enabled = true,
  });

  final Widget child;
  final double scale;
  final bool enabled;

  @override
  State<AppHoverLift> createState() => _AppHoverLiftState();
}

class _AppHoverLiftState extends State<AppHoverLift> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && context.uiRes.isDesktop;
    if (!active) return widget.child;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? widget.scale : 1,
        duration: context.uiMotion.fast,
        curve: context.uiMotion.curve,
        child: AnimatedContainer(
          duration: context.uiMotion.fast,
          decoration: BoxDecoration(
            borderRadius: context.radius(context.uiRadii.xl),
            boxShadow: _hovered ? context.uiShadows.md : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Reveals a chart/graphic by animating a 0..1 progress value.
class AppReveal extends StatelessWidget {
  const AppReveal({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 800),
  });

  final Widget Function(BuildContext context, double t) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: 1),
    duration: duration,
    curve: context.uiMotion.curve,
    builder: (BuildContext context, double t, Widget? _) => builder(context, t),
  );
}

/// Expand/collapse with a fade, used by sidebar labels and detail rows.
class AppCollapse extends StatelessWidget {
  const AppCollapse({
    super.key,
    required this.expanded,
    required this.child,
    this.axis = Axis.vertical,
  });

  final bool expanded;
  final Widget child;
  final Axis axis;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: context.uiMotion.normal,
    curve: context.uiMotion.curve,
    alignment: axis == Axis.vertical
        ? Alignment.topCenter
        : Alignment.centerLeft,
    child: AnimatedOpacity(
      duration: context.uiMotion.normal,
      opacity: expanded ? 1 : 0,
      child: expanded ? child : const SizedBox.shrink(),
    ),
  );
}
