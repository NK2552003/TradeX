import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
// ignore: unnecessary_import
import 'package:tradex/core/flutter-ui/flutter_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';
import 'package:tradex/features/messages/presentation/overlays/share_to_conversation_dialog.dart';

class AiInsightsView extends StatefulWidget {
  final AiAssistantRepository repository;

  final void Function(AiChartSetup) onOpenChartAnalysis;
  final void Function(AiChartSetup, AiCreateTarget) onCreateFromSetup;
  final void Function(String prompt)? onAskPrompt;

  const AiInsightsView({
    super.key,
    required this.repository,
    required this.onOpenChartAnalysis,
    required this.onCreateFromSetup,
    this.onAskPrompt,
  });

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  late AiAssistantRepository _repository;
  bool _generating = false;
  int _selectedFilter = 0; // 0: All, 1: Long, 2: Short, 3: High Conviction

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void didUpdateWidget(AiInsightsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      _repository = widget.repository;
      _repository.addListener(_onRepositoryChanged);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    if (mounted) setState(() {});
  }

  void _handleAsk(AppAiInsight insight) {
    final String prompt =
        'Tell me more about this insight: ${insight.title}. What is the recommended trade setup, entry, and stop loss?';
    if (widget.onAskPrompt != null) {
      widget.onAskPrompt!(prompt);
    } else {
      _repository.sendPrompt(prompt);
    }
  }

  void _handleDismiss(AppAiInsight insight) {
    _repository.dismissInsight(insight);
  }

  Future<void> _handleGenerate() async {
    if (!_repository.serviceAvailable || _generating) return;
    if (!CustomerDataPolicy.allowDemo || _repository.usesLiveService) {
      const prompt =
          'Help me review trading decisions and risk management. Ask for the inputs you need and distinguish provided observations from assumptions. Do not invent market prices or account activity.';
      if (widget.onAskPrompt != null) {
        widget.onAskPrompt!(prompt);
      } else {
        _repository.sendPrompt(prompt);
      }
      return;
    }
    setState(() => _generating = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _repository.generateInsight();
    if (mounted) {
      setState(() => _generating = false);
      UiToast.show(
        context,
        title: 'Demo insight generated',
        message: 'This sample insight is simulated for the demo.',
        intent: UiIntent.success,
      );
    }
  }

  List<double> _generateSparkline(AiChartSetup setup) {
    final isLong = setup.direction == AiTradeDirection.long;
    final e = setup.entry;
    final t = setup.target1;
    final s = setup.stopLoss;

    if (isLong) {
      return [
        s,
        s + (e - s) * 0.4,
        s + (e - s) * 0.8,
        e,
        e + (t - e) * 0.35,
        e + (t - e) * 0.7,
        t,
      ];
    } else {
      return [
        s,
        s - (s - e) * 0.4,
        s - (s - e) * 0.8,
        e,
        e - (e - t) * 0.35,
        e - (e - t) * 0.7,
        t,
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = context.ui;

    final allSetups = _repository.chartSetups;
    final filteredSetups = allSetups.where((s) {
      if (_selectedFilter == 1) return s.direction == AiTradeDirection.long;
      if (_selectedFilter == 2) return s.direction == AiTradeDirection.short;
      if (_selectedFilter == 3) return s.confidence >= 80;
      return true;
    }).toList();

    return AiDensityScope(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: context.sp(theme.spacing.xl)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiSectionHeader(
              title: 'Signal desk',
              icon: Icons.radar_rounded,
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: _buildSignalSummary(allSetups),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: AppAiInsightsBlock(
                insights: _repository.insights,
                loading: _generating,
                onAsk: _handleAsk,
                onDismiss: _handleDismiss,
                onGenerate: _repository.serviceAvailable
                    ? _handleGenerate
                    : null,
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.sm)),
            const AiSectionHeader(
              title: 'Actionable setups',
              icon: Icons.candlestick_chart_rounded,
            ),
            if (allSetups.length >= 2) _buildSetupAnalytics(allSetups),
            SizedBox(height: context.sp(theme.spacing.xs)),

            // Filter Tabs
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.sp(theme.spacing.md),
                vertical: context.sp(theme.spacing.xs),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      label: 'All Setups (${allSetups.length})',
                      selected: _selectedFilter == 0,
                      onTap: () => setState(() => _selectedFilter = 0),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    _filterChip(
                      label:
                          'Longs (${allSetups.where((s) => s.direction == AiTradeDirection.long).length})',
                      selected: _selectedFilter == 1,
                      intent: UiIntent.bullish,
                      onTap: () => setState(() => _selectedFilter = 1),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    _filterChip(
                      label:
                          'Shorts (${allSetups.where((s) => s.direction == AiTradeDirection.short).length})',
                      selected: _selectedFilter == 2,
                      intent: UiIntent.bearish,
                      onTap: () => setState(() => _selectedFilter = 2),
                    ),
                    SizedBox(width: context.sp(theme.spacing.xs)),
                    _filterChip(
                      label:
                          'High Conviction ≥80% (${allSetups.where((s) => s.confidence >= 80).length})',
                      selected: _selectedFilter == 3,
                      intent: UiIntent.primary,
                      onTap: () => setState(() => _selectedFilter = 3),
                    ),
                  ],
                ),
              ),
            ),

            _buildChartSetups(filteredSetups),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalSummary(List<AiChartSetup> setups) {
    final UiColors colors = context.ui.colors;
    final int highConviction = setups.where((s) => s.confidence >= 80).length;
    final int longs = setups
        .where((s) => s.direction == AiTradeDirection.long)
        .length;
    return UiCard(
      variant: UiCardVariant.subtle,
      padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final List<Widget> stats = <Widget>[
            _signalStat(
              context,
              'Active',
              '${setups.length}',
              Icons.radar_rounded,
            ),
            _signalStat(
              context,
              'High conviction',
              '$highConviction',
              Icons.bolt_rounded,
            ),
            _signalStat(
              context,
              'Long bias',
              '$longs',
              Icons.trending_up_rounded,
            ),
          ];
          if (constraints.maxWidth < 360) {
            return Wrap(
              spacing: context.sp(context.ui.spacing.lg),
              runSpacing: context.sp(context.ui.spacing.sm),
              children: stats,
            );
          }
          return Row(
            children: <Widget>[
              for (int i = 0; i < stats.length; i++) ...<Widget>[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(context.ui.spacing.md),
                    ),
                    child: SizedBox(
                      height: context.sz(32),
                      child: VerticalDivider(color: colors.border),
                    ),
                  ),
                Expanded(child: stats[i]),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _signalStat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final UiColors colors = context.ui.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: context.sz(16), color: colors.foregroundMuted),
        SizedBox(width: context.sp(context.ui.spacing.xs)),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(value, style: context.uiText.bodyStrong),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.uiText.caption.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    UiIntent? intent,
  }) {
    return UiBadge(
      label: label,
      variant: selected ? UiBadgeVariant.solid : UiBadgeVariant.outline,
      intent: intent ?? UiIntent.neutral,
      size: UiSize.sm,
      onTap: onTap,
    );
  }

  /// A compact read on the active chart setups: long/short mix as a donut with
  /// the average confidence in its centre. Derived entirely from the setups the
  /// repository already exposes.
  Widget _buildSetupAnalytics(List<AiChartSetup> setups) {
    final UiColors colors = context.uiColors;
    final int longs = setups
        .where((s) => s.direction == AiTradeDirection.long)
        .length;
    final int shorts = setups.length - longs;
    final double avgConf =
        setups.map((s) => s.confidence).fold<num>(0, (a, b) => a + b) /
        setups.length;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.sp(context.ui.spacing.md),
        vertical: context.sp(context.ui.spacing.xs),
      ),
      child: UiCard(
        title: 'Setups at a glance',
        subtitle: '${setups.length} active chart setups',
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool isTight = constraints.maxWidth < 260;
            final Widget chart = Center(
              child: UiDonutChart(
                size: isTight ? 96 : 120,
                showLegend: false,
                centerLabel: '${avgConf.round()}%\nconf',
                slices: <UiDonutSlice>[
                  UiDonutSlice(
                    label: 'Long',
                    value: longs.toDouble(),
                    color: colors.bullish,
                  ),
                  UiDonutSlice(
                    label: 'Short',
                    value: shorts.toDouble(),
                    color: colors.bearish,
                  ),
                ],
              ),
            );
            final Widget stats = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                UiBadge(label: 'Long · $longs', intent: UiIntent.bullish),
                SizedBox(height: context.sp(context.ui.spacing.xs)),
                UiBadge(label: 'Short · $shorts', intent: UiIntent.bearish),
                SizedBox(height: context.sp(context.ui.spacing.xs)),
                Text(
                  'Average confidence ${avgConf.round()}%',
                  style: context.uiText.caption.copyWith(
                    color: context.ui.colors.foregroundMuted,
                  ),
                ),
              ],
            );
            if (isTight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  chart,
                  SizedBox(height: context.sp(context.ui.spacing.sm)),
                  stats,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                chart,
                SizedBox(width: context.sp(context.ui.spacing.md)),
                Expanded(child: stats),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartSetups(List<AiChartSetup> setups) {
    final UiTheme theme = context.ui;
    final UiColors colors = theme.colors;

    if (setups.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_list_off_rounded,
                size: context.sz(32),
                color: colors.foregroundMuted,
              ),
              SizedBox(height: context.sp(theme.spacing.xs)),
              Text(
                'No chart setups match this filter.',
                style: context.uiText.body,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: setups.length,
      itemBuilder: (context, index) {
        final setup = setups[index];
        final isBullish = setup.direction == AiTradeDirection.long;
        final trendColor = isBullish ? colors.bullish : colors.bearish;
        final sparkValues = _generateSparkline(setup);

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(theme.spacing.md),
            vertical: context.sp(theme.spacing.xs),
          ),
          child: UiCard(
            variant: UiCardVariant.surface,
            accentColor: trendColor,
            onTap: () => widget.onOpenChartAnalysis(setup),
            child: Padding(
              padding: EdgeInsets.all(context.sp(theme.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Symbol, Timeframe, Direction, Confidence
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.sp(theme.spacing.xs),
                          vertical: context.sp(theme.spacing.xxs),
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: context.radius(theme.radii.sm),
                          border: Border.all(
                            color: colors.border.withValues(alpha: 0.6),
                            width: theme.borders.hairline,
                          ),
                        ),
                        child: Text(
                          setup.timeframe,
                          style: context.uiText.caption.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: context.fs(11),
                          ),
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.xs)),
                      Expanded(
                        child: Text(
                          setup.symbol,
                          style: context.uiText.heading.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: context.fs(15),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      UiBadge(
                        label: setup.direction.label,
                        intent: setup.direction.intent,
                        icon: setup.direction.icon,
                        size: UiSize.xs,
                      ),
                      SizedBox(width: context.sp(theme.spacing.xxs)),
                      UiBadge(
                        label: '${setup.confidence}%',
                        intent: setup.confidence >= 80
                            ? UiIntent.primary
                            : UiIntent.neutral,
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                    ],
                  ),

                  SizedBox(height: context.sp(theme.spacing.xs)),

                  // Pattern and Sparkline Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pattern: ${setup.pattern}',
                              style: context.uiText.bodyStrong.copyWith(
                                color: colors.foreground,
                              ),
                            ),
                            SizedBox(height: context.sp(theme.spacing.xxs)),
                            Text(
                              setup.rationale,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.uiText.caption.copyWith(
                                color: colors.foregroundMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sp(theme.spacing.sm)),
                      SizedBox(
                        width: context.sz(80),
                        height: context.sz(32),
                        child: UiSparkChart(
                          values: sparkValues,
                          color: trendColor,
                          filled: true,
                          height: context.sz(32),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: context.sp(theme.spacing.sm)),

                  // Execution Levels Bar
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.sp(theme.spacing.sm),
                      vertical: context.sp(theme.spacing.xs),
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted.withValues(alpha: 0.5),
                      borderRadius: context.radius(theme.radii.md),
                      border: Border.all(
                        color: colors.border.withValues(alpha: 0.5),
                        width: theme.borders.hairline,
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: context.sp(theme.spacing.sm),
                      runSpacing: context.sp(theme.spacing.xs),
                      children: [
                        _levelMetric(
                          context,
                          label: 'Entry',
                          value: AppTokens.price(setup.entry),
                          color: colors.foreground,
                        ),
                        _levelMetric(
                          context,
                          label: 'Stop Loss',
                          value: AppTokens.price(setup.stopLoss),
                          color: colors.destructive,
                        ),
                        _levelMetric(
                          context,
                          label: 'Target 1',
                          value: AppTokens.price(setup.target1),
                          color: colors.bullish,
                        ),
                        _levelMetric(
                          context,
                          label: 'R:R',
                          value: '1:${setup.rrRatio.toStringAsFixed(1)}',
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: context.sp(theme.spacing.sm)),

                  // Actions Row
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.sp(theme.spacing.xs),
                    runSpacing: context.sp(theme.spacing.xs),
                    children: [
                      UiButton(
                        label: 'Send in DM',
                        icon: Icons.send_outlined,
                        size: UiSize.xs,
                        variant: UiVariant.ghost,
                        onPressed: () {
                          ShareToConversationDialog.show(
                            context,
                            initialText:
                                '📈 AI Setup: ${setup.symbol} (${setup.timeframe})\n'
                                'Direction: ${setup.direction.label}\n'
                                'Pattern: ${setup.pattern}\n'
                                'Entry: ${AppTokens.price(setup.entry)} | Stop: ${AppTokens.price(setup.stopLoss)} | TP1: ${AppTokens.price(setup.target1)}\n'
                                'Confidence: ${setup.confidence}%\n'
                                'Rationale: ${setup.rationale}',
                          );
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UiDropdownMenu(
                            alignRight: true,
                            items: [
                              UiMenuItem(
                                label: 'Log Trade in Journal',
                                icon: Icons.menu_book_outlined,
                                onPressed: () => widget.onCreateFromSetup(
                                  setup,
                                  AiCreateTarget.journal,
                                ),
                              ),
                              UiMenuItem(
                                label: 'Save Research Note',
                                icon: Icons.sticky_note_2_outlined,
                                onPressed: () => widget.onCreateFromSetup(
                                  setup,
                                  AiCreateTarget.note,
                                ),
                              ),
                              UiMenuItem(
                                label: 'Build Playbook',
                                icon: Icons.account_tree_outlined,
                                onPressed: () => widget.onCreateFromSetup(
                                  setup,
                                  AiCreateTarget.strategy,
                                ),
                              ),
                            ],
                            child: UiIconButton(
                              icon: Icons.more_horiz_rounded,
                              size: UiSize.xs,
                              tooltip: 'More actions',
                              onPressed: null,
                            ),
                          ),
                          SizedBox(width: context.sp(theme.spacing.xs)),
                          UiButton(
                            label: 'Analyze',
                            icon: Icons.candlestick_chart_rounded,
                            size: UiSize.xs,
                            variant: UiVariant.solid,
                            intent: UiIntent.primary,
                            onPressed: () => widget.onOpenChartAnalysis(setup),
                          ),
                        ],
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

  Widget _levelMetric(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.uiText.caption.copyWith(
            color: context.uiColors.foregroundMuted,
            fontSize: context.fs(10.5),
          ),
        ),
        SizedBox(height: 1),
        Text(
          value,
          style: context.uiText.bodyStrong.copyWith(
            color: color,
            fontSize: context.fs(12),
          ),
        ),
      ],
    );
  }
}
