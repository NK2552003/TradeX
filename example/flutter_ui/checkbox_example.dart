import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class CheckboxExampleView extends StatefulWidget {
  const CheckboxExampleView({super.key});

  @override
  State<CheckboxExampleView> createState() => _CheckboxExampleViewState();
}

class _CheckboxExampleViewState extends State<CheckboxExampleView> {
  bool _checked = true;

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiCheckbox - Selection Control', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCheckbox(
            value: _checked,
            label: 'Enable Automated Stop-Loss Protection',
            onChanged: (v) => setState(() => _checked = v),
          ),
          SizedBox(height: context.sp(theme.spacing.sm)),
          const UiCheckbox(
            value: false,
            label: 'Disabled Option',
            enabled: false,
          ),
        ],
      ),
    );
  }
}
