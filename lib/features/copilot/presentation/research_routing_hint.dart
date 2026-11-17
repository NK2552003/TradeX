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
          return UiTooltip(
            message: '${route.reason} (Tap to change format)',
            child: UiButton(
              label: route.explicit
                  ? route.label
                  : 'Auto · ${route.label}',
              icon: Icons.auto_awesome_outlined,
              trailingIcon: Icons.expand_more,
              variant: UiVariant.soft,
              size: UiSize.xs,
              rounded: true,
              onPressed: enabled ? onChoose : null,
            ),
          );
        },
      );
}
