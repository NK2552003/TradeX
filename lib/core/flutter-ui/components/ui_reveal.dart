import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';

/// Expands and fades content, retaining it until the closing animation finishes.
/// A null child collapses the region and removes its focus and pointer targets.
class UiReveal extends StatefulWidget {
  const UiReveal({super.key, this.child});
  final Widget? child;

  @override
  State<UiReveal> createState() => _UiRevealState();
}

class _UiRevealState extends State<UiReveal>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  late final _progress = _controller.drive(
    CurveTween(curve: Curves.easeInOutCubic),
  );
  Widget? _content;

  @override
  void initState() {
    super.initState();
    _content = widget.child;
    _controller.value = _content == null ? 0 : 1;
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.child == null) {
        setState(() => _content = null);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : context.ui.motion.slow;
    _controller.reverseDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : context.ui.motion.normal;
  }

  @override
  void didUpdateWidget(UiReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.child != null) {
      _content = widget.child;
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: _progress,
    alignment: Alignment.topCenter,
    child: FadeTransition(
      opacity: _progress,
      child: IgnorePointer(
        ignoring: widget.child == null,
        child: ExcludeFocus(
          excluding: widget.child == null,
          child: ExcludeSemantics(
            excluding: widget.child == null,
            child: _content ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
