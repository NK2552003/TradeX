import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_card.dart';
import 'ui_common.dart';
import 'ui_empty_state.dart';
import 'ui_toggle_group.dart';

/// One switch for the four states every data-backed screen has:
/// loading -> error -> empty -> content.
///
/// This is the wrapper the screen specs call for so Loading / Error / Empty
/// never have to be re-implemented per screen.
class UiAsyncView extends StatelessWidget {
  const UiAsyncView({
    super.key,
    required this.builder,
    this.loading = false,
    this.error,
    this.isEmpty = false,
    this.onRetry,
    this.loadingBuilder,
    this.loadingMessage,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.errorTitle = 'Something went wrong',
    this.animateStateTransitions = true,
  });

  final WidgetBuilder builder;
  final bool loading;
  final String? error;
  final bool isEmpty;
  final VoidCallback? onRetry;
  final WidgetBuilder? loadingBuilder;
  final String? loadingMessage;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final String errorTitle;
  final bool animateStateTransitions;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    Widget child;
    Key key;

    if (loading) {
      key = const ValueKey<String>('async_state_loading');
      child = loadingBuilder?.call(context) ??
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: context.sp(theme.spacing.xl),
              horizontal: context.sp(theme.spacing.lg),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: context.sz(28),
                    height: context.sz(28),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colors.primary,
                    ),
                  ),
                  if (loadingMessage != null) ...<Widget>[
                    SizedBox(height: context.sp(theme.spacing.md)),
                    Text(
                      loadingMessage!,
                      style: context.uiText.caption.copyWith(
                        color: theme.colors.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
    } else if (error != null) {
      key = ValueKey<String>('async_state_error_$error');
      child = UiEmptyState(
        title: errorTitle,
        message: error,
        icon: Icons.error_outline,
        action: onRetry == null
            ? null
            : UiButton(
                label: 'Retry',
                variant: UiVariant.outline,
                leadingIcon: Icons.refresh,
                expandOnMobile: false,
                onPressed: onRetry,
              ),
      );
    } else if (isEmpty) {
      key = const ValueKey<String>('async_state_empty');
      child = UiEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: emptyIcon,
        action: emptyAction,
      );
    } else {
      key = const ValueKey<String>('async_state_content');
      child = builder(context);
    }

    if (!animateStateTransitions) return child;

    return AnimatedSwitcher(
      duration: theme.motion.fast,
      switchInCurve: theme.motion.curve,
      switchOutCurve: theme.motion.curve,
      child: KeyedSubtree(
        key: key,
        child: child,
      ),
    );
  }
}

/// Interactive Card wrapper for testing and demonstrating UiAsyncView states
/// (Data Ready, Loading, Error, Empty).
class UiAsyncViewStateCard extends StatefulWidget {
  const UiAsyncViewStateCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.contentBuilder,
    this.initialState = 'ready',
    this.onStateChanged,
  });

  final String title;
  final String? subtitle;
  final WidgetBuilder contentBuilder;
  final String initialState; // 'ready', 'loading', 'error', 'empty'
  final ValueChanged<String>? onStateChanged;

  @override
  State<UiAsyncViewStateCard> createState() => _UiAsyncViewStateCardState();
}

class _UiAsyncViewStateCardState extends State<UiAsyncViewStateCard> {
  late String _state;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _setState(String s) {
    setState(() => _state = s);
    widget.onStateChanged?.call(s);
  }

  void _simulateAsyncFetch() async {
    if (_isSimulating) return;
    setState(() {
      _isSimulating = true;
      _state = 'loading';
    });
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isSimulating = false;
        _state = 'ready';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return UiCard(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              UiToggleGroup<String>(
                value: _state,
                options: const <UiToggleOption<String>>[
                  UiToggleOption<String>(value: 'ready', label: 'Data Ready'),
                  UiToggleOption<String>(value: 'loading', label: 'Loading'),
                  UiToggleOption<String>(value: 'error', label: 'Error'),
                  UiToggleOption<String>(value: 'empty', label: 'Empty'),
                ],
                onChanged: _setState,
              ),
              UiButton(
                label: _isSimulating ? 'Fetching...' : 'Simulate Load',
                variant: UiVariant.ghost,
                size: UiSize.sm,
                leadingIcon: Icons.bolt,
                onPressed: _isSimulating ? null : _simulateAsyncFetch,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiAsyncView(
            loading: _state == 'loading',
            loadingMessage: 'Fetching live market orderbook & quotes...',
            error: _state == 'error'
                ? 'Network Connection Timeout (504 Gateway Error)'
                : null,
            errorTitle: 'Failed to fetch live quotes',
            onRetry: () => _setState('ready'),
            isEmpty: _state == 'empty',
            emptyTitle: 'No active orders',
            emptyMessage: 'Place a buy or sell trade to populate your order history.',
            emptyIcon: Icons.receipt_long_outlined,
            emptyAction: UiButton(
              label: 'Place Order',
              leadingIcon: Icons.add,
              expandOnMobile: false,
              onPressed: () => _setState('ready'),
            ),
            builder: widget.contentBuilder,
          ),
        ],
      ),
    );
  }
}
