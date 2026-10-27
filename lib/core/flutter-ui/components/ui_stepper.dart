import 'package:flutter/material.dart';

import '../theme/ui_theme.dart';
import 'ui_common.dart';

@immutable
class UiStepperStep {
  const UiStepperStep({required this.title, this.subtitle, this.icon});

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
    int? currentIndex,
    int? currentStep,
    this.onStepTap,
    this.forceVertical = false,
  }) : currentIndex = currentStep ?? currentIndex ?? 0;

  final List<UiStepperStep> steps;
  final int currentIndex;
  final ValueChanged<int>? onStepTap;
  final bool forceVertical;

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;
    final bool isMobile = context.uiRes.isMobile;
    final bool vertical = forceVertical || (isMobile && steps.length > 2);

    Widget dot(int i) {
      final bool done = i < currentIndex;
      final bool active = i == currentIndex;
      final Color color = done || active
          ? theme.colors.primary
          : theme.colors.borderStrong;
      final double dotDim = context.sz(isMobile ? 22 : 26);
      return Container(
        width: dotDim,
        height: dotDim,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? color : theme.colors.surface,
          border: Border.all(color: color, width: theme.borders.thick),
        ),
        alignment: Alignment.center,
        child: done
            ? Icon(
                Icons.check,
                size: context.sz(isMobile ? 12 : theme.sizes.iconSm),
                color: theme.colors.onPrimary,
              )
            : Text(
                '${i + 1}',
                style: context.uiText.caption.copyWith(
                  fontSize: isMobile ? 10.5 : null,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
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
          // Step titles are caller-supplied. Bounding them here is what stops a
          // long one from squeezing the connector rails to nothing and then
          // overrunning the row.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (i == currentIndex
                      ? context.uiText.bodyStrong
                      : context.uiText.body.copyWith(
                          color: theme.colors.foregroundMuted,
                        ))
                  .copyWith(fontSize: isMobile ? context.fs(11.5) : null),
        ),
        if (steps[i].subtitle != null && !isMobile)
          Text(
            steps[i].subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.uiText.caption.copyWith(
              color: theme.colors.foregroundSubtle,
            ),
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: ctx.sp(theme.spacing.md),
                      ),
                      child: label(i),
                    ),
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
          // Loose so a step takes only what it needs, but can still be shrunk
          // when the trail is wider than the rail it sits on.
          Flexible(
            child: UiInteractive(
              onTap: onStepTap == null ? null : () => onStepTap!(i),
              builder: (BuildContext ctx, UiInteractiveState _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  dot(i),
                  SizedBox(
                    width: ctx.sp(
                      isMobile ? theme.spacing.xxs : theme.spacing.sm,
                    ),
                  ),
                  Flexible(child: label(i)),
                ],
              ),
            ),
          ),
          if (i != steps.length - 1)
            Expanded(
              child: Container(
                height: theme.borders.thick,
                // A minimum keeps the rail visible as a rail once the steps have
                // taken their share; without it the connector collapses to a dot.
                constraints: BoxConstraints(
                  minWidth: context.sz(isMobile ? 8 : 16),
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: context.sp(
                    isMobile ? theme.spacing.xs : theme.spacing.md,
                  ),
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
