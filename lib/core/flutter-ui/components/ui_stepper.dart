import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

@immutable
class UiStepperStep {
  const UiStepperStep({
    required this.title,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
}

/// Progress stepper for onboarding, checkout and multi-step create flows.
/// Horizontal on wide screens, vertical on phones.
class UiStepper extends StatelessWidget {
  const UiStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.onStepTap,
    this.forceVertical = false,
  });

  final List<UiStepperStep> steps;
  final int currentIndex;
  final ValueChanged<int>? onStepTap;
  final bool forceVertical;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool vertical = forceVertical || context.uiRes.isMobile;

    Widget dot(int i) {
      final bool done = i < currentIndex;
      final bool active = i == currentIndex;
      final Color color = done || active
          ? theme.colors.primary
          : theme.colors.borderStrong;
      return Container(
        width: context.sz(26),
        height: context.sz(26),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : theme.colors.surface,
          border: Border.all(color: color, width: theme.borders.thick),
        ),
        alignment: Alignment.center,
        child: done
            ? Icon(
                Icons.check,
                size: context.sz(theme.sizes.iconSm),
                color: theme.colors.onPrimary,
              )
            : Text(
                '${i + 1}',
                style: context.uiText.caption.copyWith(
                  color: active
                      ? theme.colors.primary
                      : theme.colors.foregroundMuted,
                ),
              ),
      );
    }

    Widget label(int i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              steps[i].title,
              style: i == currentIndex
                  ? context.uiText.bodyStrong
                  : context.uiText.body
                      .copyWith(color: theme.colors.foregroundMuted),
            ),
            if (steps[i].subtitle != null)
              Text(
                steps[i].subtitle!,
                style: context.uiText.caption
                    .copyWith(color: theme.colors.foregroundSubtle),
              ),
          ],
        );

    if (vertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < steps.length; i++)
            UiInteractive(
              onTap: onStepTap == null ? null : () => onStepTap!(i),
              builder: (BuildContext ctx, UiInteractiveState _) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      dot(i),
                      if (i != steps.length - 1)
                        Container(
                          width: theme.borders.thick,
                          height: ctx.sz(28),
                          color: i < currentIndex
                              ? theme.colors.primary
                              : theme.colors.border,
                        ),
                    ],
                  ),
                  SizedBox(width: ctx.sp(theme.spacing.md)),
                  Padding(
                    padding: EdgeInsets.only(bottom: ctx.sp(theme.spacing.md)),
                    child: label(i),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        for (int i = 0; i < steps.length; i++) ...<Widget>[
          UiInteractive(
            onTap: onStepTap == null ? null : () => onStepTap!(i),
            builder: (BuildContext ctx, UiInteractiveState _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                dot(i),
                SizedBox(width: ctx.sp(theme.spacing.sm)),
                label(i),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: theme.borders.thick,
                margin: EdgeInsets.symmetric(
                  horizontal: context.sp(theme.spacing.md),
                ),
                color: i < currentIndex
                    ? theme.colors.primary
                    : theme.colors.border,
              ),
            ),
        ],
      ],
    );
  }
}
