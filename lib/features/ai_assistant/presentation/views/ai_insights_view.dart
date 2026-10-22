import 'package:tradex/core/config/customer_data_policy.dart';
import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
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

  @override
  Widget build(BuildContext context) {
    return AiDensityScope(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AiSectionHeader(
              title: 'Market Insights',
              icon: Icons.lightbulb_outline,
            ),
            Padding(
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
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
            const AiSectionHeader(
              title: 'Chart Setups',
              icon: Icons.show_chart,
            ),
            if (_repository.chartSetups.length >= 2)
              _buildSetupAnalytics(_repository.chartSetups),
            _buildChartSetups(),
          ],
        ),
      ),
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

  Widget _buildChartSetups() {
    final setups = _repository.chartSetups;
    if (setups.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
        child: Text('No chart setups available.', style: context.uiText.body),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: setups.length,
      itemBuilder: (context, index) {
        final setup = setups[index];
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.sp(context.ui.spacing.md),
            vertical: context.sp(context.ui.spacing.xs),
          ),
          child: UiCard(
            variant: UiCardVariant.surface,
            onTap: () => widget.onOpenChartAnalysis(setup),
            child: Padding(
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.candlestick_chart_rounded,
                              size: context.sz(20),
                              color: context.ui.colors.primary,
                            ),
                            SizedBox(width: context.sp(context.ui.spacing.xs)),
                            Flexible(
                              child: Text(
                                '${setup.symbol} • ${setup.timeframe}',
                                style: context.uiText.bodyStrong,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.xs)),
                      UiBadge(
                        label: setup.direction.label,
                        intent: setup.direction.intent,
                        icon: setup.direction.icon,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Text('Pattern: ${setup.pattern}', style: context.uiText.body),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.sp(context.ui.spacing.sm),
                    runSpacing: context.sp(context.ui.spacing.xs),
                    children: [
                      Wrap(
                        spacing: context.sp(context.ui.spacing.sm),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Entry: ${AppTokens.price(setup.entry)}',
                            style: context.uiText.bodyStrong,
                          ),
                          Text(
                            'SL: ${AppTokens.price(setup.stopLoss)}',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.destructive,
                            ),
                          ),
                          Text(
                            'TP: ${AppTokens.price(setup.target1)}',
                            style: context.uiText.caption.copyWith(
                              color: context.ui.colors.bullish,
                            ),
                          ),
                        ],
                      ),
                      UiBadge(
                        label: 'R:R ${setup.rrRatio.toStringAsFixed(1)}',
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: context.sp(context.ui.spacing.xs),
                    runSpacing: context.sp(context.ui.spacing.xs),
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.monitor_heart,
                            size: 16,
                            color: context.ui.colors.foregroundMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Confidence: ${setup.confidence}%',
                              style: context.uiText.caption.copyWith(
                                color: context.ui.colors.foregroundMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: context.sp(context.ui.spacing.xs),
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                          UiDropdownMenu(
                            alignRight: true,
                            items: [
                              UiMenuItem(
                                label: 'Log Trade',
                                icon: Icons.menu_book_outlined,
                                onPressed: () => widget.onCreateFromSetup(
                                  setup,
                                  AiCreateTarget.journal,
                                ),
                              ),
                              UiMenuItem(
                                label: 'Save as Note',
                                icon: Icons.sticky_note_2_outlined,
                                onPressed: () => widget.onCreateFromSetup(
                                  setup,
                                  AiCreateTarget.note,
                                ),
                              ),
                            ],
                            child: UiIconButton(
                              icon: Icons.more_vert_rounded,
                              size: UiSize.xs,
                              tooltip: 'More options',
                              onPressed: null,
                            ),
                          ),
                          UiButton(
                            label: 'Analyze',
                            icon: Icons.analytics_outlined,
                            size: UiSize.xs,
                            variant: UiVariant.soft,
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
}
