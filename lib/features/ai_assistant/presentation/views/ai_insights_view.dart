import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/features/ai_assistant/data/ai_assistant_repository.dart';
import 'package:tradex/features/ai_assistant/models/ai_assistant_models.dart';
import 'package:tradex/features/ai_assistant/presentation/widgets/ai_assistant_widgets.dart';

class AiInsightsView extends StatefulWidget {
  final AiAssistantRepository repository;

  final void Function(AiChartSetup) onOpenChartAnalysis;
  final void Function(AiChartSetup, AiCreateTarget) onCreateFromSetup;

  const AiInsightsView({
    super.key,
    required this.repository,
    required this.onOpenChartAnalysis,
    required this.onCreateFromSetup,
  });

  @override
  State<AiInsightsView> createState() => _AiInsightsViewState();
}

class _AiInsightsViewState extends State<AiInsightsView> {
  late AiAssistantRepository _repository;
  late List<AppAiInsight> _localInsights;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository;
    _repository.addListener(_onRepositoryChanged);
    _localInsights = List.of(_repository.insights);
  }

  @override
  void didUpdateWidget(AiInsightsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      oldWidget.repository.removeListener(_onRepositoryChanged);
      _repository = widget.repository;
      _repository.addListener(_onRepositoryChanged);
      _localInsights = List.of(_repository.insights);
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {
      // Re-sync local insights when repository updates
      // This is a naive implementation; you may want to handle dismissing properly
      // _localInsights = List.of(_repository.insights);
    });
  }

  void _handleAsk(AppAiInsight insight) {
    _repository.sendPrompt('Tell me more about this insight: ${insight.title}');
  }

  void _handleDismiss(AppAiInsight insight) {
    setState(() {
      _localInsights.removeWhere((i) => i == insight);
    });
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
                insights: _localInsights,
                loading: false,
                onAsk: _handleAsk,
                onDismiss: _handleDismiss,
                onGenerate: () {
                  // Optional generation trigger
                },
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
            onTap: () => widget.onOpenChartAnalysis(setup),
            child: Padding(
              padding: EdgeInsets.all(context.sp(context.ui.spacing.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        setup.symbol,
                        style: context.uiText.bodyStrong,
                      ),
                      UiBadge(
                        label: setup.direction.label,
                        intent: setup.direction.intent,
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
                      Icon(Icons.monitor_heart, size: 16, color: context.ui.colors.foregroundMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Confidence: ${(setup.confidence * 100).toInt()}%',
                        style: context.uiText.caption.copyWith(
                          color: context.ui.colors.foregroundMuted,
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
