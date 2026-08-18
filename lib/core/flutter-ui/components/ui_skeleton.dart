import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Polished, low-contrast loading placeholder with a restrained light sweep.
class UiSkeleton extends StatefulWidget {
  const UiSkeleton({super.key, this.width, this.height, this.circle = false});

  final double? width;
  final double? height;
  final bool circle;

  @override
  State<UiSkeleton> createState() => _UiSkeletonState();
}

class _UiSkeletonState extends State<UiSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final double height = context.sz(widget.height ?? 14);
    final BorderRadius radius = context.radius(
      height >= context.sz(44) ? theme.radii.md : theme.radii.sm,
    );

    return SizedBox(
      width: widget.circle
          ? context.sz(widget.width ?? widget.height ?? 14)
          : widget.width,
      height: widget.circle
          ? context.sz(widget.width ?? widget.height ?? 14)
          : height,
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints constraints) {
          final Widget shimmer = AnimatedBuilder(
            animation: _controller,
            builder: (BuildContext context, Widget? child) {
              final double travel = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : context.sz(240);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ColoredBox(
                    color: theme.colors.surfaceMuted.withValues(alpha: 0.82),
                  ),
                  Transform.translate(
                    offset: Offset(
                      ((_controller.value * 2.4) - 1.2) * travel,
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 0.42,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              theme.colors.foreground.withValues(alpha: 0.055),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
          return widget.circle
              ? ClipOval(child: shimmer)
              : ClipRRect(borderRadius: radius, child: shimmer);
        },
      ),
    );
  }
}
