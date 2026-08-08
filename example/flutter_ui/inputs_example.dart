import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for all Input Controls (Text, Password, Search, Tag, Select, Checkbox, Switch, Slider, Textarea).
class InputsExampleView extends StatefulWidget {
  const InputsExampleView({super.key});

  @override
  State<InputsExampleView> createState() => _InputsExampleViewState();
}

class _InputsExampleViewState extends State<InputsExampleView> {
  String _text = '';
  List<String> _tags = <String>['trading', 'breakout'];
  String _selectedOption = 'usd';
  bool _checkbox = true;
  bool _switchVal = true;
  double _sliderVal = 50;
  String _textareaVal = '';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Text Inputs & Fields', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiInput(
            hintText: 'Enter text...',
            value: _text,
            leadingIcon: Icons.edit,
            onChanged: (v) => setState(() => _text = v),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiPasswordField(
            hintText: 'Enter password...',
            onChanged: (v) {},
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSearchField(
            hintText: 'Search tickers or setups...',
            onChanged: (v) {},
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTagInput(
            tags: _tags,
            hintText: 'Add tag...',
            onChanged: (tags) => setState(() => _tags = tags),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Selection Controls & Switches', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSelect<String>(
            value: _selectedOption,
            hintText: 'Select Base Currency',
            options: const <UiOption<String>>[
              UiOption(value: 'usd', label: 'USD - US Dollar'),
              UiOption(value: 'eur', label: 'EUR - Euro'),
              UiOption(value: 'gbp', label: 'GBP - British Pound'),
            ],
            onChanged: (v) => setState(() => _selectedOption = v),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiCheckbox(
            value: _checkbox,
            label: 'Enable strict risk management alerts',
            onChanged: (v) => setState(() => _checkbox = v),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSwitch(
            value: _switchVal,
            label: 'Dark Mode Synced',
            onChanged: (v) => setState(() => _switchVal = v),
          ),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSlider(
            value: _sliderVal,
            min: 0,
            max: 100,
            label: 'Leverage Multiple',
            onChanged: (v) => setState(() => _sliderVal = v),
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('Multi-Line Textarea', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiTextarea(
            hintText: 'Write trading thesis or journal entry notes...',
            value: _textareaVal,
            rows: 3,
            onChanged: (v) => setState(() => _textareaVal = v),
          ),
        ],
      ),
    );
  }
}
