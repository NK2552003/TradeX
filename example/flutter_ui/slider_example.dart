import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class SliderExampleView extends StatefulWidget {
  const SliderExampleView({super.key});

  @override
  State<SliderExampleView> createState() => _SliderExampleViewState();
}

class _SliderExampleViewState extends State<SliderExampleView> {
  double _slider = 2.5;
  RangeValues _range = const RangeValues(10, 80);

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiSlider & UiRangeSlider', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiSlider(
            value: _slider,
            min: 0.5,
            max: 10.0,
            label: 'Risk Percentage Capped',
            onChanged: (v) => setState(() => _slider = v),
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),
          UiRangeSlider(
            range: _range,
            min: 0,
            max: 100,
            label: 'Filter Price Range (\$)',
            onChanged: (v) => setState(() => _range = v),
          ),
        ],
      ),
    );
  }
}
