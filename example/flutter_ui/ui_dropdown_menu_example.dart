import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiDropdownMenuExampleView extends StatelessWidget {
  const UiDropdownMenuExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiDropdownMenu Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDropdownMenu(actions: <UiMenuAction>[UiMenuAction(label: 'Edit', onSelected: () {})], child: const UiButton(label: 'Menu', variant: UiVariant.outline)),
        ],
      ),
    );
  }
}
