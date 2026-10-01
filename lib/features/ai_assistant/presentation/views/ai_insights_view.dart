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
    setState(() => _generating = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _repository.generateInsight();
    if (mounted) {
      setState(() => _generating = false);
      UiToast.show(
        context,
        title: 'New Insight Generated',
        message: 'AI analyzed market volume & technical setups',
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
                onGenerate: _handleGenerate,
              ),
            ),
            const AiSectionHeader(
              title: 'Chart Setups',
              icon: Icons.show_chart,
            ),
            _buildChartSetups(),
          ],
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.candlestick_chart_rounded,
                            size: context.sz(20),
                            color: context.ui.colors.primary,
                          ),
                          SizedBox(width: context.sp(context.ui.spacing.xs)),
                          Text(
                            '${setup.symbol} • ${setup.timeframe}',
                            style: context.uiText.bodyStrong,
                          ),
                        ],
                      ),
                      UiBadge(
                        label: setup.direction.label,
                        intent: setup.direction.intent,
                        icon: setup.direction.icon,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Text(
                    'Pattern: ${setup.pattern}',
                    style: context.uiText.body,
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Row(
                    children: [
                      Text(
                        'Entry: ${AppTokens.price(setup.entry)}',
                        style: context.uiText.bodyStrong,
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.sm)),
                      Text(
                        'SL: ${AppTokens.price(setup.stopLoss)}',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.destructive,
                        ),
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.sm)),
                      Text(
                        'TP: ${AppTokens.price(setup.target1)}',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.bullish,
                        ),
                      ),
                      const Spacer(),
                      UiBadge(
                        label: 'R:R ${setup.rrRatio.toStringAsFixed(1)}',
                        variant: UiBadgeVariant.outline,
                        size: UiSize.xs,
                      ),
                    ],
                  ),
                  SizedBox(height: context.sp(context.ui.spacing.xs)),
                  Row(
                    children: [
                      Icon(
                        Icons.monitor_heart,
                        size: 16,
                        color: context.ui.colors.foregroundMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Confidence: ${setup.confidence}%',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
                        ),
                      ),
                      const Spacer(),
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
                      SizedBox(width: context.sp(context.ui.spacing.xs)),
                      SizedBox(width: context.sp(context.ui.spacing.xs)),
                      UiDropdownMenu(
                        alignRight: true,
                        items: [
                          UiMenuItem(
                            label: 'Log Trade',
                            icon: Icons.menu_book_outlined,
                            onPressed: () => widget.onCreateFromSetup(setup, AiCreateTarget.journal),
                          ),
                          UiMenuItem(
                            label: 'Save as Note',
                            icon: Icons.sticky_note_2_outlined,
                            onPressed: () => widget.onCreateFromSetup(setup, AiCreateTarget.note),
                          ),
                        ],
                        child: UiIconButton(
                          icon: Icons.more_vert_rounded,
                          size: UiSize.xs,
                          tooltip: 'More options',
                          onPressed: null,
                        ),
                      ),
                      SizedBox(width: context.sp(context.ui.spacing.xs)),
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
            ),
          ),
        );
      },
    );
  }
}
