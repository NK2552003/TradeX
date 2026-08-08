import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

class UiRangeSliderExampleView extends StatelessWidget {
  const UiRangeSliderExampleView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiRangeSlider Example Showcase', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          UiRangeSlider(range: const RangeValues(20, 80), min: 0, max: 100, label: 'Price Range', onChanged: (v) {}),
        ],
      ),
    );
  }
}
