import 'package:flutter/material.dart';

import '../../flutter-ui/flutter_ui.dart';
import '../theme/app_tokens.dart';

/// A unified header component for feature landing pages.
///
/// Displays an eyebrow label, title, description, and optional CTA actions.
/// Adapts layout for mobile (stacked) and desktop (horizontal).
class AppFeatureHeader extends StatelessWidget {
  const AppFeatureHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.description,
    this.primaryAction,
    this.secondaryAction,
    this.helpAction,
    this.compact = false,
  });

  /// Eyebrow text shown above the title (e.g., "Where you define your playbooks")
  final String eyebrow;

  /// Main title (e.g., "Linked Strategies")
  final String title;

  /// Optional description below the title
  final String? description;

  /// Primary CTA button (e.g., "+ New Playbook")
  final Widget? primaryAction;

  /// Secondary action button (e.g., template selector)
  final Widget? secondaryAction;

  /// Help/guide action button (defaults to info icon)
  final VoidCallback? helpAction;

  /// Use compact layout with reduced spacing
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final double gutter = context.sp(compact ? theme.spacing.sm : theme.spacing.md);

    return Container(
      padding: EdgeInsets.only(
        bottom: gutter,
        top: context.sp(theme.spacing.xs),
      ),
      child: isMobile ? _buildMobileLayout(context) : _buildDesktopLayout(context),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final UiTheme theme = context.ui;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    eyebrow,
                    style: context.uiText.label.copyWith(
                      color: context.uiColors.foregroundMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    title,
                    style: context.uiText.heading,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (helpAction != null)
              Padding(
                padding: EdgeInsets.only(left: context.sp(theme.spacing.sm)),
                child: UiIconButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'View guide',
                  size: UiSize.sm,
                  onPressed: helpAction,
                ),
              ),
          ],
        ),
        if (description != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.xs)),
          Text(
            description!,
            style: context.uiText.body.copyWith(
              color: context.uiColors.foregroundMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (primaryAction != null || secondaryAction != null) ...<Widget>[
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: context.sp(theme.spacing.sm),
            runSpacing: context.sp(theme.spacing.sm),
            children: <Widget>[
              if (primaryAction != null) primaryAction!,
              if (secondaryAction != null) secondaryAction!,
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final UiTheme theme = context.ui;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                eyebrow,
                style: context.uiText.label.copyWith(
                  color: context.uiColors.foregroundMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: context.sp(theme.spacing.xxs)),
              Text(
                title,
                style: context.uiText.display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (description != null) ...<Widget>[
                SizedBox(height: context.sp(theme.spacing.xs)),
                Text(
                  description!,
                  style: context.uiText.body.copyWith(
                    color: context.uiColors.foregroundMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: context.sp(theme.spacing.lg)),
        if (helpAction != null)
          UiIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'View guide',
            size: UiSize.md,
            onPressed: helpAction,
          ),
        SizedBox(width: context.sp(theme.spacing.md)),
        if (secondaryAction != null) ...<Widget>[
          secondaryAction!,
          SizedBox(width: context.sp(theme.spacing.sm)),
        ],
        if (primaryAction != null) primaryAction!,
      ],
    );
  }
}
