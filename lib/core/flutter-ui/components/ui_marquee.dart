import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Continuously scrolling ticker tape (market movers strip).
class UiMarquee extends StatefulWidget {
  const UiMarquee({
    super.key,
    required this.children,
    this.speed = 40,
    this.spacing,
    this.paused = false,
  });

  final List<Widget> children;

  /// Logical pixels per second.
  final double speed;
  final double? spacing;
  final bool paused;

  @override
  State<UiMarquee> createState() => _UiMarqueeState();
}

class _UiMarqueeState extends State<UiMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  final ScrollController _scroll = ScrollController();
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_tick);
  }

  void _tick() {
    if (widget.paused || !_scroll.hasClients) return;
    final Duration now = _controller.lastElapsedDuration ?? Duration.zero;
    final double dt =
        ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final double max = _scroll.position.maxScrollExtent;
    if (max <= 0) return;
    double next = _scroll.offset + widget.speed * dt;
    if (next >= max) next = 0;
    _scroll.jumpTo(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double gap = context.sp(widget.spacing ?? context.uiSpace.xl);
    final List<Widget> loop = <Widget>[...widget.children, ...widget.children];
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: <Widget>[
          for (final Widget child in loop)
            Padding(
              padding: EdgeInsets.only(right: gap),
              child: child,
            ),
        ],
      ),
    );
  }
}
