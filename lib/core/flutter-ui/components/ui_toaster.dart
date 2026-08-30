import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/ui_theme.dart';
import 'ui_common.dart';
import 'ui_toast.dart';

/// Sonner-style toast host. Wrap the app body once, then call
/// `UiToast.show(...)` from anywhere below it.
///
/// Behaviour worth knowing about:
/// - **No duplicates.** Firing the same toast again while it is still on screen
///   refreshes it and bumps a counter instead of stacking a second copy, so a
///   button mashed five times reads as "×5", not as five identical cards.
/// - **Real motion.** Every toast owns an enter/exit animation and is only
///   removed from the tree once its exit has played.
/// - **Bounded stack.** At most [maxVisible] cards are alive; older ones are
///   pushed out and read as depth (slightly smaller, slightly dimmer).
class UiToastScope extends StatefulWidget {
  const UiToastScope({
    super.key,
    required this.child,
    this.maxVisible = 3,
    this.mobileBottomInset = 88.0,
  });

  final Widget child;

  /// How many toasts may be on screen at once.
  final int maxVisible;

  /// Room reserved above the phone dock. The host sits above the app shell, so
  /// it cannot read the dock footprint the shell publishes to its own pages.
  final double mobileBottomInset;

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
    String? dedupeKey,
  }) : id = UniqueKey().toString(),
       dedupeKey =
           dedupeKey ?? '$title|${message ?? ''}|${intent.name}|$actionLabel';

  final String id;
  final String title;
  final String? message;
  final UiIntent intent;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  /// Identity used to collapse repeats. Two toasts sharing a key are the same
  /// notification fired twice, not two notifications.
  final String dedupeKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is UiToastData && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// One live toast: its data, its motion, and its auto-dismiss timer.
class _ToastEntry {
  _ToastEntry({required this.data, required this.controller});

  UiToastData data;
  final AnimationController controller;
  Timer? timer;

  /// How many times this notification has fired while visible.
  int count = 1;
  bool leaving = false;

  void dispose() {
    timer?.cancel();
    controller.dispose();
  }
}

class UiToastScopeState extends State<UiToastScope>
    with TickerProviderStateMixin {
  final List<_ToastEntry> _entries = <_ToastEntry>[];

  static const Duration _enter = Duration(milliseconds: 260);
  static const Duration _exit = Duration(milliseconds: 180);

  void show(UiToastData toast) {
    // Same notification, still on screen: refresh it rather than duplicate it.
    for (final _ToastEntry entry in _entries) {
      if (entry.leaving || entry.data.dedupeKey != toast.dedupeKey) continue;
      setState(() {
        entry.count++;
        entry.data = toast;
      });
      // A short dip back into the enter curve reads as "it fired again".
      entry.controller.value = 0.82;
      entry.controller.forward();
      _arm(entry);
      return;
    }

    final _ToastEntry entry = _ToastEntry(
      data: toast,
      controller: AnimationController(
        vsync: this,
        duration: _enter,
        reverseDuration: _exit,
      ),
    );
    setState(() => _entries.add(entry));
    entry.controller.forward();
    _arm(entry);

    while (_entries.where((_ToastEntry e) => !e.leaving).length >
        widget.maxVisible) {
      final _ToastEntry oldest = _entries.firstWhere(
        (_ToastEntry e) => !e.leaving,
      );
      _dismissEntry(oldest);
    }
  }

  void dismiss(UiToastData toast) {
    for (final _ToastEntry entry in _entries) {
      if (entry.data.id == toast.id ||
          entry.data.dedupeKey == toast.dedupeKey) {
        _dismissEntry(entry);
        return;
      }
    }
  }

  /// Clears everything currently on screen.
  void dismissAll() {
    for (final _ToastEntry entry in _entries.toList()) {
      _dismissEntry(entry);
    }
  }

  void _arm(_ToastEntry entry) {
    entry.timer?.cancel();
    entry.timer = Timer(entry.data.duration, () => _dismissEntry(entry));
  }

  void _dismissEntry(_ToastEntry entry) {
    if (entry.leaving || !_entries.contains(entry)) return;
    entry.timer?.cancel();
    entry.leaving = true;
    if (mounted) setState(() {});
    entry.controller.reverse().whenComplete(() {
      if (!mounted) {
        entry.dispose();
        return;
      }
      setState(() => _entries.remove(entry));
      entry.dispose();
    });
  }

  @override
  void dispose() {
    for (final _ToastEntry entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool mobile = context.uiRes.isMobile;
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = mobile
        ? (keyboardInset > 0
              ? keyboardInset + context.sp(theme.spacing.md)
              : widget.mobileBottomInset)
        : context.sp(theme.spacing.lg);

    final List<_ToastEntry> live = _entries.toList();
    final int liveCount = live.where((_ToastEntry e) => !e.leaving).length;

    return Stack(
      children: <Widget>[
        widget.child,
        if (live.isNotEmpty)
          Positioned(
            left: mobile ? context.sp(theme.spacing.md) : null,
            right: mobile
                ? context.sp(theme.spacing.md)
                : context.sp(theme.spacing.lg),
            bottom: bottomInset,
            child: SafeArea(
              bottom: !mobile,
              child: Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: theme.typography.fontFamily,
                    decoration: TextDecoration.none,
                  ),
                  child: Column(
                    crossAxisAlignment: mobile
                        ? CrossAxisAlignment.stretch
                        : CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int i = 0; i < live.length; i++)
                        _buildEntry(
                          context,
                          live[i],
                          // Newest sits at the bottom; anything above it reads
                          // as depth in the pile.
                          depth: math.max(0, liveCount - 1 - i),
                          isFirst: i == 0,
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

  Widget _buildEntry(
    BuildContext context,
    _ToastEntry entry, {
    required int depth,
    required bool isFirst,
  }) {
    final UiTheme theme = context.ui;
    final double gap = context.sp(theme.spacing.sm);

    return AnimatedBuilder(
      animation: entry.controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOutCubic.transform(
          entry.controller.value.clamp(0.0, 1.0),
        );
        // Depth reads as a slightly smaller, slightly dimmer card behind the
        // newest one — Sonner's stacked pile, without overlapping hit targets.
        final double depthScale = 1 - (depth * 0.025).clamp(0.0, 0.075);
        final double depthOpacity = 1 - (depth * 0.18).clamp(0.0, 0.45);

        return ClipRect(
          child: Align(
            heightFactor: t,
            child: Opacity(
              opacity: t * depthOpacity,
              child: Transform.translate(
                offset: Offset(0, (1 - t) * context.sz(14)),
                child: Transform.scale(
                  scale: (0.94 + (0.06 * t)) * depthScale,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(top: isFirst ? 0 : gap),
        child: UiToast(
          data: entry.data,
          count: entry.count,
          onDismiss: () => _dismissEntry(entry),
        ),
      ),
    );
  }
}
