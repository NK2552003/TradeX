import 'package:flutter/material.dart';
import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_toast.dart';

/// Sonner-style Toast host. Wrap the app body once, then call `UiToast.show(...)`.
class UiToastScope extends StatefulWidget {
  const UiToastScope({super.key, required this.child});

  final Widget child;

  @override
  State<UiToastScope> createState() => UiToastScopeState();

  static UiToastScopeState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<UiToastScopeState>();
  }

  static UiToastScopeState of(BuildContext context) {
    final UiToastScopeState? state = maybeOf(context);
    assert(state != null, 'Wrap your app with UiToastScope');
    return state!;
  }
}

class UiToastData {
  UiToastData({
    required this.title,
    this.message,
    this.intent = UiIntent.neutral,
    this.icon,
    this.actionLabel,
    this.onAction,
    this.duration = const Duration(seconds: 4),
  }) : id = UniqueKey().toString();

  final String id;
  final String title;
  final String? message;
  final UiIntent intent;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UiToastData && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

class UiToastScopeState extends State<UiToastScope> {
  final List<UiToastData> _queue = <UiToastData>[];

  void show(UiToastData toast) {
    setState(() {
      _queue.add(toast);
      if (_queue.length > 5) {
        _queue.removeAt(0);
      }
    });

    Future<void>.delayed(toast.duration, () {
      if (mounted && _queue.contains(toast)) {
        dismiss(toast);
      }
    });
  }

  void dismiss(UiToastData toast) {
    if (_queue.contains(toast)) {
      setState(() => _queue.remove(toast));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final bool mobile = context.uiRes.isMobile;

    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          left: mobile ? context.sp(theme.spacing.md) : null,
          right: context.sp(theme.spacing.lg),
          bottom: context.sp(theme.spacing.lg),
          child: SafeArea(
            child: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle(
                style: TextStyle(
                  fontFamily: theme.typography.fontFamily,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  crossAxisAlignment:
                      mobile ? CrossAxisAlignment.center : CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int i = 0; i < _queue.length; i++)
                      Padding(
                        padding: EdgeInsets.only(top: context.sp(theme.spacing.xs)),
                        child: AnimatedSlide(
                          offset: Offset.zero,
                          duration: theme.motion.fast,
                          curve: theme.motion.curve,
                          child: AnimatedOpacity(
                            opacity: 1.0,
                            duration: theme.motion.fast,
                            child: UiToast(
                              data: _queue[i],
                              onDismiss: () => dismiss(_queue[i]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
