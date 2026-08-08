import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class DropdownMenuExampleView extends StatelessWidget {
  const DropdownMenuExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiDropdownMenu - Context Menu Triggers', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDropdownMenu(
            actions: <UiMenuAction>[
              UiMenuAction(label: 'Edit Position', onSelected: () {}),
              UiMenuAction(label: 'Close Trade', destructive: true, onSelected: () {}),
            ],
            child: const UiButton(label: 'Manage Trade Options', variant: UiVariant.outline),
          ),
        ],
      ),
    );
  }
}
