import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class SelectExampleView extends StatefulWidget {
  const SelectExampleView({super.key});

  @override
  State<SelectExampleView> createState() => _SelectExampleViewState();
}

class _SelectExampleViewState extends State<SelectExampleView> {
  String _val = 'usd';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiSelect & UiSelectNative', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSelect<String>(
            value: _val,
            hintText: 'Select Base Currency',
            options: const <UiOption<String>>[
              UiOption(value: 'usd', label: 'USD - United States Dollar'),
              UiOption(value: 'eur', label: 'EUR - Euro'),
              UiOption(value: 'gbp', label: 'GBP - British Pound'),
            ],
            onChanged: (v) => setState(() => _val = v),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiSelectNative<String>(
            value: _val,
            options: const <UiOption<String>>[
              UiOption(value: 'usd', label: 'USD Native Dropdown'),
              UiOption(value: 'eur', label: 'EUR Native Dropdown'),
            ],
            onChanged: (v) => setState(() => _val = v),
          ),
        ],
      ),
    );
  }
}
