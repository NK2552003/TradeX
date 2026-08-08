import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiCategoryBarExampleView extends StatelessWidget {
  const UiCategoryBarExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCategoryBar Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCategoryBar(segments: <UiCategorySegment>[UiCategorySegment(value: 60, label: 'Win', color: Colors.green)]),
        ],
      ),
    );
  }
}
