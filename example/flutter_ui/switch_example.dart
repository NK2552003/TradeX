import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class SwitchExampleView extends StatefulWidget {
  const SwitchExampleView({super.key});

  @override
  State<SwitchExampleView> createState() => _SwitchExampleViewState();
}

class _SwitchExampleViewState extends State<SwitchExampleView> {
  bool _val = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiSwitch - Toggle Controls', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSwitch(
            value: _val,
            label: 'Push & Webhook Notifications',
            description: 'Receive instant alerts when orders fill or stops trigger',
            onChanged: (v) => setState(() => _val = v),
          ),
        ],
      ),
    );
  }
}
