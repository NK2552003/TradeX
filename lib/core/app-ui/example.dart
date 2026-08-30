import 'package:flutter/material.dart';
import 'app_ui.dart';

/// Single-file master reference showcasing all App UI cards, blocks, shell, and motion.
class AppUiExampleApp extends StatefulWidget {
  const AppUiExampleApp({super.key});

  @override
  State<AppUiExampleApp> createState() => _AppUiExampleAppState();
}

class _AppUiExampleAppState extends State<AppUiExampleApp> {
  bool _isDark = true;

  final AppTrade _sampleTrade = AppTrade(
    id: 't1',
    ticker: 'NVDA',
    side: AppSide.long,
    entry: 120.50,
    exit: 135.00,
    pnl: 1450.00,
    pnlPercent: 12.03,
    openedAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  // Sample values, not product data: this gallery renders the design system on
  // its own and deliberately does not depend on the app's data layer. The label
  // is formatted from the amount rather than written beside it, so the two can
  // never drift apart, and the currency matches the product so the reference does
  // not read as a different app.
  final AppPlan _samplePlan = AppPlan(
    tier: AppTier.premium,
    amount: 2499,
    priceLabel: AppTokens.price(2499),
    features: const <String>[
      'Unlimited trades',
      'AI insights',
      'Custom webhooks',
    ],
    highlighted: true,
  );

  @override
  Widget build(BuildContext context) {
    final UiTheme theme = _isDark ? UiTheme.dark() : UiTheme.light();
    return UiApp(
      theme: theme,
      builder: (BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('App UI Domain Blocks & Cards Reference'),
          actions: <Widget>[
            IconButton(
              icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
              onPressed: () => setState(() => _isDark = !_isDark),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.all(context.sp(theme.spacing.lg)),
          children: <Widget>[
            _buildSection(
              context,
              title: '1. Brand & Logo',
              child: Row(
                children: const <Widget>[
                  AppLogo(),
                  SizedBox(width: 24),
                  AppWordmark(),
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            _buildSection(
              context,
              title: '2. Domain Cards',
              child: Column(
                children: <Widget>[
                  AppTradeCard(trade: _sampleTrade),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  AppPlanCard(plan: _samplePlan),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppStrategyCard(
                    strategy: AppStrategy(
                      id: 's1',
                      name: 'Morning Breakout Strategy',
                      category: 'Day Trading',
                      winRate: 0.72,
                      isFavorite: true,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppTickerCard(
                    ticker: AppTicker(
                      symbol: 'AAPL',
                      name: 'Apple Inc.',
                      price: 224.50,
                      changePercent: 1.85,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppTraderCard(
                    trader: AppTrader(
                      id: 'u1',
                      handle: '@nitish',
                      displayName: 'Nitish Kumar',
                      winRate: 0.74,
                      tier: AppTier.premium,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppAiInsightCard(
                    insight: AppAiInsight(
                      id: 'ai1',
                      title: 'Risk Warning',
                      body:
                          'FOMC announcement expected at 2PM EST. Recommend lowering position leverage.',
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            _buildSection(
              context,
              title: '3. Motion Helpers',
              child: AppFadeIn(
                child: Container(
                  padding: EdgeInsets.all(context.sp(theme.spacing.md)),
                  decoration: BoxDecoration(
                    color: theme.colors.surfaceMuted,
                    borderRadius: context.radius(theme.radii.lg),
                  ),
                  child: const Text(
                    'AppFadeIn: Smooth entrance animation applied.',
                  ),
                ),
              ),
            ),
            SizedBox(height: context.sp(theme.spacing.xl)),
            _buildSection(
              context,
              title: '4. Domain Blocks',
              child: Column(
                children: <Widget>[
                  AppStatGridBlock(
                    stats: <AppStat>[
                      AppStat(
                        label: 'Total P/L',
                        value: 14250,
                        formatter: (v) => '+\$$v',
                      ),
                      AppStat(
                        label: 'Win Rate',
                        value: 68.5,
                        formatter: (v) => '$v%',
                      ),
                      const AppStat(label: 'Total Trades', value: 142),
                      const AppStat(label: 'Profit Factor', value: 2.14),
                    ],
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppProfileHeaderBlock(
                    trader: AppTrader(
                      id: 'u1',
                      handle: '@nitish',
                      displayName: 'Nitish Kumar',
                      tier: AppTier.premium,
                    ),
                  ),
                  SizedBox(height: context.sp(theme.spacing.md)),
                  const AppUsageBlock(
                    metrics: <AppUsageMetric>[
                      AppUsageMetric(
                        label: 'Trades Logged',
                        used: 142,
                        limit: 500,
                      ),
                      AppUsageMetric(
                        label: 'AI Prompts Used',
                        used: 45,
                        limit: 100,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.uiText.heading),
        SizedBox(height: context.sp(context.uiSpace.sm)),
        child,
      ],
    );
  }
}
