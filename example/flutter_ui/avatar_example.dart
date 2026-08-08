import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class AvatarExampleView extends StatelessWidget {
  const AvatarExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAvatar - User Avatars in Sizes', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: const <Widget>[
              UiAvatar(name: 'Nitish Kumar', size: UiSize.sm),
              SizedBox(width: 12),
              UiAvatar(name: 'Nitish Kumar', size: UiSize.md),
              SizedBox(width: 12),
              UiAvatar(name: 'Nitish Kumar', size: UiSize.lg),
            ],
          ),
        ],
      ),
    );
  }
}
