import 'package:flutter/material.dart';

import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

import '../models/research_router.dart';

class ResearchRoutingHint extends StatelessWidget {
  const ResearchRoutingHint({
    super.key,
    required this.controller,
    required this.onChoose,
    this.enabled = true,
  });
  final TextEditingController controller;
  final VoidCallback onChoose;
  final bool enabled;
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final route = ResearchRouter.select(value.text);
          return Padding(
            padding: EdgeInsets.only(bottom: context.sp(context.ui.spacing.xs)),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: context.sp(context.ui.spacing.xs),
              runSpacing: context.sp(context.ui.spacing.xxs),
              children: [
                UiTooltip(
                  message: route.reason,
                  child: UiBadge(
                    label: route.explicit
                        ? route.label
                        : 'Auto · ${route.label}',
                    icon: Icons.auto_awesome_outlined,
                    variant: UiBadgeVariant.soft,
                    size: UiSize.xs,
                  ),
                ),
                UiButton(
                  label: 'Change format',
                  variant: UiVariant.ghost,
                  size: UiSize.xs,
                  onPressed: enabled ? onChoose : null,
                ),
              ],
            ),
          );
        },
      );
}
