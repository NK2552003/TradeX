import 'package:flutter/material.dart';
import 'package:tradex/core/app-ui/app_ui.dart';
import 'package:tradex/core/config/mock_data.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.ui;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Trading Assistant',
                    style: context.uiText.display.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.xxs)),
                  Text(
                    'AI market analysis, trade review & strategy recommendations',
                    style: context.uiText.body.copyWith(
                      color: theme.colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
              const UiBadge(
                label: 'AI Model v3.6 Active',
                intent: UiIntent.success,
              ),
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Disclaimer Callout
          const UiCallout(
            title: 'Educational & Analytical Purpose',
            message: 'AI Assistant outputs provide market analysis and pattern detection for educational purposes. Not financial advice.',
            intent: UiIntent.info,
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Active AI Insights List
          AppAiAnalysisCard(
            insight: mockInsight,
            observations: const [
              'Volume confirmation on 4H chart',
              'RSI holding above 55 level',
            ],
          ),
          SizedBox(height: context.sp(theme.spacing.lg)),

          // Prompt Input Card
          UiCard(
            title: 'Ask AI Trading Assistant',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiInput(
                  value: _promptController.text,
                  hintText: 'e.g. Analyze \$AAPL risk-to-reward ratio for long entry at \$224...',
                  leadingIcon: Icons.auto_awesome,
                  onChanged: (v) => _promptController.text = v,
                ),
                SizedBox(height: context.sp(theme.spacing.md)),
                UiButton(
                  label: 'Generate Insight',
                  leadingIcon: Icons.send_rounded,
                  variant: UiVariant.primary,
                  intent: UiIntent.primary,
                  onPressed: () {
                    if (_promptController.text.isEmpty) return;
                    UiToast.show(
                      context,
                      title: 'AI Analysis',
                      message: 'Processing market insight request...',
                      intent: UiIntent.primary,
                    );
                    _promptController.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
