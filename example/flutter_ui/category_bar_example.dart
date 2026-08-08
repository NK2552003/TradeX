import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class CategoryBarExampleView extends StatelessWidget {
  const CategoryBarExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCategoryBar - Proportional Allocation Bar', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          const UiCategoryBar(
            segments: <UiCategorySegment>[
              UiCategorySegment(value: 65, label: 'Win', color: Colors.green),
              UiCategorySegment(value: 35, label: 'Loss', color: Colors.red),
            ],
          ),
        ],
      ),
    );
  }
}
