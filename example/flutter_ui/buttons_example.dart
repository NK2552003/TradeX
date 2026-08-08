import 'package:flutter/material.dart';
import 'package:tradex/core/flutter-ui/flutter_ui.dart';

/// Examples for UiButton, UiIconButton, UiToggle, and UiToggleGroup demonstrating all states.
class ButtonsExampleView extends StatefulWidget {
  const ButtonsExampleView({super.key});

  @override
  State<ButtonsExampleView> createState() => _ButtonsExampleViewState();
}

class _ButtonsExampleViewState extends State<ButtonsExampleView> {
  bool _toggled = false;
  String _selectedToggleGroup = 'day';

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('UiButton - All Variants & States', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              UiButton(label: 'Primary (Normal)', variant: UiVariant.primary, onPressed: () {}),
              UiButton(label: 'Primary (Loading)', variant: UiVariant.primary, loading: true, onPressed: () {}),
              const UiButton(label: 'Primary (Disabled)', variant: UiVariant.primary, onPressed: null),
              UiButton(label: 'Secondary', variant: UiVariant.secondary, onPressed: () {}),
              UiButton(label: 'Outline', variant: UiVariant.outline, onPressed: () {}),
              UiButton(label: 'Ghost', variant: UiVariant.ghost, onPressed: () {}),
              UiButton(label: 'Destructive', variant: UiVariant.destructive, onPressed: () {}),
              UiButton(label: 'With Leading Icon', leadingIcon: Icons.add, onPressed: () {}),
              UiButton(label: 'With Trailing Icon', trailingIcon: Icons.arrow_forward, onPressed: () {}),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('UiIconButton - Icon Actions', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              UiIconButton(icon: Icons.star, tooltip: 'Star (Primary)', onPressed: () {}),
              UiIconButton(icon: Icons.share, variant: UiVariant.outline, tooltip: 'Share', onPressed: () {}),
              UiIconButton(icon: Icons.delete, variant: UiVariant.destructive, tooltip: 'Delete', onPressed: () {}),
              const UiIconButton(icon: Icons.lock, tooltip: 'Disabled', onPressed: null),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.xl)),
          Text('UiToggle & UiToggleGroup - Toggles', style: context.uiText.heading),
          SizedBox(height: context.sp(theme.spacing.md)),
          Row(
            children: <Widget>[
              UiToggle(
                value: _toggled,
                icon: Icons.bookmark,
                label: 'Bookmark',
                onChanged: (v) => setState(() => _toggled = v),
              ),
              SizedBox(width: context.sp(theme.spacing.lg)),
              UiToggleGroup<String>(
                value: _selectedToggleGroup,
                onChanged: (v) => setState(() => _selectedToggleGroup = v),
                options: const <UiToggleOption<String>>[
                  UiToggleOption(value: 'day', label: '1D'),
                  UiToggleOption(value: 'week', label: '1W'),
                  UiToggleOption(value: 'month', label: '1M'),
                  UiToggleOption(value: 'year', label: '1Y'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
