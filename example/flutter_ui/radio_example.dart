import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class RadioExampleView extends StatefulWidget {
  const RadioExampleView({super.key});

  @override
  State<RadioExampleView> createState() => _RadioExampleViewState();
}

class _RadioExampleViewState extends State<RadioExampleView> {
  String _val = 'market';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiRadioGroup & UiRadioCardGroup', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiRadioGroup<String>(
            value: _val,
            onChanged: (v) => setState(() => _val = v),
            options: const <UiOption<String>>[
              UiOption(value: 'market', label: 'Market Order (Instant execution)'),
              UiOption(value: 'limit', label: 'Limit Order (Target price entry)'),
              UiOption(value: 'stop', label: 'Stop-Limit Order'),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiRadioCardGroup<String>(
            value: _val,
            onChanged: (v) => setState(() => _val = v),
            options: const <UiOption<String>>[
              UiOption(value: 'market', label: 'Market Order Card Option'),
              UiOption(value: 'limit', label: 'Limit Order Card Option'),
            ],
          ),
        ],
      ),
    );
  }
}
