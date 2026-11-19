import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alphajournal/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

class AiOutputGrowthNotification extends Notification {
  const AiOutputGrowthNotification();
}

/// A fixed-size cursor keeps its line stable while blinking.
class AiTypingCursor extends StatefulWidget {
  const AiTypingCursor({super.key, this.style});
  final TextStyle? style;
  @override
  State<AiTypingCursor> createState() => _AiTypingCursorState();
}

class _AiTypingCursorState extends State<AiTypingCursor> {
  Timer? _blink;
  bool _visible = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _blink?.cancel();
    _visible = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() => _visible = !_visible);
      });
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Opacity(
      opacity: _visible ? 1 : 0,
      child: Text(
        '▍',
        style: (widget.style ?? context.uiText.body).copyWith(
          color: context.ui.colors.primary,
        ),
      ),
    ),
  );
}
