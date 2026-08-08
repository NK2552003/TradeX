import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiAvatarGroupExampleView extends StatelessWidget {
  const UiAvatarGroupExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiAvatarGroup Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(children: const <Widget>[UiAvatar(name: 'Nitish', size: UiSize.sm), SizedBox(width: 8), UiAvatar(name: 'Alex', size: UiSize.sm)]),
        ],
      ),
    );
  }
}
