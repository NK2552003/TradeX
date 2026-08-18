import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  String _selectedRange = '1D';
  String _chartStyle = 'Candlestick';
  String _colorScheme = 'Standard (Green/Red)';

  final List<String> _rangeOptions = const <String>[
    '1D',
    '1W',
    '1M',
    '1Y',
    'ALL',
  ];
  final List<String> _chartStyles = const <String>[
    'Candlestick',
    'Line',
    'Area',
    'Bars',
  ];
  final List<String> _colorSchemes = const <String>[
    'Standard (Green/Red)',
    'Colorblind-Safe (Blue/Orange)',
    'Monochrome (High Contrast)',
  ];
  final List<String> _densities = const <String>['Comfortable', 'Compact'];

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final themeController = AppThemeController.of(context);
    final currentThemeMode = themeController.value;
    final currentDensity = themeController.density;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Theme Section
              AppSettingsSectionBlock(
                title: 'Interface Theme',
                description:
                    'Choose your visual preference or sync with system OS appearance.',
                children: [
                  AppSettingCard(
                    title: 'Color Theme Mode',
                    description:
                        'Switches between sleek dark terminal mode and crisp daytime light mode.',
                    icon: Icons.palette_outlined,
                    control: UiToggleGroup<ThemeMode>(
                      expand: true,
                      value: currentThemeMode,
                      options: const <UiToggleOption<ThemeMode>>[
                        UiToggleOption(
                          label: 'Dark',
                          value: ThemeMode.dark,
                          icon: Icons.dark_mode_outlined,
                        ),
                        UiToggleOption(
                          label: 'Light',
                          value: ThemeMode.light,
                          icon: Icons.light_mode_outlined,
                        ),
                        UiToggleOption(
                          label: 'System',
                          value: ThemeMode.system,
                          icon: Icons.settings_brightness_outlined,
                        ),
                      ],
                      onChanged: (mode) {
                        themeController.setMode(mode);
                        UiToast.show(
                          context,
                          title: 'Theme Changed',
                          message:
                              'Switched to ${mode.name.toUpperCase()} theme mode.',
                          intent: UiIntent.info,
                        );
                      },
                    ),
                  ),
                  AppSettingCard(
                    title: 'Layout & Spacing Density',
                    description:
                        'Adjust information density across tables, cards, and execution panels.',
                    icon: Icons.density_medium_rounded,
                    control: UiToggleGroup<String>(
                      expand: true,
                      value: currentDensity,
                      options: _densities
                          .map(
                            (d) => UiToggleOption<String>(label: d, value: d),
                          )
                          .toList(),
                      onChanged: (val) {
                        themeController.setDensity(val);
                        UiToast.show(
                          context,
                          title: 'Density Updated',
                          message: 'Layout spacing adjusted to $val mode.',
                          intent: UiIntent.info,
                        );
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Financial Chart Defaults
              AppSettingsSectionBlock(
                title: 'Default Financial Chart Settings',
                description:
                    'Set default configurations applied whenever you open technical analysis workspaces.',
                children: [
                  AppSettingCard(
                    title: 'Default Timeframe Range',
                    description:
                        'Initial chart range when opening new symbol tickets.',
                    icon: Icons.timeline_rounded,
                    control: UiToggleGroup<String>(
                      expand: true,
                      value: _selectedRange,
                      options: _rangeOptions
                          .map(
                            (r) => UiToggleOption<String>(label: r, value: r),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedRange = val);
                      },
                    ),
                  ),
                  AppSettingCard(
                    title: 'Primary Chart Type',
                    description:
                        'Default rendering style for price action bars.',
                    icon: Icons.candlestick_chart_outlined,
                    control: UiSelect<String>(
                      width: 180,
                      value: _chartStyle,
                      options: _chartStyles
                          .map((s) => UiOption<String>(label: s, value: s))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _chartStyle = val);
                      },
                    ),
                  ),
                  AppSettingCard(
                    title: 'Bullish / Bearish Color Convention',
                    description:
                        'Ensure price signals match your regional or accessibility requirements.',
                    icon: Icons.invert_colors_rounded,
                    control: UiSelect<String>(
                      width: 180,
                      value: _colorScheme,
                      options: _colorSchemes
                          .map((c) => UiOption<String>(label: c, value: c))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _colorScheme = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
