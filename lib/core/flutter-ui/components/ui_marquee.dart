import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Continuous scrolling ticker text or widget banner (e.g. live prices, breaking news).
class UiMarquee extends StatefulWidget {
  const UiMarquee({
    super.key,
    required this.text,
    this.textStyle,
    this.velocity = 40.0,
    this.blankSpace = 48.0,
    this.pauseOnHover = true,
    this.padding = EdgeInsets.zero,
  });

  final String text;
  final TextStyle? textStyle;
  final double velocity;
  final double blankSpace;
  final bool pauseOnHover;
  final EdgeInsetsGeometry padding;

  @override
  State<UiMarquee> createState() => _UiMarqueeState();
}

class _UiMarqueeState extends State<UiMarquee>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController = ScrollController();
  bool _hovered = false;
  bool _running = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScroll());
  }

  void _startScroll() async {
    if (!mounted) return;
    _running = true;
    while (mounted && _running) {
      if (!_hovered &&
          _scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        final double max = _scrollController.position.maxScrollExtent;
        if (max > 0) {
          final double current = _scrollController.offset;
          final double remaining = max - current;
          final int durationMs = ((remaining / widget.velocity) * 1000).toInt();
          if (durationMs > 50) {
            await _scrollController.animateTo(
              max,
              duration: Duration(milliseconds: durationMs),
              curve: Curves.linear,
            );
          }
          if (mounted && _scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      }
      if (!mounted || !_running) break;
      final Completer<void> completer = Completer<void>();
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 100), () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      });
      await completer.future;
    }
  }

  @override
  void dispose() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final TextStyle style =
        widget.textStyle ??
        context.uiText.body.copyWith(
          color: theme.colors.foreground,
          fontWeight: FontWeight.w500,
        );

    final Widget textWidget = Text(
      widget.text,
      style: style,
      maxLines: 1,
      softWrap: false,
    );

    return MouseRegion(
      onEnter: widget.pauseOnHover
          ? (_) => setState(() => _hovered = true)
          : null,
      onExit: widget.pauseOnHover
          ? (_) => setState(() => _hovered = false)
          : null,
      child: Padding(
        padding: widget.padding,
        child: ClipRect(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                textWidget,
                SizedBox(width: widget.blankSpace),
                textWidget,
                SizedBox(width: widget.blankSpace),
                textWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
