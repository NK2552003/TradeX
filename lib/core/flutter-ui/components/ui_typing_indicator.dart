import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Three-dot "assistant is typing" indicator for AI chat and DMs.
class UiTypingIndicator extends StatefulWidget {
  const UiTypingIndicator({super.key, this.label, this.color});

  final String? label;
  final Color? color;

  @override
  State<UiTypingIndicator> createState() => _UiTypingIndicatorState();
}

class _UiTypingIndicatorState extends State<UiTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = widget.color ?? context.uiColors.foregroundMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 3; i++) ...<Widget>[
          SizedBox(
            width: context.sz(8),
            height: context.sz(8),
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext ctx, Widget? _) {
                  final double t = ((_controller.value + i * 0.2) % 1.0);
                  final double scale = 0.6 + 0.4 * (1 - (t - 0.5).abs() * 2);
                  return Container(
                    width: ctx.sz(6) * scale,
                    height: ctx.sz(6) * scale,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.4 + 0.6 * scale),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ),
          ),
          if (i < 2) SizedBox(width: context.sp(context.uiSpace.xxs)),
        ],
        if (widget.label != null) ...<Widget>[
          SizedBox(width: context.sp(context.uiSpace.xs)),
          Text(
            widget.label!,
            style: context.uiText.caption.copyWith(color: color),
          ),
        ],
      ],
    );
  }
}
