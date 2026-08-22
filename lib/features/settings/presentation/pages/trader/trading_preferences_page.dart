import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/settings/data/repositories/trading_prefs_repository.dart';
import 'package:tradex/features/settings/models/trading_prefs_model.dart';

class TradingPreferencesPage extends StatefulWidget {
  const TradingPreferencesPage({super.key, this.repository});

  final TradingPrefsRepository? repository;

  @override
  State<TradingPreferencesPage> createState() => _TradingPreferencesPageState();
}

class _TradingPreferencesPageState extends State<TradingPreferencesPage> {
  late final TradingPrefsRepository _repo;
  TradingPrefsModel _prefs = TradingPrefsModel.defaultPrefs();
  List<AppChecklistItem> _checklist = [];
  bool _loading = true;
  bool _saving = false;

  final List<int> _refreshIntervals = const <int>[5, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? TradingPrefsRepositoryImpl();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final p = await _repo.getPreferences();
      final c = await _repo.getChecklist();
      if (mounted) {
        setState(() {
          _prefs = p;
          _checklist = c;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePrefs() async {
    setState(() => _saving = true);
    try {
      await _repo.updatePreferences(_prefs);
      await _repo.updateChecklist(_checklist);
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Preferences Saved',
          message:
              'Your trading defaults and checklist items have been synced.',
          intent: UiIntent.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        UiToast.show(
          context,
          title: 'Save Failed',
          message: 'Could not update trading preferences.',
          intent: UiIntent.danger,
        );
      }
    }
  }

  void _showAddChecklistItemDialog() {
    final labelController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => UiDialog(
        title: 'Add Pre-Trade Checklist Rule',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiField(
              label: 'Rule / Confirmation Label',
              child: UiInput(
                hintText: 'e.g. Higher timeframe trend alignment verified',
                onChanged: (v) => labelController.text = v,
              ),
            ),
            SizedBox(height: context.sp(context.ui.spacing.sm)),
            UiField(
              label: 'Description / Instructions (Optional)',
              child: UiInput(
                hintText: 'e.g. Check 200 EMA slope and volume confirmation',
                onChanged: (v) => descController.text = v,
              ),
            ),
          ],
        ),
        actions: [
          UiButton(
            label: 'Cancel',
            variant: UiVariant.outline,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          UiButton(
            label: 'Add Rule',
            intent: UiIntent.primary,
            onPressed: () async {
              final lbl = labelController.text.trim();
              if (lbl.isEmpty) return;
              Navigator.of(ctx).pop();
              final updated = await _repo.addChecklistItem(
                lbl,
                description: descController.text.trim().isNotEmpty
                    ? descController.text.trim()
                    : null,
              );
              if (mounted) setState(() => _checklist = updated);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;
    final colors = theme.colors;
    final isMobile = context.uiRes.isMobile;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Column(
          children: const [
            UiSkeleton(height: 160),
            SizedBox(height: 16),
            UiSkeleton(height: 220),
          ],
        ),
      );
    }

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomInset = isMobile
        ? (keyboardInset > 0 ? keyboardInset + 24.0 : 108.0)
        : context.sp(theme.spacing.lg);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        context.sp(theme.spacing.lg),
        bottomInset,
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Personal Trader Discipline Scope Banner
              UiCallout(
                title: 'Personal Trader Risk & Discipline Parameters',
                message:
                    'Settings configured here apply directly to your personal execution ticket, auto-fill risk calculators, and journal validation.',
                intent: UiIntent.primary,
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Risk Defaults
              AppSettingsSectionBlock(
                title: 'Default Risk Management Parameters',
                description:
                    'Calculators and order tickets will pre-populate these risk limits.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ResponsivePreferenceHeading(
                          label: 'Max Account Risk per Trade',
                          badge: UiBadge(
                            label:
                                '${_prefs.defaultPositionSizePercent.toStringAsFixed(1)}% of Capital',
                            intent: UiIntent.primary,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSlider(
                          value: _prefs.defaultPositionSizePercent,
                          min: 0.5,
                          max: 10.0,
                          onChanged: (val) {
                            setState(() {
                              _prefs = _prefs.copyWith(
                                defaultPositionSizePercent: val,
                              );
                            });
                          },
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        _ResponsivePreferenceHeading(
                          label: 'Target R-Multiple (Risk-to-Reward)',
                          badge: UiBadge(
                            label:
                                '${_prefs.defaultRMultipleTarget.toStringAsFixed(1)}R Target',
                            intent: UiIntent.bullish,
                          ),
                        ),
                        SizedBox(height: context.sp(theme.spacing.sm)),
                        UiSlider(
                          value: _prefs.defaultRMultipleTarget,
                          min: 1.0,
                          max: 6.0,
                          onChanged: (val) {
                            setState(() {
                              _prefs = _prefs.copyWith(
                                defaultRMultipleTarget: val,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Pre-Trade Checklist Editor
              AppSettingsSectionBlock(
                title: 'Pre-Trade Execution Checklist Rules',
                description:
                    'Gates enforced before submitting live orders or logging journal setups.',
                children: [
                  UiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: context.sp(theme.spacing.sm),
                          runSpacing: context.sp(theme.spacing.sm),
                          children: [
                            Text(
                              '${_checklist.length} Active Checklist Rules',
                              style: context.uiText.bodyStrong,
                            ),
                            UiButton(
                              label: 'Add Rule',
                              leadingIcon: Icons.add_rounded,
                              size: UiSize.xs,
                              variant: UiVariant.outline,
                              onPressed: _showAddChecklistItemDialog,
                            ),
                          ],
                        ),
                        SizedBox(height: context.sp(theme.spacing.md)),
                        if (_checklist.isEmpty)
                          const UiEmptyState(
                            icon: Icons.checklist_rtl_rounded,
                            title: 'No checklist rules defined',
                            message:
                                'Add checklist rules to build disciplined execution habits.',
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _checklist.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: context.sp(theme.spacing.xs)),
                            itemBuilder: (context, index) {
                              final item = _checklist[index];
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.sp(theme.spacing.sm),
                                  vertical: context.sp(theme.spacing.xs),
                                ),
                                decoration: BoxDecoration(
                                  color: colors.surfaceHover,
                                  borderRadius: context.radius(theme.radii.sm),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        UiIconButton(
                                          icon: Icons.arrow_upward_rounded,
                                          size: UiSize.xs,
                                          variant: UiVariant.ghost,
                                          tooltip: 'Move up',
                                          onPressed: index > 0
                                              ? () {
                                                  setState(() {
                                                    final temp =
                                                        _checklist[index - 1];
                                                    _checklist[index - 1] =
                                                        _checklist[index];
                                                    _checklist[index] = temp;
                                                  });
                                                }
                                              : null,
                                        ),
                                        UiIconButton(
                                          icon: Icons.arrow_downward_rounded,
                                          size: UiSize.xs,
                                          variant: UiVariant.ghost,
                                          tooltip: 'Move down',
                                          onPressed:
                                              index < _checklist.length - 1
                                              ? () {
                                                  setState(() {
                                                    final temp =
                                                        _checklist[index + 1];
                                                    _checklist[index + 1] =
                                                        _checklist[index];
                                                    _checklist[index] = temp;
                                                  });
                                                }
                                              : null,
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      width: context.sp(theme.spacing.sm),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.label,
                                            style: context.uiText.bodyStrong,
                                          ),
                                          if (item.description != null)
                                            Text(
                                              item.description!,
                                              style: context.uiText.caption
                                                  .copyWith(
                                                    color:
                                                        colors.foregroundMuted,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    UiIconButton(
                                      icon: Icons.delete_outline_rounded,
                                      size: UiSize.xs,
                                      variant: UiVariant.destructive,
                                      tooltip: 'Delete rule',
                                      onPressed: () async {
                                        final updated = await _repo
                                            .deleteChecklistItem(item.id);
                                        if (mounted) {
                                          setState(() => _checklist = updated);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.lg)),

              // Watchlist Defaults
              AppSettingsSectionBlock(
                title: 'Watchlist & Scanner Defaults',
                description:
                    'Default symbols loaded on cold startup and real-time refresh rate.',
                children: [
                  UiField(
                    label: 'Default Watchlist Tickers',
                    helper: 'Cashtag symbols to track on the market scanner.',
                    child: UiTagInput(
                      tags: _prefs.defaultWatchlistSymbols,
                      onChanged: (tags) {
                        setState(() {
                          _prefs = _prefs.copyWith(
                            defaultWatchlistSymbols: tags,
                          );
                        });
                      },
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.sm)),
                  AppSettingCard(
                    title: 'Data Polling Refresh Interval',
                    description:
                        'How frequently background quotes and order book depths reload.',
                    icon: Icons.sync_rounded,
                    control: UiSelect<int>(
                      width: 160,
                      value: _prefs.watchlistRefreshIntervalSeconds,
                      options: _refreshIntervals
                          .map(
                            (sec) => UiOption<int>(
                              label: '$sec seconds',
                              value: sec,
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _prefs = _prefs.copyWith(
                            watchlistRefreshIntervalSeconds: val,
                          );
                        });
                      },
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.sp(theme.spacing.xl)),

              // Save button
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: UiButton(
                    label: 'Save Trading Preferences',
                    intent: UiIntent.primary,
                    variant: UiVariant.primary,
                    loading: _saving,
                    onPressed: _savePrefs,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsivePreferenceHeading extends StatelessWidget {
  const _ResponsivePreferenceHeading({
    required this.label,
    required this.badge,
  });

  final String label;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final spacing = context.sp(context.ui.spacing.sm);
    if (context.uiRes.isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.uiText.bodyStrong),
          SizedBox(height: spacing),
          badge,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: Text(label, style: context.uiText.bodyStrong)),
        SizedBox(width: spacing),
        badge,
      ],
    );
  }
}
