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
class UiAsyncView extends StatelessWidget {
  const UiAsyncView({
    super.key,
    required this.builder,
    this.loading = false,
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

  final WidgetBuilder builder;
  final bool loading;
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
    if (loading) {
      return loadingBuilder?.call(context) ??
          Padding(
            padding: EdgeInsets.all(context.sp(context.uiSpace.xl)),
            child: Center(
              child: SizedBox(
                width: context.sz(24),
                height: context.sz(24),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.uiColors.primary,
                ),
              ),
            ),
          );
    }
    if (error != null) {
      return UiEmptyState(
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
    }
    if (isEmpty) {
      return UiEmptyState(
        title: emptyTitle,
        message: emptyMessage,
        icon: emptyIcon,
        action: emptyAction,
      );
    }
    return builder(context);
  }
}
