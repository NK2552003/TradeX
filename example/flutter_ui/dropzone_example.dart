import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class DropzoneExampleView extends StatelessWidget {
  const DropzoneExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiDropzone - File Upload Container', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiDropzone(
            title: 'Drop Trading Journal Screenshots Here',
            message: 'Supports PNG, JPG, CSV files up to 10MB',
            onPick: () {},
          ),
        ],
      ),
    );
  }
}
