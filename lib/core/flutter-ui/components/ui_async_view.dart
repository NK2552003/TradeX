import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_button.dart';
import 'ui_common.dart';
import 'ui_empty_state.dart';

/// One switch for the four states every data-backed screen has:
/// loading -> error -> empty -> content.
///
/// This is the wrapper the screen specs call for so Loading / Error / Empty
/// never have to be re-implemented per screen.
class UiAsyncView<T> extends StatelessWidget {
  const UiAsyncView({
    super.key,
    this.builder,
    this.state,
    this.data,
    this.loading = false,
    this.loadingMessage,
    this.error,
    this.isEmpty = false,
    this.onRetry,
    this.loadingBuilder,
    this.emptyTitle = 'Nothing here yet',
    this.emptyMessage,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
    this.errorTitle = 'Something went wrong',
  });

  final dynamic builder;
  final dynamic state;
  final T? data;
  final bool loading;
  final String? loadingMessage;
  final String? error;
  final bool isEmpty;
  final VoidCallback? onRetry;
  final WidgetBuilder? loadingBuilder;
  final String emptyTitle;
  final String? emptyMessage;
  final IconData emptyIcon;
  final Widget? emptyAction;
  final String errorTitle;

  @override
  Widget build(BuildContext context) {
    bool isLoading = loading;
    String? err = error;
    bool empty = isEmpty;
    T? resolvedData = data;

    if (state != null) {
      if (state is AsyncSnapshot) {
        final AsyncSnapshot snap = state as AsyncSnapshot;
        if (snap.connectionState == ConnectionState.waiting) {
          isLoading = true;
        } else if (snap.hasError) {
          err = snap.error?.toString() ?? 'An unexpected error occurred';
        } else {
          resolvedData = snap.data as T?;
          if (resolvedData == null ||
              (resolvedData is Iterable && resolvedData.isEmpty)) {
            empty = true;
          }
        }
      }
    }

    if (isLoading) {
      return loadingBuilder?.call(context) ??
          Padding(
            padding: EdgeInsets.all(context.sp(context.uiSpace.xl)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: context.sz(24),
                    height: context.sz(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.uiColors.primary,
                    ),
                  ),
                  if (loadingMessage != null) ...<Widget>[
                    SizedBox(height: context.sp(context.uiSpace.md)),
                    Text(
                      loadingMessage!,
                      style: context.uiText.caption.copyWith(
                        color: context.uiColors.foregroundMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
    }
    if (err != null) {
      return UiEmptyState(
        title: errorTitle,
        message: err,
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
    }
    if (empty) {
      return UiEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: emptyIcon,
        action: emptyAction,
      );
    }
    if (builder != null) {
      if (builder is Widget Function(BuildContext)) {
        return (builder as Widget Function(BuildContext))(context);
      }
      if (builder is Widget Function(T)) {
        return (builder as Widget Function(T))(resolvedData as T);
      }
      try {
        return (builder as dynamic)(resolvedData ?? context) as Widget;
      } catch (_) {
        return (builder as dynamic)(context) as Widget;
      }
    }
    return const SizedBox.shrink();
  }
}

/// A self-contained demo/utility card that exposes the four async states of
/// [UiAsyncView] behind a segmented switcher. Useful in showcases, empty
/// dashboards and any screen that wants users to preview a data state.
class UiAsyncViewStateCard extends StatefulWidget {
  const UiAsyncViewStateCard({
    super.key,
    required this.contentBuilder,
    this.title,
    this.subtitle,
    this.initialStatus = UiStatus.ready,
    this.loadingMessage = 'Fetching live market orderbook & quotes...',
    this.errorMessage = 'Failed to fetch live quotes',
    this.emptyTitle = 'No active orders',
    this.emptyMessage = 'Data will appear once it is available.',
    this.onRetry,
    this.showSwitcher = true,
    this.onStatusChanged,
  });

  final WidgetBuilder contentBuilder;
  final String? title;
  final String? subtitle;
  final UiStatus initialStatus;
  final String loadingMessage;
  final String errorMessage;
  final String emptyTitle;
  final String emptyMessage;
  final VoidCallback? onRetry;
  final bool showSwitcher;
  final ValueChanged<UiStatus>? onStatusChanged;

  @override
  State<UiAsyncViewStateCard> createState() => _UiAsyncViewStateCardState();
}

class _UiAsyncViewStateCardState extends State<UiAsyncViewStateCard> {
  late UiStatus _status = widget.initialStatus;

  static const List<UiStatus> _states = <UiStatus>[
    UiStatus.ready,
    UiStatus.loading,
    UiStatus.empty,
    UiStatus.error,
  ];

  String _label(UiStatus s) {
    switch (s) {
      case UiStatus.ready:
        return 'Content';
      case UiStatus.loading:
        return 'Loading';
      case UiStatus.empty:
        return 'Empty';
      case UiStatus.error:
        return 'Error';
      case UiStatus.idle:
        return 'Idle';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.title != null)
          Text(
            widget.title!,
            style: context.uiText.subheading.copyWith(
              color: theme.colors.foreground,
            ),
          ),
        if (widget.subtitle != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xxs)),
          Text(
            widget.subtitle!,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundMuted,
            ),
          ),
        ],
        if (widget.showSwitcher) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.sm)),
          Wrap(
            spacing: context.sp(theme.spacing.xs),
            children: <Widget>[
              for (final UiStatus s in _states)
                UiButton(
                  label: _label(s),
                  size: UiSize.xs,
                  variant: _status == s ? UiVariant.soft : UiVariant.outline,
                  intent: _status == s ? UiIntent.primary : UiIntent.neutral,
                  expandOnMobile: false,
                  onPressed: () {
                    setState(() => _status = s);
                    widget.onStatusChanged?.call(s);
                  },
                ),
            ],
          ),
        ],
        SizedBox(height: context.sp(theme.spacing.md)),
        UiAsyncView(
          loading: _status == UiStatus.loading,
          loadingMessage: widget.loadingMessage,
          isEmpty: _status == UiStatus.empty,
          error: _status == UiStatus.error ? widget.errorMessage : null,
          emptyTitle: widget.emptyTitle,
          emptyMessage: widget.emptyMessage,
          onRetry:
              widget.onRetry ?? () => setState(() => _status = UiStatus.ready),
          builder: widget.contentBuilder,
        ),
      ],
    );
  }
}
