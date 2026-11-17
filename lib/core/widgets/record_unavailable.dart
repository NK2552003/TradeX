import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class RecordOpeningBanner extends StatelessWidget {
  const RecordOpeningBanner({
    super.key,
    required this.title,
    this.subtitle = 'Loading record details...',
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.sz(460)),
        child: Padding(
          padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
          child: UiCard(
            variant: UiCardVariant.surface,
            padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                UiProgressCircle(size: context.sz(36)),
                UiGap.v(theme.spacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: context.uiText.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                UiGap.v(theme.spacing.xs),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: context.uiText.body.copyWith(
                    color: theme.colors.foregroundMuted,
                  ),
                ),
                if (onBack != null) ...[
                  UiGap.v(theme.spacing.md),
                  UiButton(
                    label: 'Cancel',
                    leadingIcon: Icons.arrow_back_rounded,
                    variant: UiVariant.ghost,
                    size: UiSize.sm,
                    onPressed: onBack,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecordUnavailable extends StatelessWidget {
  const RecordUnavailable({
    super.key,
    required this.message,
    this.title = 'Record unavailable',
    required this.onBack,
  });

  final String message;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SizedBox(
      width: double.infinity,
      height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
      child: UiCard(
        padding: EdgeInsets.zero,
        child: Center(
          child: UiEmptyState(
            icon: Icons.article_outlined,
            title: title,
            message: message,
            action: UiButton(
              label: 'Go back',
              leadingIcon: Icons.arrow_back_rounded,
              onPressed: onBack,
            ),
          ),
        ),
      ),
    ),
  );
}
