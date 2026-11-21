import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alphajournal/core/app-ui/app_ui.dart';
import 'package:alphajournal/core/config/cross_subdomain_storage.dart';
import 'package:alphajournal/core/config/supabase_config.dart';
// ignore: unnecessary_import
import 'package:alphajournal/core/flutter-ui/flutter_ui.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  static const String _appearanceExtrasKey =
      'alphajournal_appearance_extras_v1';

  final AppThemeController _fallbackController = AppThemeController();
  String _numberFormat = 'Indian (1,00,000)';
  String _timeFormat = '12-hour';
  bool _showTickerStrip = true;
  bool _reduceMotion = false;

  final List<String> _numberFormats = const <String>[
    'Indian (1,00,000)',
    'International (100,000)',
  ];
  final List<String> _timeFormats = const <String>['12-hour', '24-hour'];

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_appearanceExtrasKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && mounted) {
          _applyExtrasMap(Map<String, dynamic>.from(decoded));
        }
      }
      final client = SupabaseConfig.client;
      final uid = client?.auth.currentUser?.id;
      if (SupabaseConfig.isConfigured && client != null && uid != null) {
        final row = await client
            .from('user_app_preferences')
            .select('appearance_extras')
            .eq('user_id', uid)
            .maybeSingle();
        final extras = row?['appearance_extras'];
        if (extras is Map && extras.isNotEmpty && mounted) {
          final map = Map<String, dynamic>.from(extras);
          _applyExtrasMap(map);
          await sp.setString(_appearanceExtrasKey, jsonEncode(map));
        }
      }
    } catch (_) {}
  }

  void _applyExtrasMap(Map<String, dynamic> map) {
    final String? nf = map['number_format'] as String?;
    final String? tf = map['time_format'] as String?;
    setState(() {
      if (nf != null && _numberFormats.contains(nf)) _numberFormat = nf;
      if (tf != null && _timeFormats.contains(tf)) _timeFormat = tf;
      if (map.containsKey('show_ticker_strip')) {
        _showTickerStrip = map['show_ticker_strip'] == true;
      }
      if (map.containsKey('reduce_motion')) {
        _reduceMotion = map['reduce_motion'] == true;
      }
    });
    if (!mounted) return;
    final activeController =
        AppThemeController.maybeOf(context) ?? _fallbackController;
    final String? rawMode = map['theme_mode'] as String?;
    if (rawMode != null &&
        CrossSubdomainState.getFlag('ax_theme_mode') == null &&
        CrossSubdomainState.getLocalPreferenceFallback('ax_theme_mode') ==
            null) {
      final ThemeMode? parsedMode = switch (rawMode.trim()) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        'dark' => ThemeMode.dark,
        _ => null,
      };
      if (parsedMode != null) {
        activeController.setMode(parsedMode);
        _syncControllerToSubdomain(activeController);
      }
    }
    final String? rawDensity = map['density'] as String?;
    if ((rawDensity == 'Compact' || rawDensity == 'Comfortable') &&
        CrossSubdomainState.getFlag('ax_theme_density') == null &&
        CrossSubdomainState.getLocalPreferenceFallback('ax_theme_density') ==
            null) {
      activeController.setDensity(rawDensity!);
      _syncControllerToSubdomain(activeController);
    }
  }

  void _persistAppearanceChange(
    AppThemeController controller, {
    required String title,
    required String message,
  }) {
    _syncControllerToSubdomain(controller);
    _saveExtras('', '', showToast: false, controller: controller);
    UiToast.show(
      context,
      title: title,
      message: message,
      intent: UiIntent.info,
    );
  }

  Future<void> _saveDisplayPreference(
    String key,
    String value,
    String label,
  ) async {
    CrossSubdomainState.setFlag(key, value, maxAgeDays: 180);
    try {
      final preferences = await SharedPreferences.getInstance();
      if (await preferences.setString(key, value)) return;
    } catch (_) {
      // The selection stays active for this session if storage is unavailable.
    }
    if (mounted) UiToast.error(context, title: 'Could not save $label');
  }

  void _syncControllerToSubdomain(AppThemeController controller) {
    CrossSubdomainState.setFlag(
      'ax_theme_mode',
      controller.value.name,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_theme_density',
      controller.density,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_range',
      controller.chartRange,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_style',
      controller.chartStyle,
      maxAgeDays: 180,
    );
    CrossSubdomainState.setFlag(
      'ax_chart_colors',
      controller.colorConvention,
      maxAgeDays: 180,
    );
    final Brightness systemBrightness =
        (mounted ? MediaQuery.maybePlatformBrightnessOf(context) : null) ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool isLight = switch (controller.value) {
      ThemeMode.light => true,
      ThemeMode.dark => false,
      ThemeMode.system => systemBrightness == Brightness.light,
    };
    CrossSubdomainState.syncWebTheme(
      mode: controller.value.name,
      density: controller.density,
      isLight: isLight,
    );
  }

  Future<void> _saveExtras(
    String title,
    String message, {
    bool showToast = true,
    AppThemeController? controller,
  }) async {
    final activeController =
        controller ??
        (mounted ? AppThemeController.maybeOf(context) : null) ??
        _fallbackController;
    final payload = <String, dynamic>{
      'number_format': _numberFormat,
      'time_format': _timeFormat,
      'show_ticker_strip': _showTickerStrip,
      'reduce_motion': _reduceMotion,
      'theme_mode': activeController.value.name,
      'density': activeController.density,
      'chart_range': activeController.chartRange,
      'chart_style': activeController.chartStyle,
      'color_convention': activeController.colorConvention,
    };
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_appearanceExtrasKey, jsonEncode(payload));
      final client = SupabaseConfig.client;
      final uid = client?.auth.currentUser?.id;
      if (SupabaseConfig.isConfigured && client != null && uid != null) {
        await client.from('user_app_preferences').upsert({
          'user_id': uid,
          'appearance_extras': payload,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {}
    if (showToast && mounted) {
      UiToast.show(
        context,
        title: title,
        message: message,
        intent: UiIntent.info,
      );
    }
  }

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

  static final List<UiCandle> _previewCandles = <UiCandle>[
    UiCandle(
      time: DateTime(2026, 1, 1),
      open: 182.0,
      high: 185.4,
      low: 180.8,
      close: 184.2,
      volume: 1240,
    ),
    UiCandle(
      time: DateTime(2026, 1, 2),
      open: 184.2,
      high: 186.0,
      low: 181.5,
      close: 182.1,
      volume: 980,
    ),
    UiCandle(
      time: DateTime(2026, 1, 3),
      open: 182.1,
      high: 187.8,
      low: 181.9,
      close: 187.2,
      volume: 1520,
    ),
    UiCandle(
      time: DateTime(2026, 1, 4),
      open: 187.2,
      high: 190.1,
      low: 185.6,
      close: 189.4,
      volume: 1680,
    ),
    UiCandle(
      time: DateTime(2026, 1, 5),
      open: 189.4,
      high: 190.2,
      low: 185.0,
      close: 186.3,
      volume: 1190,
    ),
    UiCandle(
      time: DateTime(2026, 1, 6),
      open: 186.3,
      high: 191.5,
      low: 185.8,
      close: 190.8,
      volume: 1840,
    ),
    UiCandle(
      time: DateTime(2026, 1, 7),
      open: 190.8,
      high: 192.4,
      low: 188.9,
      close: 189.5,
      volume: 1320,
    ),
    UiCandle(
      time: DateTime(2026, 1, 8),
      open: 189.5,
      high: 194.8,
      low: 189.0,
      close: 194.1,
      volume: 2110,
    ),
  ];

  @override
  void dispose() {
    _fallbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final themeController =
        AppThemeController.maybeOf(context) ?? _fallbackController;

    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        final currentThemeMode = themeController.value;
        final currentDensity = themeController.density;
        final selectedRange = themeController.chartRange;
        final chartStyle = themeController.chartStyle;
        final colorScheme = themeController.colorConvention;

        final bool isMobile = context.uiRes.isMobile;
        final double bottomInset = isMobile
            ? context.uiPageBottomInset
            : context.sp(theme.spacing.lg);

        final previewColors = theme.colors.withMarketConvention(
          colorScheme,
          theme.brightness,
        );
        final previewTheme = theme.copyWith(colors: previewColors);

        final double pagePad = context.sp(
          isMobile ? theme.spacing.md : theme.spacing.lg,
        );
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            pagePad,
            MediaQuery.paddingOf(context).top + pagePad,
            pagePad,
            bottomInset,
          ),
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
                            _persistAppearanceChange(
                              themeController,
                              title: 'Theme Changed',
                              message:
                                  'Switched to ${mode.name.toUpperCase()} theme mode.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'App zoom',
                        description:
                            'Adjust the size of text, controls, and spacing.',
                        icon: Icons.zoom_in_rounded,
                        control: UiSelect<AppZoom>(
                          key: const ValueKey('appearance-app-zoom'),
                          width: isMobile ? null : context.sz(220),
                          hintText: 'App zoom',
                          value: themeController.zoom,
                          options: [
                            for (final zoom in AppZoom.values)
                              UiOption(label: zoom.label, value: zoom),
                          ],
                          onChanged: (zoom) {
                            if (zoom == themeController.zoom) return;
                            themeController.setZoom(zoom);
                            _saveDisplayPreference(
                              AppZoom.preferenceKey,
                              zoom.name,
                              'app zoom',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Text size',
                        description:
                            'Follow your device’s font size or choose an in-app size.',
                        icon: Icons.format_size_rounded,
                        control: UiSelect<AppTextSize>(
                          key: const ValueKey('appearance-text-size'),
                          width: isMobile ? null : context.sz(220),
                          hintText: 'Text size',
                          value: themeController.textSize,
                          options: [
                            for (final size in AppTextSize.values)
                              UiOption(label: size.label, value: size),
                          ],
                          onChanged: (size) {
                            if (size == themeController.textSize) return;
                            themeController.setTextSize(size);
                            _saveDisplayPreference(
                              AppTextSize.preferenceKey,
                              size.name,
                              'text size',
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
                                (d) =>
                                    UiToggleOption<String>(label: d, value: d),
                              )
                              .toList(),
                          onChanged: (val) {
                            themeController.setDensity(val);
                            _persistAppearanceChange(
                              themeController,
                              title: 'Density Updated',
                              message: 'Layout spacing adjusted to $val mode.',
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
                          value: selectedRange,
                          options: _rangeOptions
                              .map(
                                (r) =>
                                    UiToggleOption<String>(label: r, value: r),
                              )
                              .toList(),
                          onChanged: (val) {
                            themeController.setChartRange(val);
                            _persistAppearanceChange(
                              themeController,
                              title: 'Default Timeframe Updated',
                              message:
                                  'New symbol charts will default to $val range.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Primary Chart Type',
                        description:
                            'Default rendering style for price action bars.',
                        icon: Icons.candlestick_chart_outlined,
                        control: UiSelect<String>(
                          width: isMobile ? null : 220,
                          value: chartStyle,
                          options: _chartStyles
                              .map((s) => UiOption<String>(label: s, value: s))
                              .toList(),
                          onChanged: (val) {
                            themeController.setChartStyle(val);
                            _persistAppearanceChange(
                              themeController,
                              title: 'Primary Chart Style Updated',
                              message: 'Default chart rendering set to $val.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Bullish / Bearish Color Convention',
                        description:
                            'Ensure price signals match your regional or accessibility requirements.',
                        icon: Icons.invert_colors_rounded,
                        control: UiSelect<String>(
                          width: isMobile ? null : 240,
                          value: colorScheme,
                          options: _colorSchemes
                              .map((c) => UiOption<String>(label: c, value: c))
                              .toList(),
                          onChanged: (val) {
                            themeController.setColorConvention(val);
                            _persistAppearanceChange(
                              themeController,
                              title: 'Color Convention Applied',
                              message:
                                  'Bullish & bearish chart colors switched to $val.',
                            );
                          },
                        ),
                      ),
                      UiThemeScope(
                        theme: previewTheme,
                        child: UiCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: context.sp(theme.spacing.sm),
                                runSpacing: context.sp(theme.spacing.xs),
                                children: [
                                  Text(
                                    'Live Chart Preview',
                                    style: context.uiText.bodyStrong,
                                  ),
                                  Wrap(
                                    spacing: context.sp(theme.spacing.xs),
                                    children: [
                                      UiBadge(
                                        label: '$selectedRange • $chartStyle',
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.xs,
                                      ),
                                      UiBadge(
                                        label: 'Bullish +2.4%',
                                        intent: UiIntent.bullish,
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.xs,
                                      ),
                                      UiBadge(
                                        label: 'Bearish -1.2%',
                                        intent: UiIntent.bearish,
                                        variant: UiBadgeVariant.soft,
                                        size: UiSize.xs,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              UiGap.v(theme.spacing.sm),
                              UiCandleChart(
                                candles: _previewCandles,
                                type: themeController.preferredPriceChartType,
                                height: 150,
                                showVolume: false,
                                interactive: false,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.lg)),

                  // Formatting & Accessibility
                  AppSettingsSectionBlock(
                    title: 'Formatting, Clock & Motion',
                    description:
                        'Control how financial figures, timestamps, and live tickers are rendered across screens.',
                    children: [
                      AppSettingCard(
                        title: 'Number & Currency Grouping',
                        description:
                            'Choose Indian lakh/crore grouping or international thousands separators.',
                        icon: Icons.pin_outlined,
                        control: UiSelect<String>(
                          width: isMobile ? null : 230,
                          value: _numberFormat,
                          options: _numberFormats
                              .map((f) => UiOption<String>(label: f, value: f))
                              .toList(),
                          onChanged: (val) {
                            setState(() => _numberFormat = val);
                            _saveExtras(
                              'Number Format Updated',
                              'Amounts now format using $val.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Clock & Execution Time Format',
                        description:
                            'Display order timestamps and notifications in 12-hour or 24-hour format.',
                        icon: Icons.access_time_rounded,
                        control: UiToggleGroup<String>(
                          expand: isMobile,
                          value: _timeFormat,
                          options: _timeFormats
                              .map(
                                (t) =>
                                    UiToggleOption<String>(label: t, value: t),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() => _timeFormat = val);
                            _saveExtras(
                              'Clock Format Saved',
                              'Timestamps set to $val format.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Show Live Market Ticker Strip',
                        description:
                            'Display the continuous market index marquee banner inside market workspaces.',
                        icon: Icons.view_carousel_outlined,
                        control: UiSwitch(
                          value: _showTickerStrip,
                          onChanged: (val) {
                            setState(() => _showTickerStrip = val);
                            _saveExtras(
                              val
                                  ? 'Market Ticker Enabled'
                                  : 'Market Ticker Hidden',
                              val
                                  ? 'Scrolling ticker strip visible in market views.'
                                  : 'Market views will hide scrolling ticker marquee.',
                            );
                          },
                        ),
                      ),
                      AppSettingCard(
                        title: 'Reduce Motion & Transitions',
                        description:
                            'Minimize slide transitions and decorative shimmer animations across Settings and charts.',
                        icon: Icons.accessibility_new_rounded,
                        control: UiSwitch(
                          value: _reduceMotion,
                          onChanged: (val) {
                            setState(() => _reduceMotion = val);
                            _saveExtras(
                              val
                                  ? 'Reduced Motion Enabled'
                                  : 'Standard Motion Restored',
                              val
                                  ? 'Simplified transitions active.'
                                  : 'Full fluid transitions active.',
                            );
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
      },
    );
  }
}
